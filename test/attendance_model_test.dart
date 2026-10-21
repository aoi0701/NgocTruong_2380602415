import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/models/attendance.dart';

void main() {
  group('AttendanceRecord Model Tests', () {
    test('fromJson and toJson serialization', () {
      final now = DateTime.now();
      final record = AttendanceRecord(
        id: 101,
        userId: 'staff_test',
        checkInTime: now,
        checkOutTime: now.add(const Duration(hours: 8, minutes: 15)),
        method: 'GPS',
        latitude: 10.8550,
        longitude: 106.7854,
        locationName: 'Trường ĐH HUTECH Khu E',
        status: 'VALID',
        notes: 'Chấm công GPS thành công',
      );

      final jsonMap = record.toJson();
      expect(jsonMap['id'], 101);
      expect(jsonMap['userId'], 'staff_test');
      expect(jsonMap['method'], 'GPS');
      expect(jsonMap['latitude'], 10.8550);
      expect(jsonMap['longitude'], 106.7854);
      expect(jsonMap['locationName'], 'Trường ĐH HUTECH Khu E');
      expect(jsonMap['status'], 'VALID');

      final reconstructed = AttendanceRecord.fromJson(jsonMap);
      expect(reconstructed.id, 101);
      expect(reconstructed.userId, 'staff_test');
      expect(reconstructed.method, 'GPS');
      expect(reconstructed.latitude, 10.8550);
      expect(reconstructed.longitude, 106.7854);
      expect(reconstructed.isCompleted, true);
      expect(reconstructed.isToday, true);
    });

    test('PascalCase from backend ASP.NET Core support', () {
      final pascalJson = {
        'Id': 202,
        'UserId': 'admin_hutech',
        'CheckInTime': '2026-10-21T08:00:00Z',
        'CheckOutTime': '2026-10-21T17:00:00Z',
        'Method': 'QR',
        'Latitude': 10.8551,
        'Longitude': 106.7855,
        'LocationName': 'HUTECH Main Campus',
        'Status': 'ON_TIME',
        'Notes': 'Quét QR cổng chính',
      };

      final record = AttendanceRecord.fromJson(pascalJson);
      expect(record.id, 202);
      expect(record.userId, 'admin_hutech');
      expect(record.method, 'QR');
      expect(record.status, 'ON_TIME');
      expect(record.isCompleted, true);
    });

    test('Duration calculation handles active shifts', () {
      final record = AttendanceRecord(
        id: 303,
        userId: 'active_staff',
        checkInTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        checkOutTime: null,
        method: 'DASHBOARD',
      );

      expect(record.isCompleted, false);
      expect(record.durationText.contains('Đang trực'), true);
      expect(record.formattedCheckOut, 'Chưa ra ca');
    });
  });
}
