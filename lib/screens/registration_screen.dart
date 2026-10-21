import 'package:flutter/material.dart';
import '../utils/auth.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F8FC),
        foregroundColor: const Color(0xFF155A80),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Color(0xFFE0F2F1),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 32,
                          color: Color(0xFF087F8C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tạo tài khoản',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF155A80),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bắt đầu quản lý thời gian cùng Chấm công',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF5D7180)),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.newUsername],
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        'Tên đăng nhập',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        'Email',
                        Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isLoading) _handleRegister();
                      },
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
                    const SizedBox(height: 10),
                    const Text(
                      'Mật khẩu có ít nhất 6 ký tự.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5D7180)),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tài khoản mặc định: User. Quyền nhân viên do quản trị viên cấp.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF5D7180)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
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
                                'Đăng ký',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Đã có tài khoản?'),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Đăng nhập',
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

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // 1. Kiểm tra không để trống trường nào
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ tất cả các trường thông tin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Validate định dạng email đúng chuẩn (@ và domain)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Định dạng email không hợp lệ (Ví dụ: sinhvien@domain.edu.vn)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4. Validate mật khẩu tối thiểu 6 ký tự
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu phải có ít nhất 6 ký tự'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Auth.register(
        username: username,
        email: email,
        password: password,
        role: 'User',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ??
                  'Đăng ký tài khoản thành công! Vui lòng đăng nhập.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      } else {
        final errorMessage = result['message'] ?? 'Đăng ký thất bại';
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
          content: Text('Lỗi kết nối khi đăng ký: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
