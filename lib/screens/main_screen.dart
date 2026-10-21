import 'package:flutter/material.dart';
import '../utils/auth.dart';
import 'login_screen.dart';
import 'market_screen.dart';
import 'feed_screen.dart';
import '../HomeScreen.dart';
import 'biometric_qr_screen.dart';
import 'location_share_screen.dart';
import 'admin_screen.dart';
import 'staff_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _username = 'User';
  String _role = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final name = await Auth.getUsername();
    final role = await Auth.getRole();
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _username = name;
        if (role != null && role.isNotEmpty) _role = role;
      });
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Auth.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3 Tab: Tổng quan (Dashboard) với các nút dẫn, Chợ sản phẩm (MarketScreen), Bảng tin (FeedScreen)
    final List<Widget> pages = [
      _buildDashboardHome(),
      const MarketScreen(),
      const FeedScreen(),
    ];

    return Scaffold(
      // Khi ở tab 0, hiển thị AppBar chính của MainScreen với Lời chào và nút Đăng xuất
      // Khi chuyển sang MarketScreen hoặc FeedScreen, sử dụng AppBar chuyên biệt của màn hình đó
      appBar: _currentIndex == 0
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hutech Social Hub',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Xin chào, $_username ($_role)',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.apps_rounded),
                  tooltip: 'Mở Tiện ích Hutech (Bộ công cụ)',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Đăng xuất',
                  onPressed: _handleLogout,
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Chợ sản phẩm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed),
            label: 'Bảng tin',
          ),
        ],
      ),
    );
  }

  // Giao diện Trang chủ Dashboard với các card dẫn tới MarketScreen, FeedScreen và HomeScreen
  Widget _buildDashboardHome() {
    final bool isAdmin = _role.trim().toUpperCase() == 'ADMIN';
    final bool isStaff = _role.trim().toUpperCase() == 'STAFF';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner chào mừng người dùng
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[900]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Text(
                    _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chào mừng, $_username!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vai trò: $_role • Xác thực JWT thành công',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Lối tắt quản trị đặc quyền nếu là Admin hoặc Staff
          if (isAdmin) ...[
            _buildFeatureCard(
              title: 'Admin Dashboard (Quản trị viên)',
              subtitle: 'Quản lý toàn bộ danh mục sản phẩm, duyệt ca chấm công và phân quyền nhân viên.',
              icon: Icons.admin_panel_settings_rounded,
              color: Colors.deepPurple,
              buttonText: 'Mở Admin Dashboard',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          if (isStaff) ...[
            _buildFeatureCard(
              title: 'Dashboard Nhân Viên (Staff)',
              subtitle: 'Giao diện quản lý ca làm việc, xem trạng thái đang trực và lịch sử chấm công.',
              icon: Icons.badge_rounded,
              color: Colors.teal,
              buttonText: 'Mở Dashboard Nhân Viên',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Chức năng chính',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Nút dẫn tới MarketScreen (Chợ sản phẩm)
          _buildFeatureCard(
            title: 'Chợ sản phẩm (MarketScreen)',
            subtitle: 'Xem danh sách sản phẩm, lọc theo danh mục, tìm kiếm theo tên hoặc ID sản phẩm.',
            icon: Icons.storefront,
            color: Colors.teal,
            buttonText: 'Truy cập Chợ sản phẩm',
            onTap: () {
              setState(() => _currentIndex = 1);
            },
          ),
          const SizedBox(height: 16),

          // Nút dẫn tới FeedScreen (Bảng tin bài đăng)
          _buildFeatureCard(
            title: 'Bảng tin bài đăng (FeedScreen)',
            subtitle: 'Đăng trạng thái, chia sẻ bài viết, tương tác Thích & Bình luận phong cách Facebook.',
            icon: Icons.dynamic_feed,
            color: Colors.indigo,
            buttonText: 'Xem Bảng tin sinh viên',
            onTap: () {
              setState(() => _currentIndex = 2);
            },
          ),
          const SizedBox(height: 16),

          // Nút dẫn tới HomeScreen (Bộ tiện ích HUTECH)
          _buildFeatureCard(
            title: 'Tiện ích sinh viên HUTECH',
            subtitle: 'Báo thức giọng nói, Đồng hồ bấm giờ, Chuyển đổi đơn vị & nhiệt độ, Dịch thuật ML Kit.',
            icon: Icons.construction,
            color: Colors.deepOrange,
            buttonText: 'Mở Tiện ích',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Nút dẫn tới Nhận diện mã QR & Sinh trắc học (Câu 5)
          _buildFeatureCard(
            title: 'Nhận diện QR & Sinh trắc học',
            subtitle: 'Quét nhận diện mã sản phẩm, điểm danh sinh viên HUTECH và tạo mã QR cá nhân.',
            icon: Icons.qr_code_scanner_rounded,
            color: Colors.purple,
            buttonText: 'Mở Quét QR',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BiometricQrScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          // Nút dẫn tới Điểm danh GPS & Chia sẻ vị trí
          _buildFeatureCard(
            title: 'Điểm danh & Chia sẻ vị trí GPS',
            subtitle: 'Xác thực tọa độ định vị GPS thực tế tại cơ sở HUTECH và chia sẻ vị trí qua bản đồ.',
            icon: Icons.location_on_rounded,
            color: Colors.teal,
            buttonText: 'Mở Định vị GPS',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocationShareScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
