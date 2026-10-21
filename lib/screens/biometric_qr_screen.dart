import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/attendance_service.dart';
import '../widgets/post_shift_feedback_dialog.dart';

enum _QrAction { checkIn, checkOut }

class BiometricQrScreen extends StatefulWidget {
  const BiometricQrScreen({
    super.key,
    this.attendanceService,
    this.scannerController,
    this.scannerBuilder,
  });

  final AttendanceService? attendanceService;
  final MobileScannerController? scannerController;
  final Widget Function(
    BuildContext context,
    MobileScannerController controller,
    void Function(BarcodeCapture) onDetect,
  )?
  scannerBuilder;

  @override
  State<BiometricQrScreen> createState() => _BiometricQrScreenState();
}

class _BiometricQrScreenState extends State<BiometricQrScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  late final MobileScannerController _scannerController;
  AttendanceService get _attendanceService =>
      widget.attendanceService ?? AttendanceService.instance;
  final ImagePicker _picker = ImagePicker();

  String _scannedResult = 'Chưa có mã nào được quét';
  bool _isHandlingScan = false;
  _QrAction? _selectedAction;
  bool _scanArmed = false;
  bool _foreground = true;
  Future<void> _cameraOperation = Future<void>.value();

  bool get _canScan =>
      mounted &&
      _foreground &&
      _tabController.index == 0 &&
      _scanArmed &&
      !_isHandlingScan;

  final TextEditingController _qrDataController = TextEditingController(
    text: 'HUTECH_ATTENDANCE_QR_CAMPUS_E_MAIN',
  );
  bool _isLoadingActiveQr = false;

  @override
  void initState() {
    super.initState();
    _scannerController =
        widget.scannerController ??
        MobileScannerController(
          autoStart: false,
          formats: [BarcodeFormat.qrCode],
        );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    // Complete any in-flight camera operation before releasing the controller.
    unawaited(
      _cameraOperation
          .then((_) async {
            try {
              await _scannerController.stop();
            } finally {
              if (widget.scannerController == null) {
                await _scannerController.dispose();
              }
            }
          })
          .catchError((Object _) {}),
    );
    _qrDataController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index != 0 && _scanArmed) {
      setState(() => _scanArmed = false);
      _syncCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _scanArmed) setState(() => _scanArmed = false);
    _syncCamera();
  }

  void _syncCamera() {
    _cameraOperation = _cameraOperation
        .then((_) async {
          if (_canScan) {
            await _scannerController.start();
          } else {
            await _scannerController.stop();
          }
        })
        .catchError((Object _) {
          if (!_canScan) return;
          setState(() => _scanArmed = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không mở được camera. Vui lòng kiểm tra quyền camera hoặc chọn ảnh QR.',
              ),
            ),
          );
        });
  }

  void _selectAction(_QrAction action) {
    if (_isHandlingScan) return;
    setState(() {
      _selectedAction = action;
      _scanArmed = true;
    });
    _syncCamera();
  }

  void _onDetectBarcode(BarcodeCapture capture) {
    if (!_canScan) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        unawaited(_handleDetectedCode(code));
        return;
      }
    }
  }

  Future<void> _scanFromGallery() async {
    final action = _selectedAction;
    if (action == null || _isHandlingScan) return;
    setState(() {
      _isHandlingScan = true;
      _scanArmed = false;
    });
    _syncCamera();
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final capture = await _scannerController.analyzeImage(picked.path);
      if (!mounted) return;
      for (final barcode in capture?.barcodes ?? <Barcode>[]) {
        final code = barcode.rawValue?.trim();
        if (code != null && code.isNotEmpty) {
          await _submitQrAttendance(code, action);
          return;
        }
      }
      setState(
        () => _scannedResult = 'Không tìm thấy mã QR trong ảnh đã chọn.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy mã QR trong ảnh được chọn'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không đọc được ảnh. Vui lòng chọn lại ảnh mã QR.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isHandlingScan = false);
    }
  }

  Future<void> _handleDetectedCode(String code) async {
    if (!_canScan || _selectedAction == null) return;
    final action = _selectedAction!;
    setState(() {
      _isHandlingScan = true;
      _scanArmed = false;
    });
    _syncCamera();
    try {
      await _submitQrAttendance(code, action);
    } finally {
      if (mounted) setState(() => _isHandlingScan = false);
    }
  }

  Future<void> _submitQrAttendance(String code, _QrAction action) async {
    setState(() => _scannedResult = code);
    final checkIn = action == _QrAction.checkIn;
    final label = checkIn ? 'Check-in' : 'Check-out';
    final navigator = Navigator.of(context, rootNavigator: true);
    final loading = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xác thực mã QR...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    unawaited(navigator.push(loading));
    AttendanceResult result;
    try {
      result = checkIn
          ? await _attendanceService.checkIn(
              method: 'QR',
              qrToken: code,
              locationName: 'Điểm danh mã QR',
              notes: 'Chấm công quét QR',
            )
          : await _attendanceService.checkOut(
              method: 'QR',
              qrToken: code,
              locationName: 'Điểm danh mã QR',
              notes: 'Chấm công quét QR',
            );
    } catch (_) {
      result = AttendanceResult(success: false, message: '');
    } finally {
      if (loading.isActive) navigator.removeRoute(loading);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('$label ${result.success ? 'thành công' : 'thất bại'}'),
          content: Text(
            result.success
                ? 'Đã ghi nhận ${checkIn ? 'vào ca' : 'ra ca'} bằng mã QR.'
                : result.isConflict
                ? 'Ca làm đã được ghi nhận hoặc trạng thái ca không phù hợp. Vui lòng kiểm tra lịch sử chấm công.'
                : 'Không thể chấm công. Vui lòng kiểm tra mã QR và kết nối rồi thử lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
    final recordId = int.tryParse(result.data?.id?.toString() ?? '');
    if (mounted && !checkIn && result.success && recordId != null) {
      await showPostShiftFeedbackDialog(context: context, recordId: recordId);
    }
  }

  Future<void> _fetchActiveQrCode() async {
    setState(() => _isLoadingActiveQr = true);
    try {
      final code = await _attendanceService.getActiveQrCode();
      if (!mounted) return;
      setState(() {
        _qrDataController.text = code;
        _isLoadingActiveQr = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sinh mã QR chuẩn'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingActiveQr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không lấy được mã QR. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================================
  // GIAO DIỆN CHÍNH (2 TABS)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR chấm công'),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    SegmentedButton<_QrAction>(
                      emptySelectionAllowed: true,
                      segments: const [
                        ButtonSegment(
                          value: _QrAction.checkIn,
                          icon: Icon(Icons.login),
                          label: Text('Check-in'),
                        ),
                        ButtonSegment(
                          value: _QrAction.checkOut,
                          icon: Icon(Icons.logout),
                          label: Text('Check-out'),
                        ),
                      ],
                      selected: {?_selectedAction},
                      onSelectionChanged: _isHandlingScan
                          ? null
                          : (selection) {
                              // Tapping the selected segment explicitly arms another scan.
                              _selectAction(
                                selection.isEmpty
                                    ? _selectedAction!
                                    : selection.first,
                              );
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isHandlingScan
                          ? 'Đang xử lý chấm công...'
                          : _scanArmed
                          ? 'Đang quét ${_selectedAction == _QrAction.checkIn ? 'Check-in' : 'Check-out'}'
                          : 'Chọn Check-in hoặc Check-out để bắt đầu quét.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    widget.scannerBuilder?.call(
                          context,
                          _scannerController,
                          _onDetectBarcode,
                        ) ??
                        MobileScanner(
                          controller: _scannerController,
                          useAppLifecycleState: false,
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
                              icon: const Icon(
                                Icons.flash_on,
                                color: Colors.white,
                              ),
                              tooltip: 'Bật/Tắt Flash',
                              onPressed: _canScan
                                  ? () => _scannerController.toggleTorch()
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(
                                Icons.flip_camera_ios,
                                color: Colors.white,
                              ),
                              tooltip: 'Đổi Camera',
                              onPressed: _canScan
                                  ? () => _scannerController.switchCamera()
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hướng dẫn
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _selectedAction == null || _isHandlingScan
                              ? null
                              : _scanFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text(
                            'Chọn ảnh mã QR từ bộ nhớ / thư viện',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.deepPurple[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.deepPurple[800],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chọn thao tác vào ca hoặc ra ca, sau đó quét mã QR do quản trị viên cung cấp. '
                                'Sau mỗi lần chấm công, hãy chọn lại thao tác để quét tiếp.',
                                style: TextStyle(
                                  color: Colors.deepPurple[900],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // -------------------------------------------------------------
          // TAB 2: TẠO MÃ QR (qr_flutter) DÀNH CHO ADMIN
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingActiveQr ? null : _fetchActiveQrCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isLoadingActiveQr
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: const Text('Sinh mã QR chuẩn'),
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
