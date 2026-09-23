import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key});

  final List<Map<String, String>> members = const [
    {
      'name': 'Đỗ Minh Nhật',
      'id': 'Thành viên nhóm',
      'phone': '0337474099',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSGQr4vSTzTPnM6JMqYxvsP9xS8wSvjcw8kMw&s'
    },
    {
      'name': 'Nguyễn Phan Ngọc Trưởng',
      'id': 'Thành viên nhóm',
      'phone': 'Đang cập nhật',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSGQr4vSTzTPnM6JMqYxvsP9xS8wSvjcw8kMw&s'
    },
    {
      'name': 'Tưởng Hoàng'
          ' Thiện',
      'id': 'Thành viên nhóm',
      'phone': '0388697937',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSGQr4vSTzTPnM6JMqYxvsP9xS8wSvjcw8kMw&s'
    },
    {
      'name': 'Lê Quốc Anh',
      'id': 'Thành viên nhóm',
      'phone': '0368774011',
      'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSGQr4vSTzTPnM6JMqYxvsP9xS8wSvjcw8kMw&s'
    },
  ];

  Future<void> _makeCall(String phoneNumber) async {
    if (phoneNumber == 'Đang cập nhật') return;
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin nhóm'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: CarouselSlider(
          options: CarouselOptions(
            height: 450.0,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
          ),
          items: members.map((member) {
            return Builder(
              builder: (BuildContext context) {
                return Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Image.network(
                            member['image']!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          member['name']!,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          member['id']!,
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 15),
                        InkWell(
                          onTap: () => _makeCall(member['phone']!),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone, color: Colors.green),
                              const SizedBox(width: 10),
                              Text(
                                member['phone']!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.green,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
