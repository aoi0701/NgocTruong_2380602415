import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentLanguage = 'vi_VN'; // 'vi_VN' hoặc 'en_US'

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
        SnackBar(content: Text('Đã đặt báo thức lúc ${_selectedTime.format(context)}')),
      );
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: _currentLanguage,
          onResult: (val) {
            String text = val.recognizedWords.toLowerCase();
            // Tiếng Việt: "báo thức lúc 7 giờ 30" hoặc Tiếng Anh: "alarm at 7 thirty" / "alarm at 7 30"
            RegExp regExpVi = RegExp(r'(\d+)\s*giờ\s*(\d*)');
            RegExp regExpEn = RegExp(r'(?:alarm at|set time to)\s*(\d+)\s*(\d*)');
            
            var matchVi = regExpVi.firstMatch(text);
            var matchEn = regExpEn.firstMatch(text);

            if (matchVi != null) {
              int hour = int.parse(matchVi.group(1)!);
              int minute = matchVi.group(2) != "" ? int.parse(matchVi.group(2)!) : 0;
              setState(() {
                _selectedTime = TimeOfDay(hour: hour, minute: minute);
              });
            } else if (matchEn != null) {
              int hour = int.parse(matchEn.group(1)!);
              int minute = matchEn.group(2) != "" ? int.parse(matchEn.group(2)!) : 0;
              setState(() {
                _selectedTime = TimeOfDay(hour: hour, minute: minute);
              });
            }
            if (val.finalResult) {
              setState(() => _isListening = false);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đồng hồ báo thức')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Ngôn ngữ nói: '),
                DropdownButton<String>(
                  value: _currentLanguage,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _currentLanguage = newValue;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'vi_VN', child: Text('Tiếng Việt')),
                    DropdownMenuItem(value: 'en_US', child: Text('Tiếng Anh (English)')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Giờ đã chọn: ${_selectedTime.format(context)}',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickTime,
              child: const Text('Chọn giờ'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _setAlarm,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Đặt báo thức'),
            ),
            const SizedBox(height: 40),
            IconButton(
              iconSize: 64,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.orange),
              onPressed: _listen,
            ),
            Text(_currentLanguage == 'vi_VN' 
              ? 'Nói: "Báo thức lúc X giờ Y phút"' 
              : 'Say: "Alarm at X Y" (e.g. Alarm at 7 30)'),
          ],
        ),
      ),
    );
  }
}
