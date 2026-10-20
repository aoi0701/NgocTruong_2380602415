import 'package:flutter/material.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedCommand = '';

  @override
  void dispose() async {
    _speech.stop();
    super.dispose();
    await _stopWatchTimer.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      // Xin quyền mic
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

      bool available = await _speech.initialize(
        onError: (e) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
            cancelOnError: false,
          ),
          onResult: (val) {
            final command = val.recognizedWords.toLowerCase();
            setState(() {
              _recognizedCommand = val.recognizedWords;
            });

            if (command.contains('bắt đầu') || command.contains('start') || command.contains('chạy')) {
              _stopWatchTimer.onStartTimer();
            } else if (command.contains('dừng') || command.contains('stop') || command.contains('tạm dừng')) {
              _stopWatchTimer.onStopTimer();
            } else if (command.contains('đặt lại') || command.contains('reset') || command.contains('làm mới')) {
              _stopWatchTimer.onResetTimer();
            }

            if (val.finalResult) {
              setState(() => _isListening = false);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đồng hồ bấm giờ')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 35),
              IconButton(
                iconSize: 64,
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.blue),
                onPressed: _listen,
              ),
              Text(
                _isListening ? 'Đang nghe... Nói: Bắt đầu / Dừng / Đặt lại' : 'Nhấn để ra lệnh giọng nói (Bắt đầu, Dừng, Đặt lại)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isListening ? Colors.red : Colors.black87,
                  fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (_recognizedCommand.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Lệnh nhận diện: "$_recognizedCommand"',
                  style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
