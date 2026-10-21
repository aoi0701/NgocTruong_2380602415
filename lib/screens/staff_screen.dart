import 'package:flutter/material.dart';
import '../utils/auth.dart';
import 'login_screen.dart';
import 'market_screen.dart';
import 'feed_screen.dart';
import '../HomeScreen.dart';
import 'biometric_qr_screen.dart';
import 'location_share_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String _staffName = 'Nhân viên';

  @override
  void initState() {
    super.initState();
    _loadStaffInfo();
  }

  Future<void> _loadStaffInfo() async {
    final name = await Auth.getUsername();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _staffName = name);
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản nhân viên?'),
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Nhân Viên',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Nhân viên: $_staffName (Staff)',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner chào mừng nhân viên
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[700]!, Colors.teal[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: const Icon(Icons.badge_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, $_staffName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Vai trò: Nhân viên vận hành • Đã xác thực OTP',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Khu vực tác nghiệp nhân viên',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Card 1: Chợ sản phẩm
            _buildFeatureCard(
              title: 'Quản lý Sản phẩm (MarketScreen)',
              subtitle: 'Tra cứu, xem thông tin chi tiết theo ID, cập nhật giá và thêm sản phẩm mới vào danh mục.',
              icon: Icons.storefront_rounded,
              color: Colors.teal,
              buttonText: 'Mở Chợ sản phẩm',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // Card 2: Bảng tin bài viết
            _buildFeatureCard(
              title: 'Kiểm duyệt Bảng tin (FeedScreen)',
              subtitle: 'Xem các bài đăng của sinh viên/khách hàng, tương tác và quản lý nội dung bài viết.',
              icon: Icons.dynamic_feed_rounded,
              color: Colors.indigo,
              buttonText: 'Mở Bảng tin',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // Card 3: Tiện ích HUTECH
            _buildFeatureCard(
              title: 'Bộ tiện ích HUTECH',
              subtitle: 'Mở bộ công cụ phụ trợ (Chuyển đổi nhiệt độ/đơn vị, Báo thức, Bấm giờ, Dịch thuật).',
              icon: Icons.construction_rounded,
              color: Colors.deepOrange,
              buttonText: 'Mở Tiện ích',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // Card 4: Chấm công & Điểm danh QR
            _buildFeatureCard(
              title: 'Chấm công & Điểm danh QR',
              subtitle: 'Quét mã QR địa điểm làm việc hoặc xác thực tọa độ GPS để chấm công ca trực nhân viên.',
              icon: Icons.qr_code_scanner_rounded,
              color: Colors.purple,
              buttonText: 'Mở Quét QR Chấm công',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.purple,
                            child: Icon(Icons.qr_code_scanner, color: Colors.white),
                          ),
                          title: const Text('1. Quét mã QR chấm công / Thẻ nhân viên'),
                          subtitle: const Text('Nhận diện mã điểm danh bằng camera hoặc ảnh'),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const BiometricQrScreen()),
                            );
                          },
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.location_on, color: Colors.white),
                          ),
                          title: const Text('2. Điểm danh định vị GPS'),
                          subtitle: const Text('Xác thực khoảng cách tại trụ sở làm việc HUTECH'),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LocationShareScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
