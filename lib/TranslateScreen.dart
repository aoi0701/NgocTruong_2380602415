import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

  TranslateLanguage _sourceLang = TranslateLanguage.english;
  TranslateLanguage _targetLang = TranslateLanguage.vietnamese;

  late OnDeviceTranslator _translator;

  @override
  void initState() {
    super.initState();
    _initTranslator();
  }

  void _initTranslator() {
    _translator = OnDeviceTranslator(
      sourceLanguage: _sourceLang,
      targetLanguage: _targetLang,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _translator.close();
    super.dispose();
  }

  Future<void> _translateText(String text) async {
    if (text.isEmpty) return;
    try {
      final translation = await _translator.translateText(text);
      setState(() {
        _translatedText = translation;
      });
    } catch (e) {
      setState(() {
        _translatedText = 'Lỗi dịch thuật: $e';
      });
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: _sourceLang == TranslateLanguage.vietnamese ? 'vi_VN' : 'en_US',
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
            if (val.finalResult) {
              setState(() => _isListening = false);
              _translateText(val.recognizedWords);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickAndTranslateImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      _textController.text = recognizedText.text;
      await _translateText(recognizedText.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi nhận diện chữ từ ảnh: $e')),
      );
    } finally {
      textRecognizer.close();
    }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<TranslateLanguage>(
                  value: _sourceLang,
                  onChanged: (TranslateLanguage? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _sourceLang = newValue;
                        _initTranslator();
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: TranslateLanguage.english, child: Text('Tiếng Anh')),
                    DropdownMenuItem(value: TranslateLanguage.vietnamese, child: Text('Tiếng Việt')),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Icon(Icons.arrow_forward),
                ),
                DropdownButton<TranslateLanguage>(
                  value: _targetLang,
                  onChanged: (TranslateLanguage? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _targetLang = newValue;
                        _initTranslator();
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: TranslateLanguage.vietnamese, child: Text('Tiếng Việt')),
                    DropdownMenuItem(value: TranslateLanguage.english, child: Text('Tiếng Anh')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Nhập văn bản cần dịch...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _translateText(_textController.text),
                  icon: const Icon(Icons.translate),
                  label: const Text('Dịch Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _listen,
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  label: Text(_isListening ? 'Đang nghe...' : 'Dịch Voice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAndTranslateImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Dịch Ảnh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Card(
              color: Colors.teal[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                constraints: const BoxConstraints(minHeight: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kết quả dịch:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                    const SizedBox(height: 10),
                    Text(_translatedText, style: const TextStyle(fontSize: 18)),
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
