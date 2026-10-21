import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';

class AuthService {
  String get apiUrl => "${Config_URL.baseUrl}Authenticate/login";

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

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
        String msg = "Đăng nhập thất bại: mã lỗi ${response.statusCode}";
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        return {"success": false, "message": msg};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_name');
  }
}
