import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/attendance_service.dart';
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
  bool _isLoadingHistory = false;
  String? _historyError;
  List<AttendanceRecord> _historyList = [];
  AttendanceRecord? _todayRecord;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStaffInfo();
    _fetchAttendanceHistory();
  }

  Future<void> _loadStaffInfo() async {
    final name = await Auth.getUsername();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _staffName = name);
    }
  }

  Future<void> _fetchAttendanceHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final records = await AttendanceService.instance.getMyHistory();
      if (!mounted) return;

      // Sắp xếp bản ghi mới nhất lên đầu
      records.sort((a, b) {
        final aTime = a.checkInTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.checkInTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      // Tìm bản ghi ngày hôm nay
      AttendanceRecord? today;
      final now = DateTime.now();
      for (final r in records) {
        if (r.checkInTime != null &&
            r.checkInTime!.year == now.year &&
            r.checkInTime!.month == now.month &&
            r.checkInTime!.day == now.day) {
          today = r;
          break;
        }
      }

      setState(() {
        _historyList = records;
        _todayRecord = today;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isActionLoading = true);
    try {
      final result = await AttendanceService.instance.checkIn(
        method: 'DASHBOARD',
        notes: 'Chấm công vào ca trực tiếp trên ứng dụng',
      );

      if (!mounted) return;
      setState(() => _isActionLoading = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
            backgroundColor: Colors.green[700],
          ),
        );
        // Tải lại lịch sử thực tế từ SQL Server
        await _fetchAttendanceHistory();
      } else {
        _showErrorDialog('Check-in thất bại', result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      _showErrorDialog('Lỗi kết nối', e.toString());
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() => _isActionLoading = true);
    try {
      final result = await AttendanceService.instance.checkOut(
        method: 'DASHBOARD',
        notes: 'Chấm công ra ca trực tiếp trên ứng dụng',
      );

      if (!mounted) return;
      setState(() => _isActionLoading = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
            backgroundColor: Colors.blue[700],
          ),
        );
        // Tải lại lịch sử thực tế từ SQL Server
        await _fetchAttendanceHistory();
      } else {
        _showErrorDialog('Check-out thất bại', result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      _showErrorDialog('Lỗi kết nối', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới lịch sử',
            onPressed: _fetchAttendanceHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAttendanceHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner chào mừng nhân viên
              _buildWelcomeBanner(),
              const SizedBox(height: 20),

              // Khối Thông tin ca làm việc hôm nay & Nút Check-in / Check-out
              _buildTodayShiftCard(),
              const SizedBox(height: 24),

              // Khối Lịch sử chấm công thực tế từ SQL Server
              _buildHistorySection(),
              const SizedBox(height: 24),

              // Khu vực tác nghiệp khác
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

              // Card 4: Chấm công & Điểm danh QR / GPS
              _buildFeatureCard(
                title: 'Chấm công nâng cao (QR & GPS)',
                subtitle: 'Quét mã QR địa điểm làm việc hoặc xác thực tọa độ GPS thời gian thực.',
                icon: Icons.qr_code_scanner_rounded,
                color: Colors.purple,
                buttonText: 'Mở Quét QR / GPS',
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
                            title: const Text('1. Quét mã QR chấm công địa điểm'),
                            subtitle: const Text('Nhận diện mã điểm danh bằng camera máy ảnh'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BiometricQrScreen()),
                              );
                              _fetchAttendanceHistory();
                            },
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.location_on, color: Colors.white),
                            ),
                            title: const Text('2. Điểm danh định vị GPS thực tế'),
                            subtitle: const Text('Xác thực khoảng cách tại cơ sở Trường ĐH HUTECH'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LocationShareScreen()),
                              );
                              _fetchAttendanceHistory();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
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
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.badge_rounded, color: Colors.white, size: 30),
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
    );
  }

  Widget _buildTodayShiftCard() {
    final now = DateTime.now();
    final dateStr = 'Hôm nay: Ngày ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final checkInStr = _todayRecord?.checkInTime != null
        ? '${_todayRecord!.checkInTime!.hour.toString().padLeft(2, '0')}:${_todayRecord!.checkInTime!.minute.toString().padLeft(2, '0')}:${_todayRecord!.checkInTime!.second.toString().padLeft(2, '0')}'
        : '--:--';

    final checkOutStr = _todayRecord?.checkOutTime != null
        ? '${_todayRecord!.checkOutTime!.hour.toString().padLeft(2, '0')}:${_todayRecord!.checkOutTime!.minute.toString().padLeft(2, '0')}:${_todayRecord!.checkOutTime!.second.toString().padLeft(2, '0')}'
        : '--:--';

    final durationStr = _todayRecord != null ? _todayRecord!.durationText : 'Chưa có dữ liệu';

    final bool hasCheckedIn = _todayRecord?.checkInTime != null;
    final bool hasCheckedOut = _todayRecord?.checkOutTime != null;

    Color statusColor = Colors.grey;
    String statusLabel = 'Chưa vào ca';
    if (hasCheckedIn && !hasCheckedOut) {
      statusColor = Colors.green;
      statusLabel = 'Đang trong ca trực';
    } else if (hasCheckedIn && hasCheckedOut) {
      statusColor = Colors.blue;
      statusLabel = 'Đã hoàn thành ca';
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time_filled, color: Colors.teal[800], size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Ca làm việc hôm nay',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const Divider(height: 24),

            // Thông số ca làm việc
            Row(
              children: [
                Expanded(
                  child: _buildShiftMetric(
                    title: 'Giờ Check-in',
                    value: checkInStr,
                    icon: Icons.login,
                    color: Colors.green,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _buildShiftMetric(
                    title: 'Giờ Check-out',
                    value: checkOutStr,
                    icon: Icons.logout,
                    color: Colors.orange,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _buildShiftMetric(
                    title: 'Tổng giờ làm',
                    value: durationStr,
                    icon: Icons.timer,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nút bấm Check-in và Check-out
            if (_isActionLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Vào ca (Check-in)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleCheckOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Ra ca (Check-out)'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftMetric({
    required String title,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lịch sử chấm công SQL Server',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_historyList.isNotEmpty)
              Text(
                '${_historyList.length} lượt',
                style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_historyError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              children: [
                Text(
                  'Không thể tải lịch sử từ máy chủ:\n$_historyError',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[900], fontSize: 13),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _fetchAttendanceHistory,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          )
        else if (_historyList.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Chưa có dữ liệu chấm công nào trên máy chủ.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _historyList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final record = _historyList[index];
              return _buildHistoryItem(record);
            },
          ),
      ],
    );
  }

  Widget _buildHistoryItem(AttendanceRecord record) {
    final methodStr = (record.method ?? 'MANUAL').toUpperCase();
    IconData methodIcon = Icons.fingerprint;
    Color methodColor = Colors.teal;
    if (methodStr.contains('GPS')) {
      methodIcon = Icons.location_on;
      methodColor = Colors.green;
    } else if (methodStr.contains('QR')) {
      methodIcon = Icons.qr_code;
      methodColor = Colors.purple;
    } else if (methodStr.contains('FACE')) {
      methodIcon = Icons.face;
      methodColor = Colors.indigo;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: methodColor.withValues(alpha: 0.15),
              child: Icon(methodIcon, color: methodColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        record.formattedCheckIn,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (record.isCompleted ? Colors.blue : Colors.orange).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.isCompleted ? 'Hoàn thành' : 'Đang trực',
                          style: TextStyle(
                            color: record.isCompleted ? Colors.blue[800] : Colors.orange[900],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ra ca: ${record.formattedCheckOut} • ${record.durationText}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  if (record.locationName != null && record.locationName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        'Địa điểm: ${record.locationName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ),
                ],
              ),
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
