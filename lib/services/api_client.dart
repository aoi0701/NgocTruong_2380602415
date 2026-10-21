import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? Config_URL.baseUrl;

  Future<Map<String, String>> _buildHeaders(Map<String, String>? headers) async {
    final Map<String, String> defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null && token.isNotEmpty) {
      defaultHeaders['Authorization'] = 'Bearer $token';
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

  Future<http.Response> get(String endpoint, {Map<String, String>? headers}) async {
    final resolvedHeaders = await _buildHeaders(headers);
    return http.get(
      _buildUri(endpoint),
      headers: resolvedHeaders,
    );
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final resolvedHeaders = await _buildHeaders(headers);
    return http.post(
      _buildUri(endpoint),
      headers: resolvedHeaders,
      body: body is String ? body : (body != null ? jsonEncode(body) : null),
    );
  }

  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final resolvedHeaders = await _buildHeaders(headers);
    return http.put(
      _buildUri(endpoint),
      headers: resolvedHeaders,
      body: body is String ? body : (body != null ? jsonEncode(body) : null),
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final resolvedHeaders = await _buildHeaders(headers);
    return http.delete(
      _buildUri(endpoint),
      headers: resolvedHeaders,
      body: body != null ? (body is String ? body : jsonEncode(body)) : null,
    );
  }
}
