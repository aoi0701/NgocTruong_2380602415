import 'package:flutter/material.dart';
import 'package:smart_auth/smart_auth.dart';
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
  final TextEditingController _initialsController = TextEditingController();
  final TextEditingController _roleController = TextEditingController(text: 'User');

  bool _isLoading = false;
  bool _obscurePassword = true;
  final SmartAuth _smartAuth = SmartAuth();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _initialsController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  // Tự động điền thông tin thông qua SmartAuth (Điểm cộng bài tập tuần 7)
  Future<void> _autofillWithSmartAuth() async {
    try {
      final credential = await _smartAuth.requestHint(
        isEmailAddressIdentifierSupported: true,
        isPhoneNumberIdentifierSupported: true,
      );

      if (credential != null) {
        setState(() {
          if (credential.id.isNotEmpty) {
            _emailController.text = credential.id;
            if (_usernameController.text.isEmpty) {
              final prefix = credential.id.split('@').first;
              _usernameController.text = prefix;
              if (prefix.length >= 2) {
                _initialsController.text = prefix.substring(0, 2).toUpperCase();
              }
            }
          }
          if (credential.name != null && credential.name!.isNotEmpty) {
            final words = credential.name!.trim().split(' ');
            if (words.isNotEmpty) {
              _initialsController.text = words
                  .where((w) => w.isNotEmpty)
                  .map((w) => w[0].toUpperCase())
                  .take(4)
                  .join();
            }
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tự động lấy thông tin từ SmartAuth!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('SmartAuth hint error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tính năng tự động điền khả dụng trên thiết bị di động có Google Services.'),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
    }
  }

  // Xử lý đăng ký tài khoản
  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final initials = _initialsController.text.trim();
    final role = _roleController.text.trim();

    // 1. Kiểm tra không để trống trường nào
    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        initials.isEmpty ||
        role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ tất cả các trường thông tin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Validate định dạng email đúng chuẩn (@ và domain)
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Định dạng email không hợp lệ (Ví dụ: sinhvien@domain.edu.vn)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Nghiêm cấm chọn hoặc gửi vai trò Admin qua form đăng ký công khai
    if (role != 'User' && role != 'Staff') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vai trò không hợp lệ. Chỉ chấp nhận User hoặc Staff.'),
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
        initials: initials,
        role: role,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        // Tùy chọn lưu lại credential thông qua SmartAuth nếu khả thi
        try {
          await _smartAuth.saveCredential(
            id: email,
            password: password,
            name: username,
          );
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Đăng ký tài khoản thành công! Vui lòng đăng nhập.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Đăng ký tài khoản'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Tạo tài khoản mới',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhanh chóng và dễ dàng',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Nút SmartAuth Autofill (Điểm cộng)
                OutlinedButton.icon(
                  onPressed: _autofillWithSmartAuth,
                  icon: Icon(Icons.flash_auto, color: Colors.blue[700]),
                  label: Text(
                    'Tự động điền bằng SmartAuth',
                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.blue[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tên người dùng
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'Tên người dùng (Username)',
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

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
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

                // Mật khẩu
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu',
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

                // Ký tự viết tắt (Initials)
                TextField(
                  controller: _initialsController,
                  maxLength: 5,
                  decoration: InputDecoration(
                    hintText: 'Ký tự viết tắt (VD: NT)',
                    counterText: '',
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

                // Vai trò: Chỉ cho phép User hoặc Staff (Gỡ bỏ hoàn toàn tùy chọn Admin)
                DropdownButtonFormField<String>(
                  value: ['User', 'Staff'].contains(_roleController.text)
                      ? _roleController.text
                      : 'User',
                  decoration: InputDecoration(
                    labelText: 'Vai trò (Role)',
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
                  items: const [
                    DropdownMenuItem(
                      value: 'User',
                      child: Text('Khách hàng / Sinh viên (User)'),
                    ),
                    DropdownMenuItem(
                      value: 'Staff',
                      child: Text('Nhân viên vận hành (Staff)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _roleController.text = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Nút Đăng ký
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                            'Đăng ký',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Chuyển về Đăng nhập
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản? '),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Đăng nhập',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
