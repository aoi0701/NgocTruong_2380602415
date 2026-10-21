import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth.dart';
import 'admin_screen.dart';
import 'staff_screen.dart';
import 'main_screen.dart';
import 'registration_screen.dart';
import 'live_face_capture_screen.dart';

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
            final dynamic rawRole =
                decoded['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
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
          content: Text(
            'Vui lòng nhập Tên đăng nhập hoặc Email trước để nhận mã OTP',
          ),
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
              result['message'] ??
                  'Mã OTP đã được gửi đến email đăng ký của bạn. Vui lòng kiểm tra hộp thư.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        // Server trả về lỗi (như 503 SMTP chưa cấu hình, 429 cooldown, hoặc 404):
        // Hiển thị thông báo lỗi thật màu đỏ chi tiết.
        // Tuyệt đối KHÔNG bật trạng thái "Đã gửi OTP", KHÔNG đếm cooldown 60s.
        final errorMsg =
            result['message'] ??
            'Không thể gửi mã OTP. Vui lòng kiểm tra lại tài khoản.';
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

    // Không chặn ở client khi ô OTP trống:
    // Backend sẽ quyết định xem tài khoản có cần OTP hay không (Admin được miễn).

    setState(() => _isLoading = true);

    try {
      final result = await Auth.login(username, password, otp: otp.isNotEmpty ? otp : null);
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
        // Kiểm tra nếu là lỗi yêu cầu OTP (OTP_REQUIRED) cho tài khoản Staff/User:
        // Giữ nguyên username/password đã nhập và hướng dẫn bấm "Gửi mã OTP"
        if (result['code'] == 'OTP_REQUIRED' || result['requiresOtp'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ??
                    'Tài khoản yêu cầu mã OTP. Vui lòng bấm "Gửi mã OTP" bên dưới và nhập mã từ email.',
              ),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        // Xóa sạch token cũ khi 401 Unauthorized hoặc đăng nhập thất bại
        await Auth.logout();
        final errorMessage =
            result['message'] ??
            'Tên đăng nhập, mật khẩu hoặc mã OTP không chính xác';
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

  /// Đăng nhập bằng khuôn mặt:
  /// Yêu cầu nhập username trước, mở camera realtime dùng chung và gửi đặc trưng lên backend đối chiếu
  Future<void> _handleFaceLogin() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập Tên đăng nhập trước khi quét khuôn mặt',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mở camera realtime dùng chung để nhận diện người thật và trích xuất đặc trưng
    final features = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => LiveFaceCaptureScreen(
          title: 'Đăng nhập khuôn mặt: $username',
        ),
      ),
    );

    if (features == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = await Auth.loginWithFace(username, features);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final String role = (result['role'] ?? 'User').toString();
        final normalized = role.toLowerCase();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập bằng khuôn mặt thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

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
        await Auth.logout();
        final String? code = result['code']?.toString();
        final String msg = result['message']?.toString() ??
            'Đăng nhập bằng khuôn mặt không thành công.';

        if (code == 'NO_FACE_PROFILE') {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Chưa có mẫu khuôn mặt'),
                ],
              ),
              content: const Text(
                'Tài khoản này chưa đăng ký mẫu khuôn mặt.\n\n'
                'Vui lòng đăng nhập thông thường bằng mật khẩu, sau đó vào mục Chấm công khuôn mặt để đăng ký mẫu một lần trước khi sử dụng tính năng này.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Thử lại',
                textColor: Colors.white,
                onPressed: _handleFaceLogin,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối khi đăng nhập khuôn mặt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF087F8C)),
      filled: true,
      fillColor: const Color(0xFFF1F6FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF087F8C), width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: Color(0xFFE0F2F1),
                        child: Icon(
                          Icons.access_time_rounded,
                          size: 36,
                          color: Color(0xFF087F8C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chấm công',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF155A80),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đăng nhập để quản lý thời gian làm việc',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF5D7180)),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        'Tên đăng nhập hoặc email',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.next,
                      decoration:
                          _fieldDecoration(
                            'Mật khẩu',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isLoading) _handleLogin();
                      },
                      decoration: _fieldDecoration(
                        'Mã xác thực OTP',
                        Icons.mark_email_read_outlined,
                      ).copyWith(
                        helperText: 'Tài khoản Admin không cần nhập mã OTP',
                        helperStyle: TextStyle(
                          color: Colors.blueGrey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: (_isSendingOtp || _otpCooldown > 0)
                            ? null
                            : _handleRequestOtp,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF087F8C),
                        ),
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _otpCooldown > 0
                                    ? 'Gửi lại sau ${_otpCooldown}s'
                                    : 'Gửi OTP',
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF155A80),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleFaceLogin,
                        icon: const Icon(Icons.face_rounded, color: Color(0xFF087F8C)),
                        label: const Text(
                          'Đăng nhập bằng khuôn mặt',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF087F8C),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF087F8C), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegistrationScreen(),
                            ),
                          ),
                          child: const Text(
                            'Đăng ký ngay',
                            style: TextStyle(color: Color(0xFF087F8C)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
