import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth.dart';
import 'admin_screen.dart';
import 'staff_screen.dart';
import 'main_screen.dart';
import 'login_screen.dart';

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

class FaceAuthScreen extends StatefulWidget {
  final bool initialEnrollmentMode;
  final String? defaultUsername;

  const FaceAuthScreen({
    super.key,
    this.initialEnrollmentMode = false,
    this.defaultUsername,
  });

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late final FaceDetector _faceDetector;
  late final TabController _tabController;

  // Trạng thái chung
  File? _capturedImage;
  bool _isProcessing = false;
  String _statusMessage = 'Vui lòng hướng camera trực diện vào khuôn mặt và bấm chụp để quét.';
  bool _isLivenessPassed = false;

  // Trạng thái phiên đăng nhập của người dùng
  bool _isLoggedIn = false;
  String? _loggedInUsername;
  String? _loggedInRole;

  // Trạng thái tab Đăng nhập bằng khuôn mặt (Tab 0)
  final TextEditingController _authUsernameController = TextEditingController();
  final TextEditingController _authPasswordController = TextEditingController();
  final TextEditingController _authOtpController = TextEditingController();
  Map<String, dynamic>? _matchedAccount;
  bool _isSubmittingLogin = false;
  bool _obscureAuthPassword = true;

  // Trạng thái tab Đăng ký mẫu (Tab 1)
  final TextEditingController _enrollUsernameController = TextEditingController();
  final TextEditingController _enrollRoleController = TextEditingController(text: 'Staff');
  Map<String, dynamic>? _lastEnrolledProfile;

  static const String _enrolledProfilesKey = 'enrolled_face_profiles_v2';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialEnrollmentMode ? 1 : 0,
    );

    final options = FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);

    _initAuthStatus();
  }

  Future<void> _initAuthStatus() async {
    final loggedIn = await Auth.isLoggedIn();
    final username = await Auth.getUsername();
    final role = await Auth.getRole();

    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _loggedInUsername = username;
      _loggedInRole = role;

      if (widget.defaultUsername != null && widget.defaultUsername!.isNotEmpty) {
        _authUsernameController.text = widget.defaultUsername!;
      } else if (username != null && username.isNotEmpty) {
        _authUsernameController.text = username;
      }

      if (loggedIn && username != null && username.isNotEmpty) {
        _enrollUsernameController.text = username;
        if (role != null && role.isNotEmpty) {
          _enrollRoleController.text = role;
        }
      }
    });
  }

  @override
  void dispose() {
    _faceDetector.close();
    _tabController.dispose();
    _authUsernameController.dispose();
    _authPasswordController.dispose();
    _authOtpController.dispose();
    _enrollUsernameController.dispose();
    _enrollRoleController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. TÍNH TOÁN ĐẶC TRƯNG & SO KHỚP MA TRẬN
  // ==========================================

  /// Trích xuất vector đặc trưng hình học bất biến theo tỷ lệ
  Map<String, double> _extractFaceFeatures(Face face) {
    final box = face.boundingBox;
    final double boxAspect = box.height > 0 ? box.width / box.height : 1.0;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final mouth = face.landmarks[FaceLandmarkType.bottomMouth] ??
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
      noseToMouthRatio = (mouth.position.y - nose.position.y).abs() / box.height;
    }

    return {
      'boxAspect': boxAspect,
      'eyeDistRatio': eyeDistRatio,
      'eyeToNoseRatio': eyeToNoseRatio,
      'noseToMouthRatio': noseToMouthRatio,
    };
  }

  /// Tính độ tương đồng giữa hai mẫu khuôn mặt (0.0 -> 1.0)
  double _calculateSimilarity(Map<String, dynamic> f1, Map<String, dynamic> f2) {
    double diff = 0.0;
    int count = 0;
    for (final key in ['boxAspect', 'eyeDistRatio', 'eyeToNoseRatio', 'noseToMouthRatio']) {
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

  // ==========================================
  // 2. CHỤP ẢNH TỪ CAMERA TRỰC TIẾP
  // ==========================================

  /// Bắt buộc chỉ sử dụng ImageSource.camera trực tiếp để chống gian lận
  Future<File?> _captureFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );
      if (pickedFile == null) return null;
      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Camera capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở Camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ==========================================
  // 3. QUY TRÌNH ĐĂNG KÝ KHUÔN MẶT MẪU (ENROLLMENT)
  // Chỉ khả dụng khi ĐÃ ĐĂNG NHẬP, đồng bộ POST /api/Attendance/enroll-face
  // ==========================================

  Future<void> _handleEnrollment() async {
    // 1. Kiểm tra bắt buộc đã đăng nhập
    if (!_isLoggedIn || _loggedInUsername == null || _loggedInUsername!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ người dùng đã đăng nhập mới được phép đăng ký mẫu khuôn mặt.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final username = _loggedInUsername!;
    final role = _loggedInRole ?? 'User';

    final file = await _captureFromCamera();
    if (file == null) return;

    setState(() {
      _capturedImage = file;
      _isProcessing = true;
      _statusMessage = 'Đang phân tích khuôn mặt và kiểm tra Liveness tương tác...';
      _isLivenessPassed = false;
    });

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      setState(() => _isProcessing = false);

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = '❌ Không tìm thấy khuôn mặt nào trong ảnh camera. Vui lòng chụp lại rõ nét.';
        });
        return;
      }

      final face = faces.first;
      final livenessResult = FaceLivenessChecker.evaluate(face: face, totalFaces: faces.length);

      if (!livenessResult.isSuccess) {
        setState(() {
          _isLivenessPassed = false;
          _statusMessage = livenessResult.errorMessage ?? 'Kiểm tra Liveness không đạt';
        });
        return;
      }

      // Trích xuất đặc trưng
      final features = _extractFaceFeatures(face);
      final profile = {
        'username': username,
        'role': role,
        'enrolledAt': DateTime.now().toIso8601String(),
        'features': features,
      };

      // Đồng bộ mẫu khuôn mặt lên máy chủ qua API: POST /api/Attendance/enroll-face
      final enrollResult = await Auth.enrollFace(
        username: username,
        features: features,
      );

      // Lưu bản sao an toàn cục bộ vào SharedPreferences để hỗ trợ offline/dự phòng
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getString(_enrolledProfilesKey);
      List<dynamic> profiles = [];
      if (rawList != null) {
        try {
          profiles = jsonDecode(rawList) as List<dynamic>;
        } catch (_) {}
      }

      profiles.removeWhere((p) =>
          (p is Map) && p['username']?.toString().toLowerCase() == username.toLowerCase());
      profiles.add(profile);
      await prefs.setString(_enrolledProfilesKey, jsonEncode(profiles));

      final bool serverOk = enrollResult['success'] == true;
      final String syncStatus = serverOk
          ? 'Đã đồng bộ thành công lên máy chủ (POST /api/Attendance/enroll-face)'
          : 'Đã lưu an toàn cục bộ trên thiết bị (${enrollResult['message']})';

      setState(() {
        _isLivenessPassed = true;
        _lastEnrolledProfile = profile;
        _statusMessage = '✅ Đăng ký mẫu khuôn mặt thành công cho tài khoản "$username"!\n'
            '• ${livenessResult.successDetail ?? 'Đạt chuẩn Liveness'}\n'
            '• $syncStatus.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã ghi nhận mẫu khuôn mặt thành công cho $username!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Lỗi xử lý hình ảnh: $e';
      });
    }
  }

  // ==========================================
  // 4. TAB ĐĂNG NHẬP BẰNG KHUÔN MẶT
  // Nhập username -> Tải mẫu từ server (GET /api/Attendance/face-profile/{username})
  // Quét camera Liveness -> So khớp ma trận -> Tự động kích hoạt gửi OTP qua email
  // ==========================================

  Future<void> _handleVerification() async {
    final username = _authUsernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Tên đăng nhập của bạn trước để đối chiếu mẫu khuôn mặt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang tải mẫu khuôn mặt của tài khoản "$username" từ máy chủ...';
      _isLivenessPassed = false;
      _matchedAccount = null;
    });

    // 1. Tải mẫu khuôn mặt từ server: GET /api/Attendance/face-profile/{username}
    Map<String, dynamic>? enrolledFeatures;
    String? enrolledRole;

    try {
      final serverResp = await Auth.getFaceProfile(username);
      if (serverResp['success'] == true && serverResp['data'] != null) {
        final data = serverResp['data'];
        if (data is Map) {
          if (data['faceVectorJson'] is String && (data['faceVectorJson'] as String).isNotEmpty) {
            try {
              enrolledFeatures = Map<String, dynamic>.from(jsonDecode(data['faceVectorJson']) as Map);
            } catch (_) {}
          } else if (data['features'] is Map) {
            enrolledFeatures = Map<String, dynamic>.from(data['features'] as Map);
          } else if (data['Features'] is Map) {
            enrolledFeatures = Map<String, dynamic>.from(data['Features'] as Map);
          }
          enrolledRole = data['role']?.toString() ?? data['Role']?.toString();
        }
      }
    } catch (_) {}

    // 2. Dự phòng: Kiểm tra bản sao cục bộ nếu máy chủ chưa có endpoint hoặc mạng chập chờn
    if (enrolledFeatures == null) {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getString(_enrolledProfilesKey);
      if (rawList != null) {
        try {
          final List<dynamic> localList = jsonDecode(rawList) as List<dynamic>;
          for (final p in localList) {
            if (p is Map &&
                p['username']?.toString().toLowerCase() == username.toLowerCase() &&
                p['features'] is Map) {
              enrolledFeatures = Map<String, dynamic>.from(p['features'] as Map);
              enrolledRole = p['role']?.toString();
              break;
            }
          }
        } catch (_) {}
      }
    }

    if (enrolledFeatures == null) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '❌ Không tìm thấy mẫu khuôn mặt cho tài khoản "$username".\n'
            'Vui lòng đăng nhập bằng mật khẩu & OTP và vào mục "Đăng ký mẫu" để thiết lập khuôn mặt trước.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tài khoản "$username" chưa đăng ký mẫu khuôn mặt trên hệ thống.'),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = false;
    });

    // 3. Mở camera chụp ảnh trực tiếp
    final file = await _captureFromCamera();
    if (file == null) return;

    setState(() {
      _capturedImage = file;
      _isProcessing = true;
      _statusMessage = 'Đang quét khuôn mặt, kiểm tra Liveness và so khớp ma trận đặc trưng...';
      _isLivenessPassed = false;
    });

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      setState(() => _isProcessing = false);

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = '❌ Không nhận diện được khuôn mặt trong ảnh camera. Vui lòng nhìn thẳng và thử lại.';
        });
        return;
      }

      final face = faces.first;
      final livenessResult = FaceLivenessChecker.evaluate(face: face, totalFaces: faces.length);

      if (!livenessResult.isSuccess) {
        setState(() {
          _isLivenessPassed = false;
          _statusMessage = livenessResult.errorMessage ?? 'Kiểm tra Liveness không đạt';
        });
        return;
      }

      // 4. So khớp ma trận đặc trưng hình học
      final currentFeatures = _extractFaceFeatures(face);
      final similarity = _calculateSimilarity(currentFeatures, enrolledFeatures);

      // Ngưỡng tin cậy tối thiểu 65% để xác thực thành công
      if (similarity < 0.65) {
        setState(() {
          _isLivenessPassed = false;
          _statusMessage = '❌ Khuôn mặt không khớp với mẫu của tài khoản "$username".\n'
              'Độ tương đồng: ${(similarity * 100).toStringAsFixed(1)}% (Yêu cầu ≥ 65%).\n'
              'Vui lòng căn chỉnh lại góc mặt hoặc sử dụng đăng nhập mật khẩu.';
        });
        return;
      }

      // 5. Khuôn mặt khớp thành công -> Tự động kích hoạt gửi OTP qua email (TUYỆT ĐỐI KHÔNG BYPASS OTP)
      final accountData = {
        'username': username,
        'role': enrolledRole ?? 'Staff',
        'similarity': similarity,
      };

      setState(() {
        _isLivenessPassed = true;
        _matchedAccount = accountData;
        _statusMessage = '✅ Xác thực khuôn mặt thành công cho tài khoản "$username"!\n'
            '• Độ tương đồng: ${(similarity * 100).toStringAsFixed(1)}%\n'
            '• ${livenessResult.successDetail ?? 'Đạt chuẩn Liveness'}\n'
            '• Đang tự động gửi mã OTP tới email của tài khoản...';
      });

      _triggerOtpAndShowLoginDialog(username);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Lỗi xử lý xác thực: $e';
      });
    }
  }

  /// Tự động kích hoạt gửi mã OTP qua email và yêu cầu người dùng nhập OTP để hoàn tất đăng nhập
  Future<void> _triggerOtpAndShowLoginDialog(String username) async {
    final otpResult = await Auth.requestOtp(username);
    final isSuccess = otpResult['success'] == true;
    final msg = otpResult['message'] ??
        (isSuccess
            ? 'Mã xác thực OTP đã được gửi đến email đăng ký của bạn. Vui lòng kiểm tra hộp thư.'
            : 'Không thể gửi mã OTP');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );

    if (isSuccess) {
      // Mở hộp thoại yêu cầu nhập mật khẩu và mã OTP để hoàn tất đăng nhập
      _showCompleteLoginSheet(username);
    }
  }

  void _showCompleteLoginSheet(String username) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hoàn tất đăng nhập: $username',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Khuôn mặt đã được xác thực an toàn qua Camera & ML Kit.\n'
                    'Vui lòng nhập mật khẩu và mã OTP vừa nhận từ email để hoàn tất đăng nhập (Không thể bypass OTP).',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 16),

                // Trường nhập mật khẩu
                TextField(
                  controller: _authPasswordController,
                  obscureText: _obscureAuthPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu tài khoản',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureAuthPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setSheetState(() => _obscureAuthPassword = !_obscureAuthPassword);
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Trường nhập mã OTP từ email (Bắt buộc)
                TextField(
                  controller: _authOtpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Mã xác thực OTP (từ email)',
                    prefixIcon: const Icon(Icons.security_rounded),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Nút Đăng nhập hoàn tất
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmittingLogin
                        ? null
                        : () async {
                            final password = _authPasswordController.text;
                            final otp = _authOtpController.text.trim();

                            if (password.isEmpty || otp.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập cả mật khẩu và mã OTP'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setSheetState(() => _isSubmittingLogin = true);
                            final result = await Auth.login(username, password, otp: otp);
                            setSheetState(() => _isSubmittingLogin = false);

                            if (result['success'] == true) {
                              if (!context.mounted) return;
                              Navigator.pop(ctx); // đóng bottom sheet

                              final String role = (result['role'] ?? 'User').toString().toLowerCase();
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
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'Đăng nhập không thành công'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmittingLogin
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Xác thực và Đăng nhập',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 5. GIAO DIỆN CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực Khuôn mặt (AI)'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.face_retouching_natural_rounded), text: 'Đăng nhập bằng khuôn mặt'),
            Tab(icon: Icon(Icons.person_add_alt_1_rounded), text: 'Đăng ký mẫu'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cảnh báo chống giả mạo: Chặn thư viện ảnh, chỉ cho phép camera
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[700]!.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: Colors.amber[800], size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chống giả mạo: Chặn ảnh từ thư viện, chỉ cho phép chụp trực tiếp từ Camera.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Khung hiển thị ảnh Camera chụp được
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isLivenessPassed ? Colors.green : Colors.blue.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _capturedImage != null
                      ? Image.file(_capturedImage!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_front_rounded, size: 70, color: Colors.blue[700]),
                            const SizedBox(height: 10),
                            const Text(
                              'Chưa có ảnh khuôn mặt từ Camera',
                              style: TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Hỗ trợ Camera thật và Máy ảo Android',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Khung trạng thái xử lý & Liveness
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isLivenessPassed
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isLivenessPassed ? Colors.green : Colors.blue.withValues(alpha: 0.25),
                  ),
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Đang kiểm tra Liveness và phân tích khuôn mặt...',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _isLivenessPassed ? Colors.green[900] : Colors.black87,
                          height: 1.4,
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Nội dung hiển thị theo Tab
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  if (_tabController.index == 0) {
                    // TAB 0: ĐĂNG NHẬP BẰNG KHUÔN MẶT
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _authUsernameController,
                          decoration: InputDecoration(
                            labelText: 'Tên người dùng (Username) hoặc Email',
                            hintText: 'Nhập tên tài khoản để đối chiếu mẫu',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _handleVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text(
                            'Chụp Camera quét khuôn mặt xác thực',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_matchedAccount != null) ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () => _triggerOtpAndShowLoginDialog(_matchedAccount!['username']),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[700],
                              side: BorderSide(color: Colors.green[700]!),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.lock_open_rounded),
                            label: Text('Nhập OTP hoàn tất đăng nhập (${_matchedAccount!['username']})'),
                          ),
                        ],
                      ],
                    );
                  } else {
                    // TAB 1: ĐĂNG KÝ MẪU (ENROLLMENT)
                    // Chỉ khả dụng khi người dùng ĐÃ ĐĂNG NHẬP
                    if (!_isLoggedIn) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock_person_rounded, size: 48, color: Colors.orange[800]),
                            const SizedBox(height: 12),
                            Text(
                              'Yêu cầu đăng nhập tài khoản',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Chức năng Đăng ký mẫu khuôn mặt chỉ khả dụng cho người dùng đã đăng nhập vào hệ thống.\n'
                              'Bạn không thể tự ý nhập tên bất kỳ để ghi đè mẫu sinh trắc học của tài khoản khác.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('Đi đến Đăng nhập'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Khi người dùng ĐÃ ĐĂNG NHẬP
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Thông tin tài khoản đăng nhập (Được khoá, không cho phép nhập tên tuỳ ý)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.account_circle_rounded, color: Colors.teal[800], size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tài khoản đăng ký: ${_loggedInUsername ?? ''}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal[900],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Vai trò: ${_loggedInRole ?? 'User'} • Mẫu sẽ được đồng bộ lên máy chủ',
                                      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Đã xác thực',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _handleEnrollment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.app_registration_rounded),
                          label: const Text(
                            'Chụp Camera đăng ký mẫu khuôn mặt',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_lastEnrolledProfile != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Đã lưu mẫu cho: ${_lastEnrolledProfile!['username']} '
                              '(${_lastEnrolledProfile!['role']}) lúc '
                              '${DateTime.tryParse(_lastEnrolledProfile!['enrolledAt'])?.toLocal().toString().split('.').first ?? ''}',
                              style: TextStyle(color: Colors.teal[900], fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
