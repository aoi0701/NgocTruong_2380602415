import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'ConverterTabsScreen.dart';
import 'StopwatchScreen.dart';
import 'AlarmScreen.dart';
import 'TranslateScreen.dart';
import 'PersonalScreen.dart';
import 'GroupInfoScreen.dart';
import 'practice/practice_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _navigationGeneration = 0;

  // Danh sách các màn hình tương ứng với từng Tab ở Bottom Navigation Bar
  final List<Widget> _screens = const [
    ConverterTabsScreen(), // 1. Chuyển đổi (Nhiệt độ + Đơn vị đo)
    StopwatchScreen(), // 2. Đồng hồ bấm giờ
    AlarmScreen(), // 3. Báo thức giọng nói
    TranslateScreen(), // 4. Dịch thuật ML Kit
    GroupInfoScreen(), // 5. Thông tin nhóm
    PersonalScreen(), // 6. Thông tin cá nhân & Xem Video
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(.1)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: GNav(
                key: ValueKey(_navigationGeneration),
                rippleColor: Colors.grey[300]!,
                hoverColor: Colors.grey[100]!,
                gap: 6,
                activeColor: Colors.deepOrange,
                iconSize: 22,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                duration: const Duration(milliseconds: 300),
                tabBackgroundColor: Colors.deepOrange.withOpacity(0.1),
                color: Colors.black54,
                selectedIndex: _selectedIndex,
                onTabChange: (index) async {
                  if (index == _screens.length) {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const PracticeEntry()),
                    );
                    if (mounted) {
                      setState(() => _navigationGeneration++);
                    }
                    return;
                  }
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                tabs: const [
                  GButton(icon: Icons.swap_horiz, text: 'Chuyển đổi'),
                  GButton(icon: Icons.timer, text: 'Bấm giờ'),
                  GButton(icon: Icons.alarm, text: 'Báo thức'),
                  GButton(icon: Icons.translate, text: 'Dịch thuật'),
                  GButton(icon: Icons.group, text: 'Nhóm'),
                  GButton(icon: Icons.person, text: 'Cá nhân'),
                  GButton(
                    key: Key('practice-entry'),
                    icon: Icons.school_outlined,
                    text: 'Bài 6–7',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
