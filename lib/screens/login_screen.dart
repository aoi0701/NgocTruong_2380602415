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

  @override
  void initState() {
    super.initState();
    _checkToken(); // Kiểm tra token tự động đăng nhập khi mở app
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Khắc phục triệt để lỗi phân quyền: Admin -> AdminScreen, Staff -> StaffScreen, User -> MainScreen
  Future<void> _checkToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token != null && token.isNotEmpty) {
        // Kiểm tra xem token còn hạn sử dụng hay không
        if (!JwtDecoder.isExpired(token)) {
          // Lấy vai trò (Role) từ SharedPreferences hoặc giải mã trực tiếp từ JWT
          String? role = prefs.getString('user_role');
          if (role == null || role.isEmpty) {
            final decoded = JwtDecoder.decode(token);
            final dynamic rawRole = decoded['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
                decoded['role'] ??
                decoded['roles'];
            if (rawRole is List && rawRole.isNotEmpty) {
              role = rawRole.first.toString();
            } else if (rawRole != null) {
              role = rawRole.toString();
            }
          }

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
          // Token đã hết hạn -> tiến hành dọn dẹp bộ nhớ
          await Auth.logout();
        }
      }
    } catch (e) {
      debugPrint('Lỗi kiểm tra token tự động đăng nhập: $e');
    }
  }

  // Gửi hoặc lấy mã OTP
  Future<void> _handleRequestOtp() async {
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
    final result = await Auth.requestOtp(username);
    if (!mounted) return;
    setState(() => _isSendingOtp = false);

    final otp = result['otp']?.toString() ?? '123456';
    _otpController.text = otp;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mã OTP của bạn: $otp (Đã tự động điền)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Xử lý khi nhấn nút Đăng nhập
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

    setState(() => _isLoading = true);

    try {
      final result = await Auth.login(username, password, otp: otp);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        // Lấy vai trò người dùng sau khi giải mã token thành công
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
        final errorMessage = result['message'] ?? 'Tên đăng nhập hoặc mật khẩu không đúng';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e'),
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

                // 3. Trường nhập mã OTP (Xác thực 2 lớp)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Mã xác thực OTP (VD: 123456)',
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
                        onPressed: _isSendingOtp ? null : _handleRequestOtp,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[700]!),
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
                            : const Text('Gửi OTP'),
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
