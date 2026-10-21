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
import '../utils/auth.dart';
import 'admin_screen.dart';
import 'main_screen.dart';
import 'staff_screen.dart';

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
  final TextEditingController _qrDataController = TextEditingController(
    text: 'LOGIN:admin:Admin@123456',
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
  // 1. CẢM BIẾN SINH TRẮC HỌC & VÂN TAY (local_auth 3.0.2)
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
                Text('Đăng nhập Vân tay'),
              ],
            ),
            content: const Text(
              'Cảm biến sinh trắc học đã nhận diện khớp vân tay của bạn.',
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
            'Lỗi cảm biến: $e\n(Trên máy ảo Android, hãy bấm nút "Touch the sensor" trong Extended controls).';
      });
    }
  }

  // ============================================================================
  // 2. NHẬN DIỆN MÃ QR THÔNG MINH (Smart QR Recognition)
  // ============================================================================

  void _onDetectBarcode(BarcodeCapture capture) {
    if (_isHandlingScan) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null && code.trim().isNotEmpty) {
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

    // Trường hợp 1: Nhận diện mã QR ĐĂNG NHẬP (Format: LOGIN:username:password)
    if (code.startsWith('LOGIN:')) {
      final parts = code.split(':');
      if (parts.length >= 3) {
        final username = parts[1];
        final password = parts.sublist(2).join(':');
        _showLoginQrDialog(username, password);
        return;
      }
    }

    // Trường hợp 2: Nhận diện mã QR SẢN PHẨM (Format: PRODUCT:1 hoặc PRD:1)
    if (code.startsWith('PRODUCT:') || code.startsWith('PRD:')) {
      final idStr = code.split(':').last;
      final id = int.tryParse(idStr);
      if (id != null) {
        _showProductQrDialog(id);
        return;
      }
    }

    // Trường hợp 3: Nhận diện mã QR ĐIỂM DANH / CHẤM CÔNG (Format: CHECKIN:...)
    if (code.startsWith('CHECKIN:')) {
      final loc = code.replaceFirst('CHECKIN:', '');
      _showCheckinQrDialog(loc);
      return;
    }

    // Trường hợp 4: Mã QR chung / Barcode sản phẩm
    _showGeneralQrDialog(code);
  }

  // Dialog Đăng nhập từ QR
  void _showLoginQrDialog(String username, String password) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Nhận diện QR Đăng nhập'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đã nhận diện thông tin tài khoản từ mã QR:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tài khoản: $username', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Mật khẩu: ${'*' * password.length}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Bạn có muốn đăng nhập ngay vào hệ thống?'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeLogin(username, password);
            },
            icon: const Icon(Icons.login),
            label: const Text('Đăng nhập ngay'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeLogin(String username, String password) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await Auth.login(username, password);
      if (!mounted) return;
      Navigator.pop(context); // Tắt dialog loading

      if (result['success'] == true) {
        final String role = (result['role'] ?? 'User').toString().toLowerCase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập thành công với vai trò: $role'),
            backgroundColor: Colors.green,
          ),
        );

        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminScreen()),
          );
        } else if (role == 'staff' || role == 'nhanvien') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StaffScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else {
        setState(() => _isHandlingScan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Đăng nhập thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isHandlingScan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
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

  // Dialog Điểm danh từ QR
  void _showCheckinQrDialog(String location) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ngày ${now.day}/${now.month}/${now.year}';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: 8),
            Text('Điểm danh QR thành công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hệ thống đã ghi nhận lượt điểm danh của bạn:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 Địa điểm: $location', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('⏰ Thời gian: $timeStr', style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 6),
                  const Text('✅ Trạng thái: Hợp lệ (Đúng vị trí)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
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
            child: const Text('Hoàn tất'),
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
          ],
        ),
        actions: [
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
              setState(() => _isHandlingScan = false);
            },
            child: const Text('Đóng'),
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
        title: const Text('Nhận diện QR, Vân tay & NFC'),
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
                    // Khung ngắm quét (Reticle Scanner Frame)
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
                          'Hướng camera vào mã QR để nhận diện tự động',
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
                        'Thử nhanh các mã QR mẫu (Hữu ích khi chấm trên máy ảo):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.admin_panel_settings, size: 16, color: Colors.red),
                            label: const Text('QR Login Admin'),
                            onPressed: () => _handleDetectedCode('LOGIN:admin:Admin@123456'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.badge, size: 16, color: Colors.teal),
                            label: const Text('QR Login Staff'),
                            onPressed: () => _handleDetectedCode('LOGIN:staff:Staff@123456'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.person, size: 16, color: Colors.blue),
                            label: const Text('QR Login User'),
                            onPressed: () => _handleDetectedCode('LOGIN:user:User@123456'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.inventory_2, size: 16, color: Colors.purple),
                            label: const Text('QR Sản phẩm #1'),
                            onPressed: () => _handleDetectedCode('PRODUCT:1'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.location_on, size: 16, color: Colors.green),
                            label: const Text('QR Điểm danh'),
                            onPressed: () => _handleDetectedCode('CHECKIN:HUTECH_CAMPUS_E1_TPHCM'),
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
                    'Tạo mã QR cho Hệ thống HUTECH',
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
                    hintText: 'Nhập chuỗi văn bản bất kỳ để tạo mã QR',
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn mẫu nhanh để tạo QR:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Admin QR'),
                      selected: _qrDataController.text == 'LOGIN:admin:Admin@123456',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'LOGIN:admin:Admin@123456';
                      }),
                    ),
                    FilterChip(
                      label: const Text('Staff QR'),
                      selected: _qrDataController.text == 'LOGIN:staff:Staff@123456',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'LOGIN:staff:Staff@123456';
                      }),
                    ),
                    FilterChip(
                      label: const Text('Sản phẩm #1'),
                      selected: _qrDataController.text == 'PRODUCT:1',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'PRODUCT:1';
                      }),
                    ),
                    FilterChip(
                      label: const Text('Điểm danh HUTECH'),
                      selected: _qrDataController.text == 'CHECKIN:HUTECH_CAMPUS_E_2026',
                      onSelected: (_) => setState(() {
                        _qrDataController.text = 'CHECKIN:HUTECH_CAMPUS_E_2026';
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
