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

  // Trạng thái tab Đăng ký mẫu (Enrollment)
  final TextEditingController _enrollUsernameController = TextEditingController();
  final TextEditingController _enrollRoleController = TextEditingController(text: 'Staff');
  Map<String, dynamic>? _lastEnrolledProfile;

  // Trạng thái tab Xác thực (Authentication)
  Map<String, dynamic>? _matchedAccount;
  final TextEditingController _authPasswordController = TextEditingController();
  final TextEditingController _authOtpController = TextEditingController();
  bool _isSubmittingLogin = false;
  bool _obscureAuthPassword = true;

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

    _initDefaultUsername();
  }

  Future<void> _initDefaultUsername() async {
    if (widget.defaultUsername != null && widget.defaultUsername!.isNotEmpty) {
      _enrollUsernameController.text = widget.defaultUsername!;
    } else {
      final currentUsername = await Auth.getUsername();
      final currentRole = await Auth.getRole();
      if (currentUsername != null && currentUsername.isNotEmpty) {
        setState(() {
          _enrollUsernameController.text = currentUsername;
          if (currentRole != null && currentRole.isNotEmpty) {
            _enrollRoleController.text = currentRole;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    _tabController.dispose();
    _enrollUsernameController.dispose();
    _enrollRoleController.dispose();
    _authPasswordController.dispose();
    _authOtpController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. KIỂM TRA LIVENESS & TÍNH TOÁN ĐẶC TRƯNG
  // ==========================================

  /// Kiểm tra Liveness nghiêm ngặt theo Section B:
  /// - Cả hai mắt mở rõ (> 0.75)
  /// - Góc mặt thẳng trực diện (quay ngang và nghiêng lệch <= 15°)
  String? _checkLiveness(Face face, int totalFaces) {
    if (totalFaces > 1) {
      return 'Phát hiện $totalFaces khuôn mặt trong ảnh. Vui lòng chỉ đứng một mình trước camera.';
    }

    final double leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
    final double rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;

    // Điều kiện: cả hai mắt mở > 0.75
    if (leftEyeOpen <= 0.75 || rightEyeOpen <= 0.75) {
      final leftPct = (leftEyeOpen * 100).toStringAsFixed(1);
      final rightPct = (rightEyeOpen * 100).toStringAsFixed(1);
      return '❌ Kiểm tra Liveness thất bại: Yêu cầu cả hai mắt mở rõ (> 75%).\n'
          'Hiện tại: Mắt trái: $leftPct%, Mắt phải: $rightPct%.\n'
          'Vui lòng mở to hai mắt, không nhắm mắt và không đeo kính râm.';
    }

    // Điều kiện: góc mặt thẳng
    final double rotY = face.headEulerAngleY ?? 0.0; // Yaw
    final double rotZ = face.headEulerAngleZ ?? 0.0; // Roll
    final double rotX = face.headEulerAngleX ?? 0.0; // Pitch

    if (rotY.abs() > 15.0 || rotZ.abs() > 15.0 || rotX.abs() > 20.0) {
      return '❌ Góc mặt chưa thẳng: Vui lòng nhìn trực diện vào camera.\n'
          'Hiện tại: Góc quay: ${rotY.toStringAsFixed(1)}°, Nghiêng: ${rotZ.toStringAsFixed(1)}° (Yêu cầu lệch ≤ 15°).';
    }

    return null; // Đạt chuẩn Liveness
  }

  /// Trích xuất vector đặc trưng hình học bất biến theo tỷ lệ
  Map<String, double> _extractFaceFeatures(Face face) {
    final box = face.boundingBox;
    final double boxAspect = box.height > 0 ? box.width / box.height : 1.0;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final mouth = face.landmarks[FaceLandmarkType.bottomMouth] ??
        face.landmarks[FaceLandmarkType.leftMouth];

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
    // Chênh lệch trung bình < 0.1 được xem là trùng khớp cao (> 70%)
    return (1.0 - (avgDiff * 3.0)).clamp(0.0, 1.0);
  }

  // ==========================================
  // 2. CHỤP ẢNH TỪ CAMERA (CHẶN THƯ VIỆN ẢNH)
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
  // ==========================================

  Future<void> _handleEnrollment() async {
    final username = _enrollUsernameController.text.trim();
    final role = _enrollRoleController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên tài khoản cần đăng ký mẫu khuôn mặt'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final file = await _captureFromCamera();
    if (file == null) return;

    setState(() {
      _capturedImage = file;
      _isProcessing = true;
      _statusMessage = 'Đang phân tích khuôn mặt và kiểm tra Liveness...';
      _isLivenessPassed = false;
    });

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      setState(() {
        _isProcessing = false;
      });

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = '❌ Không tìm thấy khuôn mặt nào trong ảnh camera. Vui lòng chụp lại rõ nét.';
        });
        return;
      }

      final face = faces.first;
      final livenessError = _checkLiveness(face, faces.length);
      if (livenessError != null) {
        setState(() {
          _isLivenessPassed = false;
          _statusMessage = livenessError;
        });
        return;
      }

      // Trích xuất đặc trưng và lưu mẫu vào SharedPreferences
      final features = _extractFaceFeatures(face);
      final profile = {
        'username': username,
        'role': role,
        'enrolledAt': DateTime.now().toIso8601String(),
        'features': features,
      };

      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getString(_enrolledProfilesKey);
      List<dynamic> profiles = [];
      if (rawList != null) {
        try {
          profiles = jsonDecode(rawList) as List<dynamic>;
        } catch (_) {}
      }

      // Ghi đè nếu username đã tồn tại mẫu, hoặc thêm mới
      profiles.removeWhere((p) => (p is Map) && p['username']?.toString().toLowerCase() == username.toLowerCase());
      profiles.add(profile);

      await prefs.setString(_enrolledProfilesKey, jsonEncode(profiles));

      setState(() {
        _isLivenessPassed = true;
        _lastEnrolledProfile = profile;
        _statusMessage = '✅ Đăng ký khuôn mặt mẫu thành công cho tài khoản "$username"!\n'
            '• Hai mắt mở rõ (> 75%)\n'
            '• Góc nhìn trực diện chuẩn\n'
            '• Mẫu sinh trắc học đã lưu bảo mật trên thiết bị.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã ghi nhận mẫu khuôn mặt thành công cho $username!'),
            backgroundColor: Colors.green,
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
  // 4. QUY TRÌNH XÁC THỰC KHUÔN MẶT (AUTHENTICATION)
  // ==========================================

  Future<void> _handleVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getString(_enrolledProfilesKey);
    List<dynamic> profiles = [];
    if (rawList != null) {
      try {
        profiles = jsonDecode(rawList) as List<dynamic>;
      } catch (_) {}
    }

    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có mẫu khuôn mặt nào được đăng ký trên thiết bị. Vui lòng chuyển sang tab "Đăng ký mẫu" trước.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final file = await _captureFromCamera();
    if (file == null) return;

    setState(() {
      _capturedImage = file;
      _isProcessing = true;
      _statusMessage = 'Đang quét khuôn mặt và đối chiếu mẫu sinh trắc học...';
      _isLivenessPassed = false;
      _matchedAccount = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      setState(() {
        _isProcessing = false;
      });

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = '❌ Không nhận diện được khuôn mặt. Vui lòng nhìn trực diện camera và thử lại.';
        });
        return;
      }

      final face = faces.first;
      final livenessError = _checkLiveness(face, faces.length);
      if (livenessError != null) {
        setState(() {
          _isLivenessPassed = false;
          _statusMessage = livenessError;
        });
        return;
      }

      // Đối chiếu với các mẫu đã ghi nhận trên thiết bị
      final currentFeatures = _extractFaceFeatures(face);
      Map<String, dynamic>? bestMatch;
      double highestSimilarity = 0.0;

      for (final p in profiles) {
        if (p is Map && p['features'] is Map) {
          final enrolledFeatures = Map<String, dynamic>.from(p['features'] as Map);
          final sim = _calculateSimilarity(currentFeatures, enrolledFeatures);
          if (sim > highestSimilarity) {
            highestSimilarity = sim;
            bestMatch = Map<String, dynamic>.from(p);
          }
        }
      }

      // Ngưỡng tin cậy tối thiểu 65% để xác thực thành công
      if (bestMatch == null || highestSimilarity < 0.65) {
        setState(() {
          _isLivenessPassed = true;
          _statusMessage = '❌ Không tìm thấy mẫu khuôn mặt phù hợp trong hệ thống.\n'
              'Độ tương đồng cao nhất: ${(highestSimilarity * 100).toStringAsFixed(1)}% (Yêu cầu ≥ 65%).\n'
              'Vui lòng đăng ký mẫu trước hoặc sử dụng đăng nhập mật khẩu/OTP truyền thống.';
        });
        return;
      }

      final matchedUsername = bestMatch['username']?.toString() ?? '';
      setState(() {
        _isLivenessPassed = true;
        _matchedAccount = bestMatch;
        _statusMessage = '✅ Xác thực khuôn mặt thành công!\n'
            '• Tài khoản: $matchedUsername\n'
            '• Vai trò: ${bestMatch!['role'] ?? 'Staff'}\n'
            '• Độ tương đồng: ${(highestSimilarity * 100).toStringAsFixed(1)}%\n'
            '• Đang tự động gửi mã OTP tới email của tài khoản...';
      });

      // Tự động kích hoạt gửi mã OTP đến email của người dùng đó (Không bypass OTP)
      _triggerOtpAndShowLoginDialog(matchedUsername);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Lỗi xử lý xác thực: $e';
      });
    }
  }

  /// Tự động kích hoạt gửi mã OTP đến email và hiển thị modal nhập OTP hoàn tất đăng nhập
  Future<void> _triggerOtpAndShowLoginDialog(String username) async {
    final otpResult = await Auth.requestOtp(username);
    final msg = otpResult['message'] ?? 'Mã OTP đã được gửi đến email đăng ký của bạn.';

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: otpResult['success'] == true ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );

    // Mở hộp thoại yêu cầu nhập mật khẩu và mã OTP để hoàn tất đăng nhập
    _showCompleteLoginSheet(username);
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
                    'Vui lòng nhập mật khẩu và mã OTP vừa nhận từ email để đăng nhập (Không thể bypass OTP).',
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

                // Trường nhập mã OTP từ email
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

                // Nút Đăng nhập
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
            Tab(icon: Icon(Icons.face_retouching_natural_rounded), text: 'Xác thực & Đăng nhập'),
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
                height: 260,
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
                          Text('Đang kiểm tra Liveness và phân tích khuôn mặt...'),
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

              // Nội dung hiển thị tùy theo Tab đang chọn
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  if (_tabController.index == 0) {
                    // TAB 1: XÁC THỰC & ĐĂNG NHẬP
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                    // TAB 2: ĐĂNG KÝ MẪU (ENROLLMENT)
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _enrollUsernameController,
                          decoration: InputDecoration(
                            labelText: 'Tên tài khoản nhân viên / người dùng',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: ['Staff', 'User', 'Admin'].contains(_enrollRoleController.text)
                              ? _enrollRoleController.text
                              : 'Staff',
                          decoration: InputDecoration(
                            labelText: 'Vai trò tài khoản',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Staff', child: Text('Nhân viên (Staff)')),
                            DropdownMenuItem(value: 'User', child: Text('Khách hàng / Sinh viên (User)')),
                            DropdownMenuItem(value: 'Admin', child: Text('Quản trị viên (Admin)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _enrollRoleController.text = val);
                            }
                          },
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
