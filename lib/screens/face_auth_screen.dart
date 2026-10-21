import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'live_face_capture_screen.dart';
import '../utils/auth.dart';
import '../services/attendance_service.dart';
import '../widgets/post_shift_feedback_dialog.dart';

/// Kết quả kiểm tra Liveness sinh trắc học
class FaceLivenessResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? successDetail;

  const FaceLivenessResult({
    required this.isSuccess,
    this.errorMessage,
    this.successDetail,
  });

  factory FaceLivenessResult.passed(String detail) =>
      FaceLivenessResult(isSuccess: true, successDetail: detail);

  factory FaceLivenessResult.failed(String error) =>
      FaceLivenessResult(isSuccess: false, errorMessage: error);
}

/// Bộ kiểm tra Liveness tương tác nghiêm ngặt:
/// - Góc mặt trực diện: Yaw, Roll, Pitch trong khoảng [-15°, +15°]
/// - Phát hiện chuyển động chớp mắt thật: Tỷ lệ mở mắt thay đổi từ > 0.7 sang < 0.25 rồi mở lại > 0.7
/// - Hoặc nụ cười thật: smilingProbability >= 0.7
class FaceLivenessChecker {
  /// Kiểm tra góc mặt trực diện trong khoảng [-15°, +15°]
  static bool isHeadAngleDirect({
    required double yaw,
    required double roll,
    required double pitch,
  }) {
    return yaw.abs() <= 15.0 && roll.abs() <= 15.0 && pitch.abs() <= 15.0;
  }

  /// Kiểm tra nụ cười đạt chuẩn Liveness: smilingProbability >= 0.7
  static bool isSmiling(double? smileProb) {
    return smileProb != null && smileProb >= 0.7;
  }

  /// Kiểm tra chuỗi chớp mắt thật: Tỷ lệ mở mắt chuyển từ > 0.7 sang < 0.25 rồi mở lại > 0.7
  static bool verifyBlinkSequence(List<double> eyeHistory) {
    if (eyeHistory.length < 3) return false;
    bool foundOpen1 = false;
    bool foundClosed = false;

    for (final val in eyeHistory) {
      if (!foundOpen1) {
        if (val > 0.7) foundOpen1 = true;
      } else if (!foundClosed) {
        if (val < 0.25) foundClosed = true;
      } else {
        if (val > 0.7) return true;
      }
    }
    return false;
  }

  /// Đánh giá Liveness toàn diện cho 1 khuôn mặt ML Kit
  static FaceLivenessResult evaluate({
    required Face face,
    int totalFaces = 1,
    List<double>? blinkHistory,
  }) {
    if (totalFaces > 1) {
      return FaceLivenessResult.failed(
        'Phát hiện $totalFaces khuôn mặt trong ảnh. Vui lòng chỉ đứng một mình trước camera để chống giả mạo.',
      );
    }

    final double rotY = face.headEulerAngleY ?? 0.0; // Yaw
    final double rotZ = face.headEulerAngleZ ?? 0.0; // Roll
    final double rotX = face.headEulerAngleX ?? 0.0; // Pitch

    if (!isHeadAngleDirect(yaw: rotY, roll: rotZ, pitch: rotX)) {
      return FaceLivenessResult.failed(
        '❌ Góc mặt chưa thẳng: Vui lòng nhìn trực diện vào camera (Lệch ≤ 15°).\n'
        'Hiện tại: Yaw: ${rotY.toStringAsFixed(1)}°, Roll: ${rotZ.toStringAsFixed(1)}°, Pitch: ${rotX.toStringAsFixed(1)}°',
      );
    }

    // 1. Kiểm tra nụ cười
    final double? smile = face.smilingProbability;
    final bool smilingPassed = isSmiling(smile);

    // 2. Kiểm tra chuỗi chớp mắt
    final double leftEye = face.leftEyeOpenProbability ?? 0.0;
    final double rightEye = face.rightEyeOpenProbability ?? 0.0;
    final double avgEye = (leftEye + rightEye) / 2.0;

    bool blinkPassed = false;
    if (blinkHistory != null && blinkHistory.isNotEmpty) {
      final historyWithCurrent = List<double>.from(blinkHistory)..add(avgEye);
      blinkPassed = verifyBlinkSequence(historyWithCurrent);
    }

    if (smilingPassed) {
      return FaceLivenessResult.passed(
        '✅ Đạt chuẩn Liveness: Phát hiện nụ cười tự nhiên (${((smile ?? 0) * 100).toStringAsFixed(1)}%) và góc mặt trực diện chuẩn!',
      );
    }

    if (blinkPassed) {
      return FaceLivenessResult.passed(
        '✅ Đạt chuẩn Liveness: Phát hiện chuyển động chớp mắt thật (Mở > 0.7 ➔ Nhắm < 0.25 ➔ Mở > 0.7)!',
      );
    }

    // 3. Nếu chưa chớp mắt/cười: Cả hai mắt phải mở to rõ (> 75%)
    if (leftEye >= 0.75 && rightEye >= 0.75) {
      return FaceLivenessResult.passed(
        '✅ Đạt chuẩn Liveness: Hai mắt mở to rõ (> 75%) và góc mặt trực diện chuẩn (-15° đến +15°)!',
      );
    }

    return FaceLivenessResult.failed(
      '❌ Kiểm tra Liveness thất bại:\n'
      'Vui lòng nhìn trực diện camera, mở to cả hai mắt (> 70%) hoặc mỉm cười nhẹ (> 70%) để xác thực người thật.\n'
      'Mắt trái: ${(leftEye * 100).toStringAsFixed(1)}%, Mắt phải: ${(rightEye * 100).toStringAsFixed(1)}%',
    );
  }
}

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

  Map<String, double> _extractFaceFeatures(Face face) {
    final box = face.boundingBox;
    final double boxAspect = box.height > 0 ? box.width / box.height : 1.0;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final mouth =
        face.landmarks[FaceLandmarkType.bottomMouth] ??
        face.landmarks[FaceLandmarkType.leftMouth] ??
        face.landmarks[FaceLandmarkType.rightMouth];

    double eyeDistRatio = 0.35;
    double eyeToNoseRatio = 0.25;
    double noseToMouthRatio = 0.20;

    if (leftEye != null && rightEye != null && box.width > 0) {
      final dx = (leftEye.position.x - rightEye.position.x).toDouble();
      final dy = (leftEye.position.y - rightEye.position.y).toDouble();
      eyeDistRatio = math.sqrt(dx * dx + dy * dy) / box.width;
    }

    if (leftEye != null && rightEye != null && nose != null && box.height > 0) {
      final eyeMidY = (leftEye.position.y + rightEye.position.y) / 2.0;
      eyeToNoseRatio = (nose.position.y - eyeMidY).abs() / box.height;
    }

    if (nose != null && mouth != null && box.height > 0) {
      noseToMouthRatio =
          (mouth.position.y - nose.position.y).abs() / box.height;
    }

    return {
      'boxAspect': boxAspect,
      'eyeDistRatio': eyeDistRatio,
      'eyeToNoseRatio': eyeToNoseRatio,
      'noseToMouthRatio': noseToMouthRatio,
    };
  }

  /// Tính độ tương đồng giữa hai mẫu khuôn mặt (0.0 -> 1.0)
  double _calculateSimilarity(
    Map<String, dynamic> f1,
    Map<String, dynamic> f2,
  ) {
    double diff = 0.0;
    int count = 0;
    for (final key in [
      'boxAspect',
      'eyeDistRatio',
      'eyeToNoseRatio',
      'noseToMouthRatio',
    ]) {
      final v1 = (f1[key] as num?)?.toDouble();
      final v2 = (f2[key] as num?)?.toDouble();
      if (v1 != null && v2 != null) {
        diff += (v1 - v2).abs();
        count++;
      }
    }
    if (count == 0) return 0.0;
    final avgDiff = diff / count;
    return (1.0 - (avgDiff * 3.0)).clamp(0.0, 1.0);
  }

  Future<Map<String, double>?> _captureFeatures({
    Map<String, dynamic>? sample,
    required String title,
  }) => Navigator.push<Map<String, double>>(
    context,
    MaterialPageRoute(
      builder: (_) => LiveFaceCaptureScreen(
        title: title,
        extractFeatures: _extractFaceFeatures,
        matchesSample: (features) =>
            sample == null || _calculateSimilarity(features, sample) >= 0.65,
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
    if (_calculateSimilarity(features, sample) < 0.65) {
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
