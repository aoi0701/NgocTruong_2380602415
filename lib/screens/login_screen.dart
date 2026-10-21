import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth.dart';
import 'admin_screen.dart';
import 'staff_screen.dart';
import 'main_screen.dart';
import 'registration_screen.dart';
import 'biometric_qr_screen.dart';
import 'face_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _obscurePassword = true;

  int _otpCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _checkToken(); // Tự động kiểm tra phiên và điều hướng nếu token còn hạn
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Khắc phục triệt để và duy trì phiên: Tự động đăng nhập khi token còn hạn
  /// Giải mã vai trò qua jwt_decoder và phân luồng chính xác: Admin, Staff, User
  Future<void> _checkToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token != null && token.isNotEmpty) {
        bool isExpired = true;
        try {
          isExpired = JwtDecoder.isExpired(token);
        } catch (_) {
          isExpired = true;
        }

        if (!isExpired) {
          // Lấy vai trò (Role) từ SharedPreferences hoặc giải mã trực tiếp từ JWT
          String? role = prefs.getString('user_role');
          try {
            final decoded = JwtDecoder.decode(token);
            final dynamic rawRole = decoded['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
                decoded['role'] ??
                decoded['roles'];
            if (rawRole is List && rawRole.isNotEmpty) {
              role = rawRole.first.toString();
            } else if (rawRole != null) {
              role = rawRole.toString();
            }
          } catch (_) {}

          if (!mounted) return;

          final normalized = role?.toLowerCase() ?? '';
          if (normalized == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminScreen()),
            );
          } else if (normalized == 'staff' || normalized == 'nhanvien') {
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
          // Token đã hết hạn -> tiến hành dọn dẹp sạch sẽ bộ nhớ
          await Auth.logout();
        }
      }
    } catch (e) {
      debugPrint('Lỗi kiểm tra token tự động đăng nhập: $e');
      await Auth.logout();
    }
  }

  /// Bắt đầu bộ đếm thời gian Cooldown 60s cho nút gửi OTP
  void _startOtpCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() {
      _otpCooldown = seconds;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_otpCooldown > 1) {
          _otpCooldown--;
        } else {
          _otpCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  /// Gửi yêu cầu mã OTP tới email đã đăng ký
  /// Bắt buộc KHÔNG tự động điền mã OTP và kích hoạt Cooldown 60 giây
  Future<void> _handleRequestOtp() async {
    if (_otpCooldown > 0) return;

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Tên đăng nhập hoặc Email trước để nhận mã OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final result = await Auth.requestOtp(username);
      if (!mounted) return;
      setState(() => _isSendingOtp = false);

      if (result['success'] == true) {
        // Server trả về 200 OK -> Mới bắt đầu đếm ngược cooldown 60s và hiển thị thông báo xanh
        _startOtpCooldown(60);

        // Xóa trường nhập OTP để người dùng tự nhập mã gửi về email
        _otpController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Mã OTP đã được gửi đến email đăng ký của bạn. Vui lòng kiểm tra hộp thư.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        // Server trả về lỗi (như 503 SMTP chưa cấu hình, 429 cooldown, hoặc 404):
        // Hiển thị thông báo lỗi thật màu đỏ chi tiết.
        // Tuyệt đối KHÔNG bật trạng thái "Đã gửi OTP", KHÔNG đếm cooldown 60s.
        final errorMsg = result['message'] ?? 'Không thể gửi mã OTP. Vui lòng kiểm tra lại tài khoản.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối khi yêu cầu OTP: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Xử lý Đăng nhập bắt buộc mã OTP nhận được qua email
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final otp = _otpController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên đăng nhập và mật khẩu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Bắt buộc người dùng phải nhập mã OTP nhận được qua email mới được đăng nhập
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mã OTP được gửi về email để xác thực đăng nhập'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Auth.login(username, password, otp: otp);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final String role = (result['role'] ?? 'User').toString();
        final normalized = role.toLowerCase();

        // Phân quyền chuẩn xác 3 luồng: Admin, Staff, User
        if (normalized == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminScreen()),
          );
        } else if (normalized == 'staff' || normalized == 'nhanvien') {
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
        // Xóa sạch token cũ khi 401 Unauthorized hoặc đăng nhập thất bại
        await Auth.logout();
        final errorMessage = result['message'] ?? 'Tên đăng nhập, mật khẩu hoặc mã OTP không chính xác';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối khi đăng nhập: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 50),
                // Logo Facebook theo mẫu tài liệu Tuần 7
                Text(
                  'facebook',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 35),

                // 1. Trường nhập số điện thoại hoặc email
                TextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Số điện thoại hoặc email',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Trường nhập mật khẩu
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Trường nhập mã OTP (Xác thực 2 lớp) + Nút gửi OTP kèm Cooldown 60s
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Mã xác thực OTP (từ email)',
                          prefixIcon: const Icon(Icons.security_rounded),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: (_isSendingOtp || _otpCooldown > 0)
                            ? null
                            : _handleRequestOtp,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          disabledForegroundColor: Colors.grey[600],
                          side: BorderSide(
                            color: _otpCooldown > 0 ? Colors.grey[350]! : Colors.blue[700]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _otpCooldown > 0 ? '${_otpCooldown}s' : 'Gửi OTP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _otpCooldown > 0 ? Colors.grey[600] : Colors.blue[700],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Nút Đăng nhập
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nút Đăng nhập bằng mã QR (Thuyết trình Câu 5)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BiometricQrScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple[700],
                      side: BorderSide(color: Colors.deepPurple[700]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text(
                      'Đăng nhập bằng mã QR',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Phím tắt xác thực Sinh trắc học: Vân tay & Khuôn mặt
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BiometricQrScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo[700],
                          side: BorderSide(color: Colors.indigo[200]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.fingerprint, size: 20),
                        label: const Text('Vân tay'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FaceAuthScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal[700],
                          side: BorderSide(color: Colors.teal[200]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.face_rounded, size: 20),
                        label: const Text('Khuôn mặt'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Điều hướng sang màn hình đăng ký
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản? '),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistrationScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Đăng ký ngay',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
