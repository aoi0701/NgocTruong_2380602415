import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubePlayerScreen extends StatefulWidget {
  const YouTubePlayerScreen({super.key});

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  final TextEditingController _linkController = TextEditingController();
  YoutubePlayerController? _controller;

  void _loadVideo() {
    final link = _linkController.text.trim();
    if (link.isEmpty) return;

    String? id = YoutubePlayerController.convertUrlToId(link);
    if (id == null && link.length == 11 && !link.contains('/')) {
      id = link;
    }
    if (id != null) {
      final videoId = id;
      setState(() {
        if (_controller == null) {
          _controller = YoutubePlayerController.fromVideoId(
            videoId: videoId,
            autoPlay: true,
            params: const YoutubePlayerParams(
              showControls: true,
              showFullscreenButton: true,
              mute: false,
            ),
          );
        } else {
          _controller!.loadVideoById(videoId: videoId);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link YouTube không hợp lệ!')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem Video YouTube'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        hintText: 'Dán link YouTube tại đây...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loadVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Xem'),
                  ),
                ],
              ),
            ),
            if (_controller != null)
              YoutubePlayer(
                controller: _controller!,
                aspectRatio: 16 / 9,
              )
            else
              Container(
                height: 200,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('Nhập link để xem video'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
