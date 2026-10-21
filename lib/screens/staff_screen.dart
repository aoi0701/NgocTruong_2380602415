import 'dart:async';
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
  AttendanceRecord? _openShift; // Ca làm việc đang mở (checkOutTime == null)
  AttendanceRecord? _todayRecord; // Bản ghi ngày hôm nay
  bool _isActionLoading = false;

  Timer? _shiftTimer;
  Duration _elapsedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadStaffInfo();
    _fetchAttendanceHistory();
  }

  @override
  void dispose() {
    _stopShiftTimer();
    super.dispose();
  }

  void _startShiftTimer(DateTime checkInTime) {
    _stopShiftTimer();
    _elapsedDuration = DateTime.now().difference(checkInTime);
    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedDuration = DateTime.now().difference(checkInTime);
        });
      }
    });
  }

  void _stopShiftTimer() {
    _shiftTimer?.cancel();
    _shiftTimer = null;
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
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

      // Tìm ca mở (checkOutTime == null) & bản ghi hôm nay
      AttendanceRecord? openShift;
      AttendanceRecord? today;
      final now = DateTime.now();

      for (final r in records) {
        if (openShift == null && r.isOpenShift) {
          openShift = r;
        }
        if (today == null &&
            r.checkInTime != null &&
            r.checkInTime!.year == now.year &&
            r.checkInTime!.month == now.month &&
            r.checkInTime!.day == now.day) {
          today = r;
        }
      }

      setState(() {
        _historyList = records;
        _openShift = openShift;
        _todayRecord = today ?? openShift;
        _isLoadingHistory = false;
      });

      if (openShift != null && openShift.checkInTime != null) {
        _startShiftTimer(openShift.checkInTime!);
      } else {
        _stopShiftTimer();
        _elapsedDuration = Duration.zero;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    // Nếu đã có ca mở, tuyệt đối không gửi lại
    if (_openShift != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đang trong ca trực rồi! Vui lòng Ra ca trước khi bắt đầu ca mới.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      } else if (result.isConflict) {
        _showConflictDialog(result.message);
      } else {
        _showErrorDialog('Check-in thất bại', result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      _showErrorDialog(
        'Lỗi kết nối máy chủ',
        'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng của bạn.\nChi tiết: $e',
      );
    }
  }

  Future<void> _handleCheckOut() async {
    if (_openShift == null) {
      _showNotCheckedInDialog();
      return;
    }

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
      _showErrorDialog(
        'Lỗi kết nối máy chủ',
        'Không thể kết nối đến máy chủ khi check-out.\nChi tiết: $e',
      );
    }
  }

  void _showNotCheckedInDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Chưa vào ca làm việc'),
          ],
        ),
        content: const Text(
          'Bạn chưa vào ca làm việc nên không thể thực hiện Ra ca (Check-out).\n\n'
          'Vui lòng bấm nút "Vào ca (Check-in)" để bắt đầu ca trực mới.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showConflictDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Xung đột ca làm (409)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            const Text(
              'Quy định hệ thống: Mỗi nhân viên chỉ được duy trì 1 ca làm việc mở tại một thời điểm, '
              'hoặc cần đợi 5 phút giữa các lần chấm công để tránh bản ghi trùng lặp.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _fetchAttendanceHistory();
            },
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Tải lại trạng thái'),
          ),
        ],
      ),
    );
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
              const SizedBox(height: 18),

              // Khối Thông tin ca làm việc & Nút Check-in / Check-out (Single Open Shift)
              _buildShiftControlCard(),
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

  /// Khối Ca làm việc với quy tắc Single Open Shift
  Widget _buildShiftControlCard() {
    final now = DateTime.now();
    final dateStr = 'Ngày ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final bool hasOpenShift = _openShift != null;
    final activeRecord = _openShift ?? _todayRecord;

    final checkInStr = activeRecord?.checkInTime != null
        ? '${activeRecord!.checkInTime!.hour.toString().padLeft(2, '0')}:${activeRecord.checkInTime!.minute.toString().padLeft(2, '0')}:${activeRecord.checkInTime!.second.toString().padLeft(2, '0')}'
        : '--:--';

    final checkOutStr = activeRecord?.checkOutTime != null
        ? '${activeRecord!.checkOutTime!.hour.toString().padLeft(2, '0')}:${activeRecord.checkOutTime!.minute.toString().padLeft(2, '0')}:${activeRecord.checkOutTime!.second.toString().padLeft(2, '0')}'
        : (hasOpenShift ? 'Đang trong ca' : '--:--');

    return Card(
      elevation: hasOpenShift ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasOpenShift
            ? BorderSide(color: Colors.green[600]!, width: 2)
            : BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề trạng thái ca
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasOpenShift ? Icons.radio_button_checked : Icons.access_time_filled,
                      color: hasOpenShift ? Colors.green[700] : Colors.teal[800],
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Trạng thái ca làm việc',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasOpenShift
                        ? Colors.green.withValues(alpha: 0.15)
                        : (activeRecord?.isCompleted == true
                            ? Colors.blue.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasOpenShift
                          ? Colors.green[700]!
                          : (activeRecord?.isCompleted == true ? Colors.blue[700]! : Colors.grey),
                    ),
                  ),
                  child: Text(
                    hasOpenShift
                        ? '🟢 ĐANG TRONG CA TRỰC'
                        : (activeRecord?.isCompleted == true ? 'ĐÃ HOÀN THÀNH CA' : 'CHƯA VÀO CA'),
                    style: TextStyle(
                      color: hasOpenShift
                          ? Colors.green[800]
                          : (activeRecord?.isCompleted == true ? Colors.blue[800] : Colors.grey[700]),
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
            const Divider(height: 22),

            // NỔI BẬT NẾU ĐANG TRONG CA TRỰC: BỘ ĐẾM THỜI GIAN LÀM VIỆC THỜI GIAN THỰC
            if (hasOpenShift) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.teal[50]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, color: Colors.green[800], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'THỜI GIAN LÀM VIỆC HIỆN TẠI',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDuration(_elapsedDuration),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.green[900],
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Giờ vào ca: ${_openShift!.formattedCheckIn}',
                      style: TextStyle(color: Colors.teal[800], fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],

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
                    title: 'Tổng thời gian',
                    value: hasOpenShift
                        ? _formatDuration(_elapsedDuration)
                        : (activeRecord?.durationText ?? '--'),
                    icon: Icons.timer,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nút bấm Check-in và Check-out (Single Open Shift Control)
            if (_isActionLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Nút Vào ca: KÍCH HOẠT khi CHƯA có ca mở, VÔ HIỆU HÓA khi ĐANG có ca mở
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasOpenShift ? null : _handleCheckIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            disabledBackgroundColor: Colors.grey[300],
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.grey[600],
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Vào ca (Check-in)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nút Ra ca: KÍCH HOẠT khi ĐANG có ca mở, VÔ HIỆU HÓA khi CHƯA có ca mở
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasOpenShift ? _handleCheckOut : _showNotCheckedInDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasOpenShift ? Colors.orange[800] : Colors.grey[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Ra ca (Check-out)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasOpenShift
                        ? 'ℹ️ Bạn đang trong ca trực. Nút Vào ca đã vô hiệu hóa để ngăn tạo ca trùng lặp.'
                        : 'ℹ️ Bạn chưa có ca mở. Hãy bấm "Vào ca" để bắt đầu ghi nhận thời gian làm việc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: hasOpenShift ? Colors.green[800] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
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
