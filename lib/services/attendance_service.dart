import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import 'api_client.dart';

class AttendanceResult {
  final bool success;
  final String message;
  final AttendanceRecord? data;
  final int statusCode;

  AttendanceResult({
    required this.success,
    required this.message,
    this.data,
    this.statusCode = 200,
  });

  @override
  String toString() => 'AttendanceResult(success: $success, message: $message, statusCode: $statusCode)';
}

class AttendanceService {
  final ApiClient _apiClient;

  AttendanceService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // Singleton instance
  static final AttendanceService _instance = AttendanceService();
  static AttendanceService get instance => _instance;

  // Helper để lấy token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Gửi yêu cầu Check-in (Vào ca): POST /api/Attendance/check-in
  Future<AttendanceResult> checkIn({
    required String method,
    double? latitude,
    double? longitude,
    String? qrToken,
    String? locationName,
    String? notes,
  }) async {
    final Map<String, dynamic> body = {
      'method': method,
      'checkInTime': DateTime.now().toIso8601String(),
    };
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (qrToken != null) body['qrToken'] = qrToken;
    if (locationName != null) body['locationName'] = locationName;
    if (notes != null) body['notes'] = notes;

    try {
      final response = await _apiClient.post('Attendance/check-in', body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic decoded;
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          decoded = null;
        }

        AttendanceRecord? record;
        String message = 'Chấm công vào ca (Check-in) thành công!';

        if (decoded is Map<String, dynamic>) {
          if (decoded['message'] != null) {
            message = decoded['message'].toString();
          }
          final dynamic dataPart = decoded['data'] ?? decoded['record'] ?? decoded['attendance'] ?? decoded;
          if (dataPart is Map<String, dynamic>) {
            record = AttendanceRecord.fromJson(dataPart);
          }
        }

        return AttendanceResult(
          success: true,
          message: message,
          data: record,
          statusCode: response.statusCode,
        );
      } else {
        String errorMsg = 'Chấm công thất bại (Mã lỗi ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            errorMsg = decoded['message'] ?? decoded['error'] ?? decoded['title'] ?? errorMsg;
          }
        } catch (_) {}

        return AttendanceResult(
          success: false,
          message: errorMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AttendanceResult(
        success: false,
        message: 'Lỗi kết nối máy chủ khi chấm công: $e',
        statusCode: 500,
      );
    }
  }

  /// Gửi yêu cầu Check-out (Ra ca): POST /api/Attendance/check-out
  Future<AttendanceResult> checkOut({
    required String method,
    double? latitude,
    double? longitude,
    String? qrToken,
    String? locationName,
    String? notes,
  }) async {
    final Map<String, dynamic> body = {
      'method': method,
      'checkOutTime': DateTime.now().toIso8601String(),
    };
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (qrToken != null) body['qrToken'] = qrToken;
    if (locationName != null) body['locationName'] = locationName;
    if (notes != null) body['notes'] = notes;

    try {
      final response = await _apiClient.post('Attendance/check-out', body: body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        dynamic decoded;
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          decoded = null;
        }

        AttendanceRecord? record;
        String message = 'Chấm công ra ca (Check-out) thành công!';

        if (decoded is Map<String, dynamic>) {
          if (decoded['message'] != null) {
            message = decoded['message'].toString();
          }
          final dynamic dataPart = decoded['data'] ?? decoded['record'] ?? decoded['attendance'] ?? decoded;
          if (dataPart is Map<String, dynamic>) {
            record = AttendanceRecord.fromJson(dataPart);
          }
        }

        return AttendanceResult(
          success: true,
          message: message,
          data: record,
          statusCode: response.statusCode,
        );
      } else {
        String errorMsg = 'Check-out thất bại (Mã lỗi ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            errorMsg = decoded['message'] ?? decoded['error'] ?? decoded['title'] ?? errorMsg;
          }
        } catch (_) {}

        return AttendanceResult(
          success: false,
          message: errorMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AttendanceResult(
        success: false,
        message: 'Lỗi kết nối máy chủ khi check-out: $e',
        statusCode: 500,
      );
    }
  }

  /// Lấy lịch sử chấm công của người dùng hiện tại: GET /api/Attendance/my-history
  Future<List<AttendanceRecord>> getMyHistory() async {
    try {
      final response = await _apiClient.get('Attendance/my-history');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            list = decoded['data'];
          } else if (decoded['history'] is List) {
            list = decoded['history'];
          } else if (decoded['items'] is List) {
            list = decoded['items'];
          }
        }
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => AttendanceRecord.fromJson(item))
            .toList();
      } else {
        throw Exception('Không thể tải lịch sử chấm công (Mã lỗi: ${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Quản trị viên lấy tất cả lượt chấm công: GET /api/Attendance/all
  Future<List<AttendanceRecord>> getAllAttendances() async {
    try {
      final response = await _apiClient.get('Attendance/all');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            list = decoded['data'];
          } else if (decoded['attendances'] is List) {
            list = decoded['attendances'];
          } else if (decoded['items'] is List) {
            list = decoded['items'];
          }
        }
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => AttendanceRecord.fromJson(item))
            .toList();
      } else {
        throw Exception('Không thể tải danh sách chấm công toàn bộ (Mã lỗi: ${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }
}
