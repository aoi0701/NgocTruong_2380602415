import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/live_face_gate.dart';

/// Processes the front camera stream; returns one accepted sample, never a photo.
class LiveFaceCaptureScreen extends StatefulWidget {
  const LiveFaceCaptureScreen({
    super.key,
    required this.title,
    required this.extractFeatures,
    required this.matchesSample,
  });
  final String title;
  final Map<String, double> Function(Face face) extractFeatures;
  final bool Function(Map<String, double> features) matchesSample;

  @override
  State<LiveFaceCaptureScreen> createState() => _LiveFaceCaptureScreenState();
}

class _LiveFaceCaptureScreenState extends State<LiveFaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  final _gate = LiveFaceGate();
  bool _processing = false;
  bool _finished = false;
  bool _starting = false;
  bool _foreground = true;
  bool _reopenPending = false;
  Future<void> _releaseFuture = Future.value();
  int _generation = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  Completer<void>? _frameDone;
  String _hint = 'Đang mở camera trước...';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  Future<void> _openCamera() async {
    if (_finished || !mounted || !_foreground) return;
    if (_starting) {
      _reopenPending = true;
      return;
    }
    if (_camera != null) return;
    _starting = true;
    var generation = _generation;
    CameraController? controller;
    try {
      await _releaseFuture;
      if (!mounted || !_foreground) return;
      generation = ++_generation;
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Không tìm thấy camera.');
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      _gate.reset();
      setState(() {
        _error = null;
        _hint = 'Nhìn thẳng và mỉm cười hoặc chớp mắt trước camera';
      });
      await controller.startImageStream(
        (frame) => _processFrame(frame, generation),
      );
    } catch (error) {
      if (_camera == controller) _camera = null;
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is CameraException
              ? 'Không mở được camera. Kiểm tra quyền camera rồi thử lại. (${error.code})'
              : 'Không mở được camera: $error',
        );
      }
    } finally {
      _starting = false;
      if (_reopenPending && mounted && _foreground && !_finished) {
        _reopenPending = false;
        scheduleMicrotask(_openCamera);
      }
    }
  }

  InputImage _inputImage(CameraImage frame, CameraController controller) {
    // CameraX's NV21 mode yields a single packed plane, even if format reports YUV.
    if (frame.planes.length != 1) {
      throw StateError('Camera chưa cung cấp định dạng ảnh hỗ trợ.');
    }
    const orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final description = controller.description;
    final deviceRotation =
        orientations[controller.value.deviceOrientation] ?? 0;
    final degrees = Platform.isIOS
        ? description.sensorOrientation
        : description.lensDirection == CameraLensDirection.front
        ? (description.sensorOrientation + deviceRotation) % 360
        : (description.sensorOrientation - deviceRotation + 360) % 360;
    return InputImage.fromBytes(
      bytes: frame.planes.single.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation:
            InputImageRotationValue.fromRawValue(degrees) ??
            InputImageRotation.rotation0deg,
        format: Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888,
        bytesPerRow: frame.planes.single.bytesPerRow,
      ),
    );
  }

  Future<void> _processFrame(CameraImage frame, int generation) async {
    final controller = _camera;
    if (_finished ||
        _processing ||
        !_foreground ||
        !mounted ||
        controller == null ||
        generation != _generation) {
      return;
    }
    if (DateTime.now().difference(_lastFrame).inMilliseconds < 160) return;
    _lastFrame = DateTime.now();
    _processing = true;
    final done = _frameDone = Completer<void>();
    try {
      final faces = await _detector.processImage(
        _inputImage(frame, controller),
      );
      if (!mounted || _finished || generation != _generation) return;
      if (faces.length != 1) {
        _gate.reset();
        setState(
          () => _hint = faces.isEmpty
              ? 'Đưa khuôn mặt vào khung camera'
              : 'Chỉ một người đứng trước camera',
        );
        return;
      }
      final face = faces.single;
      final features = widget.extractFeatures(face);
      final facing =
          (face.headEulerAngleX ?? 90).abs() <= 15 &&
          (face.headEulerAngleY ?? 90).abs() <= 15 &&
          (face.headEulerAngleZ ?? 90).abs() <= 15;
      final matches = widget.matchesSample(features);
      final accepted = _gate.observe(
        faceCount: 1,
        facingForward: facing,
        matches: matches,
        trackingId: face.trackingId,
        leftEye: face.leftEyeOpenProbability,
        rightEye: face.rightEyeOpenProbability,
        smile: face.smilingProbability,
      );
      if (accepted) {
        _finished = true;
        setState(() => _hint = 'Đã nhận diện. Đang xác nhận...');
        // Finish only after this frame releases the detector.
        unawaited(_finish(features, controller));
      } else {
        setState(
          () => _hint = !facing
              ? 'Nhìn thẳng vào camera'
              : !matches
              ? 'Khuôn mặt chưa khớp mẫu. Hãy nhìn rõ camera'
              : 'Giữ mặt trong khung, mỉm cười hoặc chớp mắt',
        );
      }
    } catch (error) {
      if (mounted && generation == _generation && !_finished) {
        _gate.reset();
        setState(() => _hint = 'Chưa nhận diện được: $error');
      }
    } finally {
      _processing = false;
      done.complete();
    }
  }

  Future<void> _finish(
    Map<String, double> features,
    CameraController controller,
  ) async {
    await _frameDone?.future;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      if (mounted) Navigator.pop(context, features);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Camera bị gián đoạn. Hãy quay lại và thử lại.';
        });
      }
    }
  }

  Future<void> _releaseCamera() async {
    final controller = _camera;
    _camera = null;
    ++_generation;
    _gate.reset();
    try {
      await controller?.dispose();
    } catch (error) {
      debugPrint('Camera close: $error');
    }
    await _frameDone?.future;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _foreground = false;
      ++_generation;
      _releaseFuture = _releaseFuture.then((_) => _releaseCamera());
    } else if (state == AppLifecycleState.resumed && !_finished) {
      _foreground = true;
      _openCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finished = true;
    unawaited(
      _releaseFuture
          .then((_) => _releaseCamera())
          .whenComplete(_detector.close),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : camera == null || !camera.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      Center(child: CameraPreview(camera)),
                      Center(
                        child: IgnorePointer(
                          child: Container(
                            width: 240,
                            height: 310,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(120),
                              border: Border.all(
                                color: Colors.tealAccent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
