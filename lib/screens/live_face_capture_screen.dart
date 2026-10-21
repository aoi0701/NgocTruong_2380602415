import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/live_face_gate.dart';
import '../services/face_feature_helper.dart';

/// Processes the front camera stream; returns one accepted sample, never a photo.
class LiveFaceCaptureScreen extends StatefulWidget {
  const LiveFaceCaptureScreen({
    super.key,
    required this.title,
    this.sample,
    this.extractFeatures,
    this.matchesSample,
  });

  final String title;

  /// Mẫu đặc trưng khuôn mặt đã đăng ký trước (nếu có).
  /// Nếu null: Màn hình hoạt động ở chế độ thu thập (enrollment/face-login)
  /// và hoàn tất ngay khi đạt chuẩn Liveness.
  final Map<String, dynamic>? sample;

  /// Hàm trích xuất đặc trưng khuôn mặt (tùy chọn, mặc định dùng FaceFeatureHelper.extractFaceFeatures).
  final Map<String, double> Function(Face face)? extractFeatures;

  /// Hàm so khớp mẫu khuôn mặt (tùy chọn).
  final bool Function(Map<String, double> features)? matchesSample;

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

  int _openEyesDirectFrames = 0;
  int? _lastTrackingId;

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
      _openEyesDirectFrames = 0;
      _lastTrackingId = null;
      setState(() {
        _error = null;
        _hint = widget.sample == null
            ? 'Nhìn thẳng vào camera, mở to mắt hoặc mỉm cười'
            : 'Nhìn thẳng và mỉm cười hoặc chớp mắt trước camera';
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
        _openEyesDirectFrames = 0;
        _lastTrackingId = null;
        setState(
          () => _hint = faces.isEmpty
              ? 'Đưa khuôn mặt vào khung camera'
              : 'Chỉ một người đứng trước camera',
        );
        return;
      }
      final face = faces.single;
      final features = widget.extractFeatures != null
          ? widget.extractFeatures!(face)
          : FaceFeatureHelper.extractFaceFeatures(face);

      final double rotX = face.headEulerAngleX ?? 90;
      final double rotY = face.headEulerAngleY ?? 90;
      final double rotZ = face.headEulerAngleZ ?? 90;
      final facing = FaceLivenessChecker.isHeadAngleDirect(
        yaw: rotY,
        roll: rotZ,
        pitch: rotX,
      );

      final matches = widget.matchesSample != null
          ? widget.matchesSample!(features)
          : (widget.sample != null
              ? FaceFeatureHelper.isMatch(features, widget.sample)
              : true);

      final leftEye = face.leftEyeOpenProbability;
      final rightEye = face.rightEyeOpenProbability;
      final smile = face.smilingProbability;

      final gateAccepted = _gate.observe(
        faceCount: 1,
        facingForward: facing,
        matches: matches,
        trackingId: face.trackingId,
        leftEye: leftEye,
        rightEye: rightEye,
        smile: smile,
      );

      bool accepted = gateAccepted;

      // Khi sample == null (đăng ký mẫu hoặc đăng nhập khuôn mặt khi chưa có mẫu từ trước):
      // Đạt chuẩn Liveness khi: chớp mắt hoặc mỉm cười (qua LiveFaceGate)
      // HOẶC 2 mắt mở to trực diện (leftEye >= 0.75 && rightEye >= 0.75 trong >= 3 frames ổn định).
      if (widget.sample == null) {
        if (_lastTrackingId != null &&
            face.trackingId != null &&
            _lastTrackingId != face.trackingId) {
          _openEyesDirectFrames = 0;
        }
        _lastTrackingId = face.trackingId;

        if (facing &&
            matches &&
            (leftEye ?? 0) >= 0.75 &&
            (rightEye ?? 0) >= 0.75) {
          _openEyesDirectFrames++;
          if (_openEyesDirectFrames >= 3) {
            accepted = true;
          }
        } else {
          _openEyesDirectFrames = 0;
        }
      }

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
              : widget.sample != null
              ? 'Giữ mặt trong khung, mỉm cười hoặc chớp mắt'
              : 'Giữ mặt thẳng, mở to mắt hoặc mỉm cười',
        );
      }
    } catch (error) {
      if (mounted && generation == _generation && !_finished) {
        _gate.reset();
        _openEyesDirectFrames = 0;
        _lastTrackingId = null;
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
    _openEyesDirectFrames = 0;
    _lastTrackingId = null;
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
