import 'package:flutter/material.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void dispose() async {
    super.dispose();
    await _stopWatchTimer.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          String command = val.recognizedWords.toLowerCase();
          if (command.contains('bắt đầu') || command.contains('start')) {
            _stopWatchTimer.onStartTimer();
          } else if (command.contains('dừng') || command.contains('stop')) {
            _stopWatchTimer.onStopTimer();
          } else if (command.contains('đặt lại') || command.contains('reset')) {
            _stopWatchTimer.onResetTimer();
          }
          setState(() => _isListening = false);
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đồng hồ bấm giờ')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<int>(
              stream: _stopWatchTimer.rawTime,
              initialData: 0,
              builder: (context, snap) {
                final value = snap.data!;
                final displayTime = StopWatchTimer.getDisplayTime(value);
                return Text(
                  displayTime,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _stopWatchTimer.onStartTimer(),
                  child: const Text('Bắt đầu'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _stopWatchTimer.onStopTimer(),
                  child: const Text('Dừng'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _stopWatchTimer.onResetTimer(),
                  child: const Text('Đặt lại'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            IconButton(
              iconSize: 64,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.blue),
              onPressed: _listen,
            ),
            const Text('Nhấn để ra lệnh giọng nói (Bắt đầu, Dừng, Đặt lại)'),
          ],
        ),
      ),
    );
  }
}
