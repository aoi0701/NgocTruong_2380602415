import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'RealtimeCameraTranslateScreen.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _textController = TextEditingController();
  String _translatedText = '';
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  TranslateLanguage _sourceLang = TranslateLanguage.english;
  TranslateLanguage _targetLang = TranslateLanguage.vietnamese;

  bool _isLoading = false;
  OnDeviceTranslator? _translator;

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
    _initTranslator();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onError: (val) {
          if (mounted) {
            setState(() => _isListening = false);
            if (val.errorMsg == 'error_speech_timeout' || val.errorMsg == 'error_no_match') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Không nghe thấy tiếng. Trên máy ảo laptop, hãy bật mic host trong (...) > Microphone.'),
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi giọng nói: ${val.errorMsg}')),
              );
            }
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Speech init error in translate: $e');
    }
  }

  void _initTranslator() {
    _translator?.close();
    _translator = OnDeviceTranslator(
      sourceLanguage: _sourceLang,
      targetLanguage: _targetLang,
    );
  }

  String _getLocaleForLanguage(TranslateLanguage lang) {
    switch (lang) {
      case TranslateLanguage.vietnamese:
        return 'vi_VN';
      case TranslateLanguage.english:
        return 'en_US';
      case TranslateLanguage.french:
        return 'fr_FR';
      case TranslateLanguage.japanese:
        return 'ja_JP';
      case TranslateLanguage.korean:
        return 'ko_KR';
      case TranslateLanguage.chinese:
        return 'zh_CN';
      case TranslateLanguage.spanish:
        return 'es_ES';
      case TranslateLanguage.german:
        return 'de_DE';
      default:
        return 'en_US';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    _translator?.close();
    super.dispose();
  }

  Future<void> _translateText(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _translatedText = 'Đang dịch... (lần đầu có thể mất vài giây để tải mô hình)';
    });

    try {
      if (_translator == null) _initTranslator();
      final translation = await _translator!.translateText(trimmedText);
      if (mounted) {
        setState(() {
          _translatedText = translation;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = 'Lỗi dịch thuật: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listen() async {
    if (!_isListening) {
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vui lòng cấp quyền Microphone để dùng tính năng này!')),
            );
          }
          return;
        }
      }

      if (!_speech.isAvailable) {
        await _initSpeech();
      }

      if (_speech.isAvailable) {
        setState(() => _isListening = true);
        final locale = _getLocaleForLanguage(_sourceLang);

        _speech.listen(
          localeId: locale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
            cancelOnError: false,
          ),
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
            if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
              setState(() => _isListening = false);
              _translateText(val.recognizedWords);
            }
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể kích hoạt Micro trên thiết bị này. Vui lòng kiểm tra quyền hoặc micro.'),
            ),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      if (_textController.text.trim().isNotEmpty) {
        _translateText(_textController.text);
      }
    }
  }

  /// Chọn ảnh từ Camera hoặc Thư viện và dịch
  Future<void> _pickAndTranslateImage(ImageSource source) async {
    // 1. Kiểm tra quyền
    if (source == ImageSource.camera) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng cấp quyền Camera để chụp ảnh!')),
          );
        }
        return;
      }
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _isLoading = true;
        _translatedText = 'Đang nhận diện chữ từ ảnh...';
      });

      // 2. Chọn script nhận diện chữ phù hợp theo ngôn ngữ nguồn
      TextRecognitionScript script = TextRecognitionScript.latin;
      if (_sourceLang == TranslateLanguage.chinese) {
        script = TextRecognitionScript.chinese;
      } else if (_sourceLang == TranslateLanguage.japanese) {
        script = TextRecognitionScript.japanese;
      } else if (_sourceLang == TranslateLanguage.korean) {
        script = TextRecognitionScript.korean;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: script);

      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        final extractedText = recognizedText.text.trim();

        if (extractedText.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không tìm thấy văn bản nào trong ảnh. Hãy thử ảnh rõ nét hơn!'),
                duration: Duration(seconds: 3),
              ),
            );
            setState(() {
              _isLoading = false;
              _translatedText = 'Không phát hiện chữ trong ảnh.';
            });
          }
          return;
        }

        setState(() {
          _textController.text = extractedText;
        });

        // 3. Tiến hành dịch tự động
        await _translateText(extractedText);
      } finally {
        textRecognizer.close();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _translatedText = 'Lỗi xử lý ảnh: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi nhận diện ảnh: $e')),
        );
      }
    }
  }



  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      _initTranslator();
      if (_translatedText.isNotEmpty && !_translatedText.startsWith('Lỗi') && !_translatedText.startsWith('Đang')) {
        _textController.text = _translatedText;
        _translateText(_textController.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google ML Kit Translate'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TranslateLanguage>(
                        isExpanded: true,
                        value: _sourceLang,
                        onChanged: (TranslateLanguage? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _sourceLang = newValue;
                              _initTranslator();
                            });
                          }
                        },
                        items: _languages.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: Colors.teal),
                    tooltip: 'Đổi chiều ngôn ngữ',
                    onPressed: _swapLanguages,
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TranslateLanguage>(
                        isExpanded: true,
                        value: _targetLang,
                        onChanged: (TranslateLanguage? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _targetLang = newValue;
                              _initTranslator();
                            });
                          }
                        },
                        items: _languages.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Nhập văn bản cần dịch, bấm Dịch Voice hoặc Dịch Ảnh...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _textController.clear();
                            _translatedText = '';
                            _selectedImage = null;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _translateText(_textController.text),
                  icon: const Icon(Icons.translate),
                  label: const Text('Dịch Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _listen,
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  label: Text(_isListening ? 'Đang nghe...' : 'Dịch Voice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickAndTranslateImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Chụp ảnh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickAndTranslateImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Thư viện'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RealtimeCameraTranslateScreen(
                          initialSourceLang: _sourceLang,
                          initialTargetLang: _targetLang,
                        ),
                      ),
                    );
                    if (result != null && result.isNotEmpty) {
                      setState(() {
                        _translatedText = result;
                      });
                    }
                  },
                  icon: const Icon(Icons.videocam),
                  label: const Text('Dịch Realtime (Lia Camera)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Đã chọn ảnh thành công',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      tooltip: 'Bỏ ảnh',
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              color: Colors.teal[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                constraints: const BoxConstraints(minHeight: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kết quả dịch:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _translatedText.isEmpty ? 'Nội dung dịch sẽ hiển thị ở đây...' : _translatedText,
                      style: TextStyle(
                        fontSize: 18,
                        color: _translatedText.isEmpty ? Colors.grey.shade500 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
