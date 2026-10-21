import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class Auth {
  static final AuthService _authService = AuthService();
  static final ApiClient _apiClient = ApiClient();

  /// Yêu cầu gửi mã OTP tới email người dùng
  static Future<Map<String, dynamic>> requestOtp(String username) async {
    return await _authService.requestOtp(username);
  }

  /// Đăng nhập với tên tài khoản, mật khẩu và mã OTP
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? otp,
  }) async {
    return await _authService.login(username, password, otp: otp);
  }

  /// Đăng ký tài khoản mới (Chỉ cho phép User hoặc Staff)
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String initials,
    required String role,
  }) async {
    final cleanRole = role.trim();
    final Map<String, dynamic> body = {
      "username": username.trim(),
      "email": email.trim(),
      "password": password,
      "initials": initials.trim(),
      "role": cleanRole,
    };

    try {
      final response = await _apiClient.post('Authenticate/register', body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result is Map<String, dynamic>) {
          final bool isSuccess = result['success'] == true ||
              result['status'] == true ||
              result['status']?.toString().toLowerCase() == 'success' ||
              result['isSuccess'] == true;
          return {
            ...result,
            'success': isSuccess,
            'message': result['message'] ?? 'Đăng ký thành công.',
          };
        }
        return {
          'success': true,
          'message': 'Đăng ký thành công.',
        };
      } else {
        String msg = 'Đăng ký thất bại, vui lòng thử lại (${response.statusCode}).';
        try {
          final result = jsonDecode(response.body);
          if (result is Map<String, dynamic> && result['message'] != null) {
            msg = result['message'].toString();
          }
        } catch (_) {}
        return {
          'success': false,
          'message': msg,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: ${e.toString()}',
      };
    }
  }

  /// Đăng xuất và dọn dẹp sạch sẽ phiên lưu trữ
  static Future<void> logout() async {
    await _authService.logout();
  }

  /// Lấy JWT token đang lưu
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Lấy vai trò (Role) của người dùng hiện tại
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString('user_role');
    if (role != null && role.isNotEmpty) {
      return role;
    }

    final token = prefs.getString('jwt_token');
    if (token != null && token.isNotEmpty) {
      try {
        if (!JwtDecoder.isExpired(token)) {
          final decoded = JwtDecoder.decode(token);
          final dynamic rawRole = decoded['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
              decoded['role'] ??
              decoded['roles'];
          if (rawRole is List && rawRole.isNotEmpty) {
            role = rawRole.first.toString();
          } else if (rawRole != null) {
            role = rawRole.toString();
          }
          if (role != null) {
            await prefs.setString('user_role', role);
          }
        }
      } catch (_) {}
    }
    return role;
  }

  /// Lấy tên hiển thị của người dùng
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('user_name');
    if (name != null && name.isNotEmpty) return name;

    final token = prefs.getString('jwt_token');
    if (token != null && token.isNotEmpty) {
      try {
        if (!JwtDecoder.isExpired(token)) {
          final decoded = JwtDecoder.decode(token);
          final dynamic raw = decoded['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
              decoded['name'] ??
              decoded['unique_name'] ??
              decoded['sub'];
          if (raw != null) return raw.toString();
        }
      } catch (_) {}
    }
    return null;
  }

  /// Kiểm tra xem người dùng có phiên đăng nhập hợp lệ và token còn hạn hay không
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return false;
    try {
      final expired = JwtDecoder.isExpired(token);
      if (expired) {
        await logout();
        return false;
      }
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }
}
