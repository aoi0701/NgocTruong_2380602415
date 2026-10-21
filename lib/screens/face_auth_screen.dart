import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'live_face_capture_screen.dart';
import '../services/face_feature_helper.dart';
import '../utils/auth.dart';
import '../services/attendance_service.dart';
import '../widgets/post_shift_feedback_dialog.dart';

// Tái xuất các lớp Liveness và Helper để duy trì tương thích ngược
export '../services/face_feature_helper.dart';

/// Chấm công cho tài khoản đã đăng nhập; không tạo phiên đăng nhập mới.
class FaceAuthScreen extends StatefulWidget {
  const FaceAuthScreen({super.key, this.initialEnrollmentMode = false});
  final bool initialEnrollmentMode;
  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _ready = false;
  bool _signedIn = false;
  bool _busy = false;
  String? _username;
  String? _status;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialEnrollmentMode ? 1 : 0,
    );
    _loadSession();
  }

  Future<void> _loadSession() async {
    final valid = await Auth.isLoggedIn();
    final name = valid ? await Auth.getUsername() : null;
    if (!mounted) return;
    setState(() {
      _signedIn = valid && name != null && name.isNotEmpty;
      _username = name;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Map<String, double> _extractFaceFeatures(Face face) =>
      FaceFeatureHelper.extractFaceFeatures(face);

  /// Tính độ tương đồng giữa hai mẫu khuôn mặt (0.0 -> 1.0)
  double _calculateSimilarity(
    Map<String, dynamic> f1,
    Map<String, dynamic> f2,
  ) =>
      FaceFeatureHelper.calculateSimilarity(f1, f2);

  Future<Map<String, double>?> _captureFeatures({
    Map<String, dynamic>? sample,
    required String title,
  }) => Navigator.push<Map<String, double>>(
    context,
    MaterialPageRoute(
      builder: (_) => LiveFaceCaptureScreen(
        title: title,
        sample: sample,
        extractFeatures: _extractFaceFeatures,
        matchesSample: (features) =>
            sample == null ||
            _calculateSimilarity(features, sample) >=
                FaceFeatureHelper.similarityThreshold,
      ),
    ),
  );

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      if (!await Auth.isLoggedIn()) {
        if (mounted) setState(() => _signedIn = false);
        return;
      }
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = error is StateError
              ? error.message.toString()
              : 'Không thể thực hiện: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enroll() => _run(() async {
    final features = await _captureFeatures(title: 'Đăng ký mẫu khuôn mặt');
    if (features == null || !mounted) return;
    final result = await Auth.enrollFace(
      username: _username!,
      features: features,
    );
    if (result['success'] != true) {
      throw StateError(
        result['message']?.toString() ?? 'Không lưu được mẫu khuôn mặt.',
      );
    }
    if (mounted) {
      setState(() => _status = 'Đã lưu mẫu khuôn mặt cho $_username.');
    }
  });

  Future<void> _submitAttendance({required bool checkIn}) => _run(() async {
    final profile = await Auth.getFaceProfile(_username!);
    if (!mounted) return;
    if (profile['success'] != true || profile['data'] is! Map) {
      throw StateError(
        profile['message']?.toString() ??
            'Bạn chưa có mẫu khuôn mặt. Hãy đăng ký mẫu trước.',
      );
    }
    final data = profile['data'] as Map;
    final raw = data['faceVectorJson'];
    final dynamic decoded = raw is String ? jsonDecode(raw) : data['features'];
    if (decoded is! Map) {
      throw StateError('Mẫu khuôn mặt không hợp lệ. Vui lòng đăng ký lại.');
    }
    final sample = Map<String, dynamic>.from(decoded);
    final features = await _captureFeatures(
      sample: sample,
      title: checkIn ? 'Khuôn mặt · Check-in' : 'Khuôn mặt · Check-out',
    );
    if (features == null || !mounted) return;
    if (_calculateSimilarity(features, sample) <
        FaceFeatureHelper.similarityThreshold) {
      throw StateError(
        'Khuôn mặt chưa khớp mẫu của $_username. Vui lòng thử lại.',
      );
    }
    final proof = jsonEncode({
      'username': _username,
      'features': features,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    });
    final service = AttendanceService.instance;
    final result = checkIn
        ? await service.checkIn(
            method: 'Face',
            faceProof: proof,
            notes: 'Vào ca bằng khuôn mặt',
          )
        : await service.checkOut(
            method: 'Face',
            faceProof: proof,
            notes: 'Ra ca bằng khuôn mặt',
          );
    if (!mounted) return;
    if (!result.success) throw StateError(result.message);
    setState(() => _status = result.message);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(checkIn ? 'Vào ca thành công' : 'Ra ca thành công'),
        content: Text('Tài khoản: $_username\n${result.message}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    if (!checkIn && mounted && result.data?.id != null) {
      await showPostShiftFeedbackDialog(
        context: context,
        recordId: result.data!.id!,
      );
    }
  });

  Widget _content({required bool enrollment}) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(
              enrollment
                  ? Icons.person_add_alt_1_rounded
                  : Icons.face_retouching_natural,
              size: 66,
              color: const Color(0xFF087F8C),
            ),
            const SizedBox(height: 16),
            Text(
              enrollment ? 'Đăng ký mẫu khuôn mặt' : 'Xác nhận ca làm của bạn',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              enrollment
                  ? 'Mở camera trước, nhìn thẳng và mỉm cười hoặc chớp mắt. Mẫu được lưu cho tài khoản của bạn.'
                  : 'Chọn Check-in hoặc Check-out, đưa khuôn mặt vào khung camera. Hệ thống tự nhận diện khi khớp mẫu.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5, color: Colors.black54),
            ),
            if (_status != null) ...[
              const SizedBox(height: 18),
              Text(_status!, textAlign: TextAlign.center),
            ],
            if (_busy) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 24),
            if (enrollment)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _enroll,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Mở camera đăng ký mẫu'),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _submitAttendance(checkIn: true),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Check-in · Vào ca'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _submitAttendance(checkIn: false),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Check-out · Ra ca'),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        title: const Text('Chấm công khuôn mặt'),
        backgroundColor: Colors.white,
        bottom: _ready && _signedIn
            ? TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Chấm công'),
                  Tab(text: 'Đăng ký mẫu'),
                ],
              )
            : null,
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : !_signedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Vui lòng đăng nhập trước khi chấm công.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Tài khoản: $_username',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _content(enrollment: false),
                      _content(enrollment: true),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
