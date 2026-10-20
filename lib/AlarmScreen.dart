import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  bool _autoSetAlarm = true;
  String _currentLanguage = 'vi_VN';
  String _recognizedText = '';
  String _statusMessage = '';

  static const Map<String, String> _languages = {
    'vi_VN': 'Tiếng Việt',
    'en_US': 'English (Tiếng Anh)',
    'fr_FR': 'Français (Tiếng Pháp)',
    'ja_JP': '日本語 (Tiếng Nhật)',
    'ko_KR': '한국어 (Tiếng Hàn)',
    'zh_CN': '中文 (Tiếng Trung)',
    'es_ES': 'Español (Tây Ban Nha)',
    'de_DE': 'Deutsch (Tiếng Đức)',
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechInitialized = await _speech.initialize(
        onError: (val) {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (val.errorMsg == 'error_speech_timeout' || val.errorMsg == 'error_no_match') {
                _statusMessage = 'Chưa bắt được âm thanh từ mic laptop/máy ảo. Hãy bật mic host hoặc dùng nút "Nhập lệnh phím".';
              } else {
                _statusMessage = 'Thông báo mic: ${val.errorMsg}';
              }
            });
          }
        },
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
            }
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  String _getGuideText() {
    switch (_currentLanguage) {
      case 'vi_VN':
        return 'Nói: "Báo thức lúc 7 giờ 30" hoặc "7h30", "bảy giờ rưỡi", "8 giờ tối"';
      case 'en_US':
        return 'Say: "Alarm at 7:30", "Seven thirty", or "Set alarm for 8:15 PM"';
      case 'fr_FR':
        return 'Dites: "Réveil à 7 heures 30" ou "8h30"';
      case 'ja_JP':
        return '「7時30分にアラーム」または「7:30」と言ってください';
      case 'ko_KR':
        return '"7시 30분 알람" 또는 "7:30"이라고 말하세요';
      case 'zh_CN':
        return '说: "7点30分闹钟" 或 "晚上8点"';
      case 'es_ES':
        return 'Diga: "Alarma a las 7 y 30" o "7:30"';
      case 'de_DE':
        return 'Sagen: "Wecker auf 7 Uhr 30" hoặc "7:30"';
      default:
        return 'Nói giờ muốn đặt (VD: 7:30)';
    }
  }

  /// Chuyển đổi các chữ số dạng chữ (tiếng Việt, tiếng Anh) thành dạng số
  String _normalizeWordsToNumbers(String input) {
    var text = input.toLowerCase();

    // Các từ ghép nhiều chữ trước
    final compoundReplacements = {
      'mười chín': '19', 'mười tám': '18', 'mười bảy': '17', 'mười sáu': '16',
      'mười lăm': '15', 'mười bốn': '14', 'mười ba': '13', 'mười hai': '12',
      'mười một': '11', 'mười': '10',
      'hai mươi mốt': '21', 'hai mốt': '21', 'hai mươi lăm': '25', 'hai lăm': '25',
      'hai mươi': '20', 'hăm mươi': '20', 'hăm': '20',
      'ba mươi lăm': '35', 'ba lăm': '35', 'ba mươi': '30',
      'bốn mươi lăm': '45', 'bốn lăm': '45', 'bốn mươi': '40',
      'năm mươi lăm': '55', 'năm lăm': '55', 'năm mươi': '50',
      // English compounds
      'twenty one': '21', 'twenty two': '22', 'twenty three': '23', 'twenty four': '24',
      'twenty five': '25', 'twenty six': '26', 'twenty seven': '27', 'twenty eight': '28',
      'twenty nine': '29', 'twenty': '20',
      'thirty five': '35', 'thirty': '30',
      'forty five': '45', 'forty': '40',
      'fifty five': '55', 'fifty': '50',
      'o clock': '00', "o'clock": '00',
      'nineteen': '19', 'eighteen': '18', 'seventeen': '17', 'sixteen': '16',
      'fifteen': '15', 'fourteen': '14', 'thirteen': '13', 'twelve': '12',
      'eleven': '11', 'ten': '10',
    };

    compoundReplacements.forEach((word, replacement) {
      text = text.replaceAll(RegExp('\\b$word\\b'), replacement);
    });

    // Các số đơn lẻ
    final singleReplacements = {
      'không': '0', 'zero': '0',
      'một': '1', 'mốt': '1', 'one': '1',
      'hai': '2', 'two': '2',
      'ba': '3', 'three': '3',
      'bốn': '4', 'tư': '4', 'four': '4',
      'năm': '5', 'five': '5',
      'sáu': '6', 'six': '6',
      'bảy': '7', 'bẩy': '7', 'seven': '7',
      'tám': '8', 'eight': '8',
      'chín': '9', 'nine': '9',
    };

    singleReplacements.forEach((word, replacement) {
      text = text.replaceAll(RegExp('\\b$word\\b'), replacement);
    });

    return text;
  }

  /// Phân tích câu nói đa ngôn ngữ để trích xuất giờ và phút
  TimeOfDay? _parseSpokenTime(String raw) {
    var text = _normalizeWordsToNumbers(raw).trim();
    if (text.isEmpty) return null;

    int? hour;
    int? minute;

    // 0. Xử lý dạng giờ kém tiếng Việt: "6 giờ kém 15" -> 5:45
    final kemMatch = RegExp(r'(\d{1,2})\s*(?:giờ|gio)\s*kém\s*(\d{1,2})').firstMatch(text);
    if (kemMatch != null) {
      int rawHour = int.tryParse(kemMatch.group(1)!) ?? 0;
      int minusMin = int.tryParse(kemMatch.group(2)!) ?? 0;
      hour = (rawHour - 1) % 24;
      minute = 60 - minusMin;
    }

    // 1. Dạng HH:MM hoặc H:MM (VD: 7:30, 07:30, 7.30)
    if (hour == null) {
      final colonMatch = RegExp(r'\b(\d{1,2})[:\.](\d{2})\b').firstMatch(text);
      if (colonMatch != null) {
        hour = int.tryParse(colonMatch.group(1)!);
        minute = int.tryParse(colonMatch.group(2)!);
      }
    }

    // 2. Dạng 7h30, 7h, 7H
    if (hour == null) {
      final hMatch = RegExp(r'\b(\d{1,2})\s*[hH]\s*(\d{1,2})?\b').firstMatch(text);
      if (hMatch != null) {
        hour = int.tryParse(hMatch.group(1)!);
        minute = hMatch.group(2) != null && hMatch.group(2)!.isNotEmpty
            ? int.tryParse(hMatch.group(2)!)
            : 0;
      }
    }

    // 3. Từ khóa giờ đa ngôn ngữ (giờ, hour, heure, uhr, hora, 点, 時, 시...)
    if (hour == null) {
      final multiLangMatch = RegExp(
        r'(\d{1,2})\s*(?:giờ|gio|hours?|hour|heures?|heure|uhr|horas?|hora|点|點|시|時|时)\s*(\d{1,2})?',
        caseSensitive: false,
      ).firstMatch(text);

      if (multiLangMatch != null) {
        hour = int.tryParse(multiLangMatch.group(1)!);
        minute = multiLangMatch.group(2) != null && multiLangMatch.group(2)!.isNotEmpty
            ? int.tryParse(multiLangMatch.group(2)!)
            : 0;
      }
    }

    // 4. Trường hợp đặc biệt: rưỡi, half, media
    if (hour != null && (text.contains('rưỡi') || text.contains('half') || text.contains('media'))) {
      minute = 30;
    }

    // 5. Dạng 2 số liền nhau: "alarm at 7 30", "báo thức 7 30", "7 30"
    if (hour == null) {
      final numbersMatch = RegExp(
        r'(?:báo thức|hẹn giờ|alarm|wecker|réveil|alarma)?\s*(?:lúc|at|for|à|auf|a las)?\s*(\d{1,2})\s+(\d{1,2})\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (numbersMatch != null && numbersMatch.group(1) != null && numbersMatch.group(2) != null) {
        hour = int.tryParse(numbersMatch.group(1)!);
        minute = int.tryParse(numbersMatch.group(2)!);
      }
    }

    // 6. Dạng 1 số duy nhất: "báo thức lúc 7", "alarm at 7", "7 o'clock"
    if (hour == null) {
      final singleNumMatch = RegExp(
        r'(?:báo thức|hẹn giờ|alarm|wecker|réveil|alarma)?\s*(?:lúc|at|for|à|auf|a las)?\s*(\d{1,2})\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (singleNumMatch != null) {
        hour = int.tryParse(singleNumMatch.group(1)!);
        minute = 0;
      }
    }

    // 7. Xử lý AM / PM / Buổi sáng, chiều, tối, đêm
    if (hour != null) {
      minute ??= 0;
      final isPm = RegExp(
        r'\b(pm|chiều|tối|night|evening|nachmittag|abend|soir|tarde|noche|오후|下午|午後)\b',
        caseSensitive: false,
      ).hasMatch(text);
      final isAm = RegExp(
        r'\b(am|sáng|morning|matin|mañana|morgen|오전|早上|午前)\b',
        caseSensitive: false,
      ).hasMatch(text);
      final isMidnight = text.contains('đêm') || text.contains('midnight');

      if (isMidnight && hour == 12) {
        hour = 0;
      } else if (isPm && hour < 12) {
        hour += 12;
      } else if (isAm && hour == 12) {
        hour = 0;
      }

      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return null;
  }

  /// Áp dụng câu lệnh văn bản từ giọng nói hoặc phím gõ
  Future<void> _applySpokenText(String text, {bool autoSet = true}) async {
    setState(() {
      _recognizedText = text;
    });

    final parsed = _parseSpokenTime(text);
    if (parsed != null) {
      setState(() {
        _selectedTime = parsed;
        _statusMessage = 'Đã nhận diện: ${_selectedTime.format(context)}';
      });

      if (autoSet && _autoSetAlarm) {
        await _setAlarm();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã cập nhật giờ: ${_selectedTime.format(context)}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      setState(() {
        _statusMessage = 'Chưa nhận diện được giờ từ câu: "$text". Hãy nói rõ hoặc dùng mẫu.';
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _setAlarm() async {
    final now = DateTime.now();
    DateTime alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    final alarmSettings = AlarmSettings(
      id: 42,
      dateTime: alarmDateTime,
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 3),
      ),
      notificationSettings: const NotificationSettings(
        title: 'Báo thức',
        body: 'Dậy thôi nào!',
        stopButton: 'Dừng',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ĐÃ ĐẶT BÁO THỨC LÚC ${_selectedTime.format(context)} THÀNH CÔNG!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _listen() async {
    if (!_isListening) {
      // 1. Kiểm tra và xin quyền microphone
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vui lòng cấp quyền Microphone để ra lệnh giọng nói!')),
            );
          }
          return;
        }
      }

      // 2. Đảm bảo SpeechToText đã được khởi tạo
      if (!_speechInitialized) {
        await _initSpeech();
      }

      if (_speech.isAvailable) {
        setState(() {
          _isListening = true;
          _statusMessage = 'Đang lắng nghe... Hãy nói giờ cần đặt!';
          _recognizedText = '';
        });

        _speech.listen(
          localeId: _currentLanguage,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.confirmation,
            partialResults: true,
            cancelOnError: false,
          ),
          onResult: (val) {
            if (val.recognizedWords.isNotEmpty) {
              setState(() {
                _recognizedText = val.recognizedWords;
              });
              final parsed = _parseSpokenTime(val.recognizedWords);
              if (parsed != null) {
                _applySpokenText(val.recognizedWords, autoSet: val.finalResult);
              }
            }
            if (val.finalResult) {
              setState(() => _isListening = false);
            }
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Micro không khả dụng. Bạn có thể dùng nút "Nhập lệnh phím" bên dưới để đặt giờ!'),
            ),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      if (_recognizedText.isNotEmpty) {
        _applySpokenText(_recognizedText, autoSet: true);
      }
    }
  }

  void _showTextInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.keyboard, color: Colors.orange),
              SizedBox(width: 8),
              Text('Nhập lệnh đặt giờ', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập câu lệnh bất kỳ (tiếng Việt, tiếng Anh...):',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'VD: báo thức 7h30, 8 giờ tối, alarm at 7:30...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (value) {
                  Navigator.pop(context);
                  if (value.trim().isNotEmpty) {
                    _applySpokenText(value.trim(), autoSet: true);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Gợi ý nhanh:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  '7h30',
                  '8 giờ tối',
                  'bảy giờ rưỡi sáng',
                  '6 giờ kém 15',
                  'Alarm at 8:15 PM',
                ].map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    textController.text = s;
                  },
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                if (textController.text.trim().isNotEmpty) {
                  _applySpokenText(textController.text.trim(), autoSet: true);
                }
              },
              child: const Text('Đặt ngay'),
            ),
          ],
        );
      },
    );
  }

  void _showTestCommandDialog() {
    final samples = [
      'Báo thức lúc 7 giờ 30',
      '7h30',
      'Bảy giờ rưỡi sáng',
      '8 giờ tối',
      'Sáu giờ kém mười lăm',
      'Alarm at 7 30',
      'Set alarm for 8:15 PM',
      'Alarm at eight o clock',
      'Réveil à 6 heures 45',
      '7時30分',
      '7시 30분',
      '7点30分',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thử nghiệm câu lệnh mẫu (Tự động đặt báo thức ngay):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: samples.map((sample) {
                  return ActionChip(
                    label: Text(sample),
                    onPressed: () {
                      Navigator.pop(context);
                      _applySpokenText(sample, autoSet: true);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đồng hồ báo thức'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Nhập lệnh phím',
            onPressed: _showTextInputDialog,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Lệnh mẫu',
            onPressed: _showTestCommandDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Ngôn ngữ nói: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _currentLanguage,
                    underline: const SizedBox(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _currentLanguage = newValue;
                        });
                      }
                    },
                    items: _languages.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Giờ đã chọn: ${_selectedTime.format(context)}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Chọn giờ thủ công'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _setAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.alarm_on),
                  label: const Text('Đặt báo thức'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Toggle tự động lưu báo thức khi ra lệnh giọng nói
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _autoSetAlarm,
                  activeColor: Colors.orange,
                  onChanged: (val) {
                    setState(() {
                      _autoSetAlarm = val ?? true;
                    });
                  },
                ),
                const Text(
                  'Tự động lưu báo thức ngay khi nói xong',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _listen,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red.shade100 : Colors.orange.shade100,
                  border: Border.all(
                    color: _isListening ? Colors.red : Colors.orange,
                    width: 3,
                  ),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 56,
                  color: _isListening ? Colors.red : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening ? 'Đang nghe... hãy nói giờ cần đặt!' : 'Nhấn vào Micro để nói',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isListening ? Colors.red : Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _getGuideText(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (_recognizedText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lời nói / Câu lệnh nhận diện được:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"$_recognizedText"',
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _statusMessage.contains('Đã nhận diện') ? Colors.green.shade700 : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (_statusMessage.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _showTextInputDialog,
                  icon: const Icon(Icons.keyboard, size: 18),
                  label: const Text('Nhập lệnh phím'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade900),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _showTestCommandDialog,
                  icon: const Icon(Icons.touch_app, size: 18),
                  label: const Text('Thử lệnh mẫu'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
