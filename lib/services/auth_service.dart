import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';

class AuthService {
  String get apiUrl => "${Config_URL.baseUrl}Authenticate/login";
  String get requestOtpUrl => "${Config_URL.baseUrl}Authenticate/request-otp";
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Yêu cầu gửi mã OTP xác thực đăng nhập qua email
  /// Chỉ gửi yêu cầu và nhận kết quả thành công/thất bại từ máy chủ, không trả về OTP trong client.
  Future<Map<String, dynamic>> requestOtp(String username) async {
    try {
      final response = await http
          .post(
            Uri.parse(requestOtpUrl),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({"username": username.trim()}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool isSuccess = data is Map<String, dynamic> &&
            (data['status'] == true ||
                data['success'] == true ||
                !data.containsKey('status'));

        if (isSuccess) {
          return {
            "success": true,
            "message": data['message'] != null
                ? data['message'].toString()
                : 'Mã OTP đã được gửi đến email đăng ký của bạn.',
          };
        } else {
          return {
            "success": false,
            "message": (data is Map && data['message'] != null)
                ? data['message'].toString()
                : 'Gửi mã OTP không thành công.',
          };
        }
      } else {
        String msg = "Không thể gửi mã OTP (Mã lỗi ${response.statusCode})";
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        return {"success": false, "message": msg};
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Quá thời gian kết nối máy chủ (10s). Vui lòng thử lại.",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Lỗi kết nối khi yêu cầu OTP: $e",
      };
    }
  }

  /// Đăng nhập với Tên đăng nhập + Mật khẩu + Mã OTP (Bắt buộc OTP)
  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? otp,
  }) async {
    try {
      final Map<String, dynamic> body = {
        "username": username.trim(),
        "password": password,
      };
      if (otp != null && otp.trim().isNotEmpty) {
        body["otp"] = otp.trim();
      }

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('status') && data['status'] == false) {
            return {
              "success": false,
              "message": data['message'] ?? 'Đăng nhập không thành công',
            };
          }

          final String? token = data['token'];
          if (token == null || token.isEmpty) {
            return {
              "success": false,
              "message": data['message'] ?? 'Không nhận được token xác thực',
            };
          }

          Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
          final dynamic rawRole = decodedToken['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
              decodedToken['role'] ??
              decodedToken['roles'];

          String role = 'User';
          if (rawRole is List && rawRole.isNotEmpty) {
            role = rawRole.first.toString();
          } else if (rawRole != null) {
            role = rawRole.toString();
          }

          final dynamic rawName = decodedToken['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
              decodedToken['name'] ??
              decodedToken['unique_name'] ??
              decodedToken['sub'] ??
              username;

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          await prefs.setString('user_role', role);
          await prefs.setString('user_name', rawName.toString());

          return {
            "success": true,
            "token": token,
            "role": role,
            "decodedToken": decodedToken,
            "message": data['message'] ?? 'Đăng nhập thành công',
          };
        }
        return {"success": false, "message": "Định dạng dữ liệu phản hồi không đúng"};
      } else {
        // Xử lý các mã lỗi như 400 (OTP sai), 401 (Sai username/password), 500, v.v.
        String msg = "Đăng nhập thất bại: mã lỗi ${response.statusCode}";
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}

        if (response.statusCode == 401) {
          // Xóa sạch session cũ nếu bị từ chối
          await logout();
        }

        return {"success": false, "message": msg};
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Quá thời gian chờ phản hồi từ máy chủ (10s). Vui lòng thử lại.",
      };
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối máy chủ: $e"};
    }
  }

  /// Xóa sạch thông tin token và quyền đăng nhập khỏi thiết bị
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_name');
  }
}
