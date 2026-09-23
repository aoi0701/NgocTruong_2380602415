import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonalScreen extends StatelessWidget {
  const PersonalScreen({super.key});

  final String _phoneNumber = '0337474099';
  final String _userName = 'Đỗ Minh Nhật';

  Future<void> _makeCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: _phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch $launchUri');
    }
  }

  Future<void> _openYouTube() async {
    final Uri youtubeUri = Uri.parse('https://www.youtube.com');
    if (await canLaunchUrl(youtubeUri)) {
      await launchUrl(youtubeUri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $youtubeUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                _userName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _makeCall,
                icon: const Icon(Icons.phone),
                label: Text('Gọi điện đến SĐT ($_phoneNumber)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _openYouTube,
                icon: const Icon(Icons.video_library),
                label: const Text('Gọi tới App YouTube'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
