import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/config_url.dart';
import '../models/productPost.dart';
import '../services/api_client.dart';
import '../services/attendance_service.dart';
import 'main_screen.dart';

class BiometricQrScreen extends StatefulWidget {
  const BiometricQrScreen({super.key});

  @override
  State<BiometricQrScreen> createState() => _BiometricQrScreenState();
}

class _BiometricQrScreenState extends State<BiometricQrScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final LocalAuthentication _auth = LocalAuthentication();
  final MobileScannerController _scannerController = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  final ApiClient _apiClient = ApiClient(baseUrl: Config_URL.baseUrl);

  String _biometricStatus = 'Chưa quét vân tay';
  String _scannedResult = 'Chưa có mã nào được quét';
  bool _isHandlingScan = false;
  DateTime _lastScanTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  final TextEditingController _qrDataController = TextEditingController(
    text: 'CHECKIN:HUTECH_CAMPUS_E_2026',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    _qrDataController.dispose();
    super.dispose();
  }

  // ============================================================================
  // 1. CẢM BIẾN SINH TRẮC HỌC & VÂN TAY (local_auth)
  // ============================================================================
  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isDeviceSupported) {
        setState(() {
          _biometricStatus =
              'Thiết bị không hỗ trợ cảm biến sinh trắc học hoặc chưa thiết lập vân tay/PIN.';
        });
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason:
            'Vui lòng chạm cảm biến vân tay hoặc nhập mã PIN của thiết bị',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      setState(() {
        _biometricStatus = didAuthenticate
            ? '✅ Xác thực vân tay thành công! Đã cấp quyền truy cập hệ thống.'
            : '❌ Xác thực vân tay bị hủy hoặc thất bại.';
      });

      if (didAuthenticate && mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.fingerprint, color: Colors.green),
                SizedBox(width: 8),
                Text('Xác thực Vân tay'),
              ],
            ),
            content: const Text(
              'Cảm biến sinh trắc học đã nhận diện khớp vân tay của bạn thành công.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                  );
                },
                child: const Text('Vào ứng dụng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _biometricStatus =
            'Lỗi cảm biến: $e\n(Trên máy ảo Android, hãy dùng lệnh mô phỏng fingerprint).';
      });
    }
  }

  // ============================================================================
  // 2. NHẬN DIỆN MÃ QR & CHẤM CÔNG THỰC TẾ
  // ============================================================================

  void _onDetectBarcode(BarcodeCapture capture) {
    if (_isHandlingScan) return;
    final now = DateTime.now();
    // Chống quét trùng lặp trong khoảng 2.5 giây
    if (now.difference(_lastScanTimestamp).inMilliseconds < 2500) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _lastScanTimestamp = now;
        _handleDetectedCode(code.trim());
      }
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final barcodeCapture = await _scannerController.analyzeImage(picked.path);
      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        final code = barcodeCapture.barcodes.first.rawValue ?? '';
        if (code.isNotEmpty) {
          _handleDetectedCode(code.trim());
          return;
        }
      }

      setState(() => _scannedResult = 'Không tìm thấy mã QR nào trong ảnh đã chọn.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy mã QR trong ảnh được chọn'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _scannedResult = 'Lỗi quét ảnh: $e');
    }
  }

  void _handleDetectedCode(String code) {
    if (_isHandlingScan) return;
    setState(() {
      _isHandlingScan = true;
      _scannedResult = code;
    });

    // Cảnh báo nếu gặp mã QR mật khẩu dạng rõ (đã bãi bỏ vì lý do an toàn)
    if (code.startsWith('LOGIN:')) {
      _showSecurityWarningDialog();
      return;
    }

    // Trường hợp 1: Nhận diện mã QR SẢN PHẨM (Format: PRODUCT:1 hoặc PRD:1)
    if (code.startsWith('PRODUCT:') || code.startsWith('PRD:')) {
      final idStr = code.split(':').last;
      final id = int.tryParse(idStr);
      if (id != null) {
        _showProductQrDialog(id);
        return;
      }
    }

    // Trường hợp 2: Nhận diện mã QR ĐIỂM DANH / CHẤM CÔNG (Format: CHECKIN:... hoặc CHECKOUT:...)
    if (code.startsWith('CHECKIN:') || code.startsWith('CHECKOUT:') || code.contains('CAMPUS')) {
      _showAttendanceQrDialog(code);
      return;
    }

    // Trường hợp 3: Mã QR chung
    _showGeneralQrDialog(code);
  }

  void _showSecurityWarningDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.red),
            SizedBox(width: 8),
            Text('Cảnh báo bảo mật'),
          ],
        ),
        content: const Text(
          'Mã QR chứa mật khẩu văn bản rõ (LOGIN:...) đã bị vô hiệu hóa hoàn toàn để đảm bảo an toàn thông tin theo tiêu chuẩn OWASP.\n\n'
          'Vui lòng sử dụng tính năng Đăng nhập bằng mã OTP, Sinh trắc học vân tay hoặc tài khoản được cấp.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isHandlingScan = false);
            },
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  // Dialog Chấm công QR gửi dữ liệu lên Backend SQL Server
  void _showAttendanceQrDialog(String qrCode) {
    final bool isCheckoutSuggestion = qrCode.startsWith('CHECKOUT:');
    final String cleanToken = qrCode.replaceFirst('CHECKIN:', '').replaceFirst('CHECKOUT:', '');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.purple),
            SizedBox(width: 8),
            Text('Điểm danh QR'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đã nhận diện mã điểm danh địa điểm làm việc:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 Mã địa điểm: $cleanToken', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Mã đầy đủ: $qrCode', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Vui lòng chọn loại chấm công để gửi xác nhận đến máy chủ:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isHandlingScan = false);
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: isCheckoutSuggestion ? Colors.grey[700] : Colors.green[700]),
            onPressed: () {
              Navigator.pop(ctx);
              _submitAttendance(qrToken: qrCode, isCheckIn: true, locationName: cleanToken);
            },
            icon: const Icon(Icons.login, size: 16, color: Colors.white),
            label: const Text('VÀO CA (Check-in)', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () {
              Navigator.pop(ctx);
              _submitAttendance(qrToken: qrCode, isCheckIn: false, locationName: cleanToken);
            },
            icon: const Icon(Icons.logout, size: 16, color: Colors.white),
            label: const Text('RA CA (Check-out)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAttendance({
    required String qrToken,
    required bool isCheckIn,
    required String locationName,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang xác thực mã QR với máy chủ...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final AttendanceResult result;
      if (isCheckIn) {
        result = await AttendanceService.instance.checkIn(
          method: 'QR',
          qrToken: qrToken,
          locationName: locationName,
          notes: 'Quét mã QR địa điểm: $locationName',
        );
      } else {
        result = await AttendanceService.instance.checkOut(
          method: 'QR',
          qrToken: qrToken,
          locationName: locationName,
          notes: 'Quét mã QR địa điểm: $locationName',
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // Tắt loading

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(result.success ? 'Chấm công thành công' : 'Chấm công thất bại'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Mã địa điểm: $locationName'),
              Text('Hình thức: Quét mã QR'),
              const SizedBox(height: 8),
              Text(
                result.success
                    ? '✅ Đã lưu bản ghi chấm công vào SQL Server (Mã 200 OK).'
                    : '⚠️ Máy chủ từ chối ghi nhận chấm công. Chi tiết lỗi đã được báo cáo.',
                style: TextStyle(
                  color: result.success ? Colors.green[800] : Colors.red[800],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isHandlingScan = false);
              },
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isHandlingScan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi hệ thống: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Dialog Tra cứu Sản phẩm từ QR
  Future<void> _showProductQrDialog(int productId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    productPost? product;
    try {
      http.Response response = await _apiClient.get('ProductApi/$productId');
      if (response.statusCode == 404) {
        response = await _apiClient.get('products/$productId');
      }
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        product = productPost.fromJson(data);
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context); // Tắt loading

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, color: Colors.teal),
            const SizedBox(width: 8),
            Text('Sản phẩm #$productId'),
          ],
        ),
        content: product != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.image != null && product.image!.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.image!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 60),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    product.name ?? 'Không có tên',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Giá: ${product.price?.toStringAsFixed(0) ?? '0'} VND',
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description ?? 'Không có mô tả',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              )
            : Text('Đã nhận diện mã sản phẩm #$productId (Chưa lấy được chi tiết từ máy chủ).'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isHandlingScan = false);
            },
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isHandlingScan = false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
              );
            },
            icon: const Icon(Icons.storefront),
            label: const Text('Xem trong Chợ'),
          ),
        ],
      ),
    );
  }

  // Dialog hiển thị mã QR chung
  void _showGeneralQrDialog(String code) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Colors.purple),
            SizedBox(width: 8),
            Text('Nhận diện mã QR / Barcode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nội dung mã vừa quét:'),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text('Bạn có muốn dùng mã này để chấm công?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isHandlingScan = false);
            },
            child: const Text('Đóng'),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép nội dung mã vào bộ nhớ tạm')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Sao chép'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAttendanceQrDialog(code);
            },
            child: const Text('Chấm công bằng mã này'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GIAO DIỆN CHÍNH (3 TABS)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhận diện QR & Sinh trắc học'),
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Quét mã QR'),
            Tab(icon: Icon(Icons.qr_code), text: 'Tạo mã QR'),
            Tab(icon: Icon(Icons.fingerprint), text: 'Vân tay'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // -------------------------------------------------------------
          // TAB 1: QUÉT MÃ QR & BARCODE
          // -------------------------------------------------------------
          Column(
            children: [
              Expanded(
                flex: 4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetectBarcode,
                    ),
                    // Khung ngắm quét
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.greenAccent, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    // Nút bật đèn flash & đổi camera
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.flash_on, color: Colors.white),
                              tooltip: 'Bật/Tắt Flash',
                              onPressed: () => _scannerController.toggleTorch(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                              tooltip: 'Đổi Camera',
                              onPressed: () => _scannerController.switchCamera(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hướng dẫn
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Hướng camera vào mã QR địa điểm để chấm công',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kết quả gần nhất: $_scannedResult',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _scanFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Chọn ảnh mã QR từ bộ nhớ / thư viện'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mã QR điểm danh mẫu (Hữu ích khi chấm trên máy ảo):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.location_city, size: 16, color: Colors.purple),
                            label: const Text('Vào ca Khu E'),
                            onPressed: () => _handleDetectedCode('CHECKIN:HUTECH_CAMPUS_E'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.logout, size: 16, color: Colors.orange),
                            label: const Text('Ra ca Khu E'),
                            onPressed: () => _handleDetectedCode('CHECKOUT:HUTECH_CAMPUS_E'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.business, size: 16, color: Colors.teal),
                            label: const Text('Vào ca Trụ sở chính'),
                            onPressed: () => _handleDetectedCode('CHECKIN:HUTECH_MAIN_CAMPUS'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.inventory_2, size: 16, color: Colors.indigo),
                            label: const Text('QR Sản phẩm #1'),
                            onPressed: () => _handleDetectedCode('PRODUCT:1'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // -------------------------------------------------------------
          // TAB 2: TẠO MÃ QR (qr_flutter)
          // -------------------------------------------------------------
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Tạo mã QR Điểm danh & Địa điểm HUTECH',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrDataController.text.isNotEmpty
                          ? _qrDataController.text
                          : 'HUTECH',
                      version: QrVersions.auto,
                      size: 210.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _qrDataController,
                  decoration: const InputDecoration(
                    labelText: 'Dữ liệu mã QR',
                    border: OutlineInputBorder(),
                    hintText: 'Nhập chuỗi mã địa điểm hoặc token chấm công',
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn mẫu mã địa điểm chuẩn:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Vào ca Campus Khu E'),
                      selected: _qrDataController.text == 'CHECKIN:HUTECH_CAMPUS_E_2026',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'CHECKIN:HUTECH_CAMPUS_E_2026';
                      }),
                    ),
                    FilterChip(
                      label: const Text('Ra ca Campus Khu E'),
                      selected: _qrDataController.text == 'CHECKOUT:HUTECH_CAMPUS_E_2026',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'CHECKOUT:HUTECH_CAMPUS_E_2026';
                      }),
                    ),
                    FilterChip(
                      label: const Text('Trụ sở Điện Biên Phủ'),
                      selected: _qrDataController.text == 'CHECKIN:HUTECH_CAMPUS_A_DBP',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'CHECKIN:HUTECH_CAMPUS_A_DBP';
                      }),
                    ),
                    FilterChip(
                      label: const Text('Sản phẩm #1'),
                      selected: _qrDataController.text == 'PRODUCT:1',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'PRODUCT:1';
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------
          // TAB 3: XÁC THỰC SINH TRẮC HỌC VÂN TAY (local_auth)
          // -------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint_rounded, size: 100, color: Colors.deepPurple[700]),
                const SizedBox(height: 24),
                const Text(
                  'Xác thực Sinh Trắc Học',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _biometricStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[800], fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.touch_app_rounded),
                    label: const Text('Quét vân tay ngay', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
