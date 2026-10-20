import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class RealtimeCameraTranslateScreen extends StatefulWidget {
  final TranslateLanguage initialSourceLang;
  final TranslateLanguage initialTargetLang;

  const RealtimeCameraTranslateScreen({
    super.key,
    this.initialSourceLang = TranslateLanguage.english,
    this.initialTargetLang = TranslateLanguage.vietnamese,
  });

  @override
  State<RealtimeCameraTranslateScreen> createState() => _RealtimeCameraTranslateScreenState();
}

class _RealtimeCameraTranslateScreenState extends State<RealtimeCameraTranslateScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;

  late TranslateLanguage _sourceLang;
  late TranslateLanguage _targetLang;
  OnDeviceTranslator? _translator;
  TextRecognizer? _textRecognizer;

  Timer? _scanTimer;
  bool _isScanning = true;
  bool _isProcessingFrame = false;

  String _detectedText = '';
  String _translatedText = '';
  String _lastProcessedText = '';
  bool _isTranslating = false;

  static const Map<TranslateLanguage, String> _languages = {
    TranslateLanguage.vietnamese: 'Tiếng Việt',
    TranslateLanguage.english: 'Tiếng Anh',
    TranslateLanguage.french: 'Tiếng Pháp',
    TranslateLanguage.japanese: 'Tiếng Nhật',
    TranslateLanguage.korean: 'Tiếng Hàn',
    TranslateLanguage.chinese: 'Tiếng Trung',
    TranslateLanguage.spanish: 'Tây Ban Nha',
    TranslateLanguage.german: 'Tiếng Đức',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sourceLang = widget.initialSourceLang;
    _targetLang = widget.initialTargetLang;

    _initTranslator();
    _initTextRecognizer();
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    _cameraController?.dispose();
    _translator?.close();
    _textRecognizer?.close();
    super.dispose();
  }

  void _initTranslator() {
    _translator?.close();
    _translator = OnDeviceTranslator(
      sourceLanguage: _sourceLang,
      targetLanguage: _targetLang,
    );
  }

  void _initTextRecognizer() {
    _textRecognizer?.close();
    TextRecognitionScript script = TextRecognitionScript.latin;
    if (_sourceLang == TranslateLanguage.chinese) {
      script = TextRecognitionScript.chinese;
    } else if (_sourceLang == TranslateLanguage.japanese) {
      script = TextRecognitionScript.japanese;
    } else if (_sourceLang == TranslateLanguage.korean) {
      script = TextRecognitionScript.korean;
    }
    _textRecognizer = TextRecognizer(script: script);
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng cấp quyền Camera để dùng tính năng dịch Realtime!')),
        );
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy thiết bị camera khả dụng!')),
          );
        }
        return;
      }

      // Ưu tiên camera sau
      _selectedCameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      final controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        _startRealtimeScanTimer();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi động camera: $e')),
        );
      }
    }
  }

  void _startRealtimeScanTimer() {
    _scanTimer?.cancel();
    // Quét định kỳ mỗi 900ms để đảm bảo mượt mà và không quá tải bộ nhớ
    _scanTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_isScanning && !_isProcessingFrame && _cameraController != null && _cameraController!.value.isInitialized) {
        _processFrame();
      }
    });
  }

  Future<void> _processFrame() async {
    if (_isProcessingFrame || !_isScanning || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isProcessingFrame = true;
    XFile? capturedFile;

    try {
      capturedFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(capturedFile.path);

      if (_textRecognizer == null) _initTextRecognizer();
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);

      final text = recognizedText.text.trim();

      // Xóa file ảnh tạm ngay để tránh chiếm dung lượng
      try {
        await File(capturedFile.path).delete();
      } catch (_) {}

      if (text.isNotEmpty && text != _lastProcessedText) {
        _lastProcessedText = text;

        if (mounted) {
          setState(() {
            _detectedText = text;
            _isTranslating = true;
          });
        }

        if (_translator == null) _initTranslator();
        final translation = await _translator!.translateText(text);

        if (mounted) {
          setState(() {
            _translatedText = translation;
            _isTranslating = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Realtime frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
    });
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      _initTranslator();
      _initTextRecognizer();
      _lastProcessedText = '';
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

    await _cameraController?.dispose();
    setState(() {
      _isCameraInitialized = false;
    });

    final controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _cameraController = controller;
    await controller.initialize();
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
      _startRealtimeScanTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),

          // 2. Khung ngắm quét (Viewfinder Scanner)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isScanning ? Colors.tealAccent : Colors.grey,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.08),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isScanning ? '🔍 Đang lia quét văn bản...' : '⏸️ Đã tạm dừng',
                          style: TextStyle(
                            color: _isScanning ? Colors.tealAccent : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Header Bar (Nút Back, Đổi ngôn ngữ, Đổi camera)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context, _translatedText),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.shade300, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            DropdownButtonHideUnderline(
                              child: DropdownButton<TranslateLanguage>(
                                value: _sourceLang,
                                dropdownColor: Colors.black87,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _sourceLang = val;
                                      _initTranslator();
                                      _initTextRecognizer();
                                      _lastProcessedText = '';
                                    });
                                  }
                                },
                                items: _languages.entries.map((e) {
                                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                                }).toList(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.swap_horiz, color: Colors.tealAccent, size: 20),
                              onPressed: _swapLanguages,
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<TranslateLanguage>(
                                value: _targetLang,
                                dropdownColor: Colors.black87,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _targetLang = val;
                                      _initTranslator();
                                      _lastProcessedText = '';
                                    });
                                  }
                                },
                                items: _languages.entries.map((e) {
                                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_cameras.length > 1)
                        CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                            onPressed: _switchCamera,
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Floating Card: Kết quả Dịch Realtime
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.teal.shade400, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh tiêu đề trạng thái
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isScanning ? Colors.greenAccent : Colors.orangeAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScanning ? 'DỊCH REALTIME' : 'ĐÃ TẠM DỪNG (FREEZE)',
                            style: TextStyle(
                              color: _isScanning ? Colors.greenAccent : Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isScanning ? Icons.pause_circle_outline : Icons.play_circle_outline,
                              color: Colors.white,
                              size: 26,
                            ),
                            tooltip: _isScanning ? 'Tạm dừng lia' : 'Tiếp tục quét',
                            onPressed: _toggleScanning,
                          ),
                          if (_translatedText.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                              tooltip: 'Sao chép bản dịch',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _translatedText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã sao chép bản dịch!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 12),

                  // Nội dung phát hiện gốc
                  if (_detectedText.isNotEmpty) ...[
                    Text(
                      'Phát hiện (${_languages[_sourceLang]}):',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _detectedText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Kết quả dịch
                  Text(
                    'Bản dịch (${_languages[_targetLang]}):',
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (_isTranslating)
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                        ),
                        SizedBox(width: 8),
                        Text('Đang dịch...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    )
                  else
                    Text(
                      _translatedText.isEmpty ? 'Hãy lia camera vào vùng có chữ...' : _translatedText,
                      style: TextStyle(
                        color: _translatedText.isEmpty ? Colors.white38 : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
