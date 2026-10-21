import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ngoc_truong_2380602415/services/api_client.dart';
import 'package:ngoc_truong_2380602415/services/attendance_service.dart';

class _AttendanceApi extends ApiClient {
  String? requestedPath;
  Map<String, dynamic>? payload;

  @override
  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = ApiClient.defaultTimeout,
  }) async {
    requestedPath = endpoint;
    payload = Map<String, dynamic>.from(body as Map);
    return http.Response(
      jsonEncode({
        'status': true,
        'data': {'id': 17, 'userId': 'employee', 'method': 'Face'},
      }),
      200,
    );
  }
}

void main() {
  for (final checkIn in [true, false]) {
    test(
      'face ${checkIn ? 'check-in' : 'check-out'} sends proof to attendance API',
      () async {
        final api = _AttendanceApi();
        final service = AttendanceService(apiClient: api);
        final result = checkIn
            ? await service.checkIn(method: 'Face', faceProof: 'captured-face')
            : await service.checkOut(
                method: 'Face',
                faceProof: 'captured-face',
              );
        expect(result.success, isTrue);
        expect(result.data?.id, 17);
        expect(
          api.requestedPath,
          'Attendance/${checkIn ? 'check-in' : 'check-out'}',
        );
        expect(api.payload?['method'], 'Face');
        expect(api.payload?['faceProof'], 'captured-face');
        expect(api.payload?.containsKey('password'), isFalse);
        expect(api.payload?.containsKey('otp'), isFalse);
      },
    );
  }
}
