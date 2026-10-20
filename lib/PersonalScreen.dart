import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final String _phoneNumber = '0337474099';
  final String _userName = 'Nguyễn Phan Ngọc Trưởng';

  final TextEditingController _linkController = TextEditingController();

  Future<void> _makeCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: _phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        final bool ok = await launchUrl(launchUri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể mở ứng dụng gọi điện cho số $_phoneNumber')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi mở cuộc gọi: $e')),
        );
      }
    }
  }

  Future<void> _openVideoOnYouTubeApp() async {
    String input = _linkController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập link YouTube hoặc mã video!')),
      );
      return;
    }

    // Trích xuất video ID nếu có (ví dụ dQw4w9WgXcQ hoặc link full)
    String? videoId = YoutubePlayerController.convertUrlToId(input);
    if (videoId == null && input.length == 11 && !input.contains('/')) {
      videoId = input;
    }

    // Nếu tìm thấy video ID: ưu tiên mở thẳng App YouTube qua vnd.youtube:<id>
    if (videoId != null) {
      final Uri appUri = Uri.parse('vnd.youtube:$videoId');
      final Uri webUri = Uri.parse('https://www.youtube.com/watch?v=$videoId');

      try {
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể mở video trên YouTube: $e')),
          );
        }
        return;
      }
    }

    // Nếu là URL web YouTube khác
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      input = 'https://$input';
    }
    final Uri targetUri = Uri.parse(input);
    try {
      await launchUrl(targetUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở liên kết: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const CircleAvatar(
                radius: 48,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                _userName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _makeCall,
                icon: const Icon(Icons.phone),
                label: Text('Gọi điện đến SĐT ($_phoneNumber)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Khung Xem Video YouTube trên App YouTube
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.video_library, color: Colors.red, size: 26),
                          SizedBox(width: 8),
                          Text(
                            'Xem Video trên App YouTube',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Điền link YouTube hoặc mã video bên dưới, bấm "Xem" để mở xem trực tiếp trên App YouTube:',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _linkController,
                        decoration: InputDecoration(
                          hintText: 'Dán link YouTube tại đây...',
                          prefixIcon: const Icon(Icons.link, color: Colors.red),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _linkController.clear(),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openVideoOnYouTubeApp,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text(
                          'Mở xem trên App YouTube',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
