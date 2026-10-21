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

  bool get isConflict => statusCode == 409;

  @override
  String toString() =>
      'AttendanceResult(success: $success, message: $message, statusCode: $statusCode)';
}

class AttendanceService {
  final ApiClient _apiClient;

  AttendanceService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

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
    String? faceProof,
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
    if (faceProof != null) body['faceProof'] = faceProof;
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
          final dynamic dataPart =
              decoded['data'] ??
              decoded['record'] ??
              decoded['attendance'] ??
              decoded;
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
        String errorMsg = response.statusCode == 409
            ? 'Xung đột ca làm (409 Conflict): Bạn đã thực hiện check-in trong vòng 5 phút trước hoặc ca làm đã tồn tại.'
            : 'Chấm công thất bại (Mã lỗi ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            errorMsg =
                decoded['message'] ??
                decoded['error'] ??
                decoded['title'] ??
                errorMsg;
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
    String? faceProof,
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
    if (faceProof != null) body['faceProof'] = faceProof;
    if (locationName != null) body['locationName'] = locationName;
    if (notes != null) body['notes'] = notes;

    try {
      final response = await _apiClient.post(
        'Attendance/check-out',
        body: body,
      );

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
          final dynamic dataPart =
              decoded['data'] ??
              decoded['record'] ??
              decoded['attendance'] ??
              decoded;
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
            errorMsg =
                decoded['message'] ??
                decoded['error'] ??
                decoded['title'] ??
                errorMsg;
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

  /// Gửi cảm nhận sau ca làm: POST /api/Attendance/{id}/feedback
  Future<AttendanceResult> submitFeedback({
    required int recordId,
    required String mood,
    String? notes,
  }) async {
    final Map<String, dynamic> body = {'mood': mood};
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

    try {
      final response = await _apiClient.post(
        'Attendance/$recordId/feedback',
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic decoded;
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          decoded = null;
        }

        AttendanceRecord? record;
        String message = 'Gửi cảm nhận sau ca làm thành công! Cảm ơn bạn.';

        if (decoded is Map<String, dynamic>) {
          if (decoded['message'] != null) {
            message = decoded['message'].toString();
          }
          final dynamic dataPart =
              decoded['data'] ?? decoded['record'] ?? decoded;
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
        String errorMsg =
            'Gửi cảm nhận thất bại (Mã lỗi ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            errorMsg =
                decoded['message'] ??
                decoded['error'] ??
                decoded['title'] ??
                errorMsg;
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
        message: 'Lỗi kết nối máy chủ khi gửi cảm nhận: $e',
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
        throw Exception(
          'Không thể tải lịch sử chấm công (Mã lỗi: ${response.statusCode})',
        );
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
        throw Exception(
          'Không thể tải danh sách chấm công toàn bộ (Mã lỗi: ${response.statusCode})',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Lấy mã QR chấm công đang hiệu lực hoặc sinh mã chuẩn có tiền tố HUTECH_ATTENDANCE_QR_
  Future<String> getActiveQrCode() async {
    try {
      final response = await _apiClient.get('Attendance/active-qr');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final token =
              decoded['qrToken'] ?? decoded['token'] ?? decoded['data'];
          if (token != null && token.toString().trim().isNotEmpty) {
            return token.toString().trim();
          }
        } else if (decoded is String && decoded.trim().isNotEmpty) {
          return decoded.trim();
        }
      }
    } catch (_) {
      // Bỏ qua lỗi kết nối, sinh mã chuẩn bên dưới
    }
    // Chuẩn prefix HUTECH_ATTENDANCE_QR_ kèm thời gian hiện tại
    final now = DateTime.now();
    final timeStamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'HUTECH_ATTENDANCE_QR_CAMPUS_E_$timeStamp';
  }

  /// Admin lấy danh sách nhân viên: GET /api/Admin/employees
  Future<List<Employee>> getEmployees() async {
    try {
      final response = await _apiClient.get('Admin/employees');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            list = decoded['data'];
          } else if (decoded['employees'] is List) {
            list = decoded['employees'];
          } else if (decoded['users'] is List) {
            list = decoded['users'];
          }
        }
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => Employee.fromJson(item))
            .toList();
      } else {
        throw Exception(
          'Không thể tải danh sách nhân viên (Mã lỗi: ${response.statusCode})',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Admin cập nhật vai trò người dùng: POST /api/Admin/employees/{id}/role
  Future<AttendanceResult> updateEmployeeRole(
    String employeeId,
    String newRole,
  ) async {
    try {
      final response = await _apiClient.post(
        'Admin/employees/$employeeId/role',
        body: {'role': newRole},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AttendanceResult(
          success: true,
          message: 'Đã cập nhật vai trò thành "$newRole" thành công!',
          statusCode: response.statusCode,
        );
      } else {
        String msg = 'Cập nhật vai trò thất bại (mã ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            msg = decoded['message'] ?? decoded['error'] ?? msg;
          }
        } catch (_) {}
        return AttendanceResult(
          success: false,
          message: msg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AttendanceResult(
        success: false,
        message: 'Lỗi máy chủ khi cập nhật vai trò: $e',
        statusCode: 500,
      );
    }
  }

  /// Admin điều chỉnh bản ghi chấm công: PUT /api/Attendance/{id} (Bắt buộc có reason)
  Future<AttendanceResult> updateAttendance(
    dynamic id, {
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? status,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return AttendanceResult(
        success: false,
        message: 'Lý do điều chỉnh (reason) là bắt buộc.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> body = {'id': id, 'reason': reason.trim()};
    if (checkInTime != null) {
      body['checkInTime'] = checkInTime.toIso8601String();
    }
    if (checkOutTime != null) {
      body['checkOutTime'] = checkOutTime.toIso8601String();
    }
    if (status != null) body['status'] = status;

    try {
      final response = await _apiClient.put('Attendance/$id', body: body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AttendanceResult(
          success: true,
          message: 'Điều chỉnh bản ghi chấm công #$id thành công!',
          statusCode: response.statusCode,
        );
      } else {
        String msg = 'Điều chỉnh thất bại (Mã lỗi ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            msg = decoded['message'] ?? decoded['error'] ?? msg;
          }
        } catch (_) {}
        return AttendanceResult(
          success: false,
          message: msg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AttendanceResult(
        success: false,
        message: 'Lỗi khi gửi điều chỉnh chấm công: $e',
        statusCode: 500,
      );
    }
  }

  /// Admin xóa bản ghi chấm công: DELETE /api/Attendance/{id} (Bắt buộc có reason)
  Future<AttendanceResult> deleteAttendance(
    dynamic id, {
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return AttendanceResult(
        success: false,
        message: 'Lý do xóa bản ghi (reason) là bắt buộc.',
        statusCode: 400,
      );
    }

    try {
      final response = await _apiClient.delete(
        'Attendance/$id?reason=${Uri.encodeComponent(reason.trim())}',
        body: {'reason': reason.trim()},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AttendanceResult(
          success: true,
          message: 'Đã xóa bản ghi chấm công #$id thành công!',
          statusCode: response.statusCode,
        );
      } else {
        String msg = 'Xóa bản ghi thất bại (Mã lỗi ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            msg = decoded['message'] ?? decoded['error'] ?? msg;
          }
        } catch (_) {}
        return AttendanceResult(
          success: false,
          message: msg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AttendanceResult(
        success: false,
        message: 'Lỗi khi gửi yêu cầu xóa bản ghi: $e',
        statusCode: 500,
      );
    }
  }
}
