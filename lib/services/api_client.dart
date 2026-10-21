import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';

class ApiClient {
  final String baseUrl;
  static const Duration defaultTimeout = Duration(seconds: 10);

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? Config_URL.baseUrl;

  Future<Map<String, String>> _buildHeaders(Map<String, String>? headers) async {
    final Map<String, String> defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null && token.trim().isNotEmpty) {
      defaultHeaders['Authorization'] = 'Bearer ${token.trim()}';
    }

    if (headers != null) {
      defaultHeaders.addAll(headers);
    }
    return defaultHeaders;
  }

  Uri _buildUri(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  /// Xử lý phản hồi và các mã trạng thái đặc biệt (401, 403, 409, 500)
  Future<http.Response> _processResponse(http.Response response) async {
    final statusCode = response.statusCode;

    if (statusCode == 401) {
      // 401 Unauthorized: Phiên làm việc hết hạn hoặc không hợp lệ -> Xóa sạch thông tin token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('user_role');
      await prefs.remove('user_name');
      debugPrint('[ApiClient] 401 Unauthorized: Đã dọn sạch phiên đăng nhập.');
    } else if (statusCode == 403) {
      debugPrint('[ApiClient] 403 Forbidden: Tài khoản không có quyền truy cập tài nguyên.');
    } else if (statusCode == 409) {
      debugPrint('[ApiClient] 409 Conflict: Xung đột dữ liệu hoặc bản ghi đã tồn tại.');
    } else if (statusCode >= 500) {
      debugPrint('[ApiClient] $statusCode Internal Server Error: Máy chủ phản hồi lỗi.');
    }

    return response;
  }

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
  }) async {
    final resolvedHeaders = await _buildHeaders(headers);
    final response = await http
        .get(
          _buildUri(endpoint),
          headers: resolvedHeaders,
        )
        .timeout(timeout);
    return await _processResponse(response);
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = defaultTimeout,
  }) async {
    final resolvedHeaders = await _buildHeaders(headers);
    final response = await http
        .post(
          _buildUri(endpoint),
          headers: resolvedHeaders,
          body: body is String ? body : (body != null ? jsonEncode(body) : null),
        )
        .timeout(timeout);
    return await _processResponse(response);
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = defaultTimeout,
  }) async {
    final resolvedHeaders = await _buildHeaders(headers);
    final response = await http
        .put(
          _buildUri(endpoint),
          headers: resolvedHeaders,
          body: body is String ? body : (body != null ? jsonEncode(body) : null),
        )
        .timeout(timeout);
    return await _processResponse(response);
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = defaultTimeout,
  }) async {
    final resolvedHeaders = await _buildHeaders(headers);
    final response = await http
        .delete(
          _buildUri(endpoint),
          headers: resolvedHeaders,
          body: body != null ? (body is String ? body : jsonEncode(body)) : null,
        )
        .timeout(timeout);
    return await _processResponse(response);
  }
}
