import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'TemperatureConverterScreen.dart';
import 'UnitConverterScreen.dart';
import 'YouTubePlayerScreen.dart';
import 'AlarmScreen.dart';
import 'StopwatchScreen.dart';
import 'TranslateScreen.dart';
import 'PersonalScreen.dart';
import 'GroupInfoScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Danh sách các Widget tương ứng với từng Tab điều hướng
  final List<Widget> _screens = [
    // Tab 1: Công cụ (Chuyển đổi, YouTube, Bấm giờ đặt chung làm 1 giao diện tiện ích hoặc danh sách)
    const MainToolsList(),
    // Tab 2: Báo thức giọng nói
    const AlarmScreen(),
    // Tab 3: Dịch thuật ML Kit
    const TranslateScreen(),
    // Tab 4: Thông tin nhóm
    const GroupInfoScreen(),
    // Tab 5: Cá nhân
    const PersonalScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(.1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
          child: GNav(
            rippleColor: Colors.grey[300]!,
            hoverColor: Colors.grey[100]!,
            gap: 8,
            activeColor: Colors.deepOrange,
            iconSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: Colors.deepOrange.withOpacity(0.1),
            color: Colors.black54,
            tabs: const [
              GButton(icon: Icons.home, text: 'Trang chủ'),
              GButton(icon: Icons.alarm, text: 'Báo thức'),
              GButton(icon: Icons.translate, text: 'Dịch thuật'),
              GButton(icon: Icons.group, text: 'Nhóm'),
              GButton(icon: Icons.person, text: 'Cá nhân'),
            ],
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}

// Widget phụ hiển thị danh sách các công cụ nhỏ (Chuyển đổi, Youtube, Bấm giờ) ở Tab Trang chủ
class MainToolsList extends StatelessWidget {
  const MainToolsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhom_3_nguoi - Công cụ'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuButton(context, 'Chuyển đổi nhiệt độ', Icons.thermostat, const TemperatureConverterScreen()),
              _buildMenuButton(context, 'Chuyển đổi đơn vị đo', Icons.straighten, const UnitConverterScreen()),
              _buildMenuButton(context, 'Xem Video YouTube', Icons.video_library, const YouTubePlayerScreen()),
              _buildMenuButton(context, 'Đồng hồ bấm giờ', Icons.timer, const StopwatchScreen()),
              
              const SizedBox(height: 30),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSGQr4vSTzTPnM6JMqYxvsP9xS8wSvjcw8kMw&s',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon, Widget screen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 25.0),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
          },
          icon: Icon(icon),
          label: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepOrange,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }
}
