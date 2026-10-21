import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/models/attendance.dart';
import 'package:ngoc_truong_2380602415/services/attendance_service.dart';

void main() {
  group('AttendanceRecord Model Tests', () {
    test('fromJson and toJson serialization with all fields', () {
      final now = DateTime.now();
      final record = AttendanceRecord(
        id: 101,
        userId: 'staff_test',
        userName: 'Nguyễn Văn A',
        email: 'staff@hutech.edu.vn',
        initials: 'NA',
        deviceInfo: 'Pixel 7 Pro',
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
      expect(jsonMap['userName'], 'Nguyễn Văn A');
      expect(jsonMap['email'], 'staff@hutech.edu.vn');
      expect(jsonMap['initials'], 'NA');
      expect(jsonMap['deviceInfo'], 'Pixel 7 Pro');
      expect(jsonMap['method'], 'GPS');
      expect(jsonMap['latitude'], 10.8550);
      expect(jsonMap['longitude'], 106.7854);
      expect(jsonMap['locationName'], 'Trường ĐH HUTECH Khu E');
      expect(jsonMap['status'], 'VALID');

      final reconstructed = AttendanceRecord.fromJson(jsonMap);
      expect(reconstructed.id, 101);
      expect(reconstructed.userId, 'staff_test');
      expect(reconstructed.userName, 'Nguyễn Văn A');
      expect(reconstructed.email, 'staff@hutech.edu.vn');
      expect(reconstructed.initials, 'NA');
      expect(reconstructed.deviceInfo, 'Pixel 7 Pro');
      expect(reconstructed.method, 'GPS');
      expect(reconstructed.latitude, 10.8550);
      expect(reconstructed.longitude, 106.7854);
      expect(reconstructed.isCompleted, true);
      expect(reconstructed.isOpenShift, false);
      expect(reconstructed.isToday, true);
    });

    test('PascalCase from backend ASP.NET Core support', () {
      final pascalJson = {
        'Id': 202,
        'UserId': 'admin_hutech',
        'UserName': 'Admin HUTECH',
        'Email': 'admin@hutech.edu.vn',
        'Initials': 'AH',
        'DeviceInfo': 'Android Emulator',
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
      expect(record.userName, 'Admin HUTECH');
      expect(record.email, 'admin@hutech.edu.vn');
      expect(record.method, 'QR');
      expect(record.status, 'ON_TIME');
      expect(record.isCompleted, true);
      expect(record.isOpenShift, false);
    });

    test('Single open shift rules: isOpenShift is true when checkOutTime is null', () {
      final openRecord = AttendanceRecord(
        id: 303,
        userId: 'active_staff',
        checkInTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        checkOutTime: null,
        method: 'DASHBOARD',
      );

      expect(openRecord.isCompleted, false);
      expect(openRecord.isOpenShift, true);
      expect(openRecord.durationText.contains('Đang trực'), true);
      expect(openRecord.formattedCheckOut, 'Chưa ra ca');
    });

    test('Single open shift rules: isOpenShift is false when checkOutTime is present', () {
      final closedRecord = AttendanceRecord(
        id: 304,
        userId: 'active_staff',
        checkInTime: DateTime.now().subtract(const Duration(hours: 4)),
        checkOutTime: DateTime.now(),
        method: 'DASHBOARD',
      );

      expect(closedRecord.isCompleted, true);
      expect(closedRecord.isOpenShift, false);
      expect(closedRecord.durationText.contains('Đang trực'), false);
      expect(closedRecord.formattedCheckOut.contains('Chưa ra ca'), false);
    });

    test('AttendanceRecord.copyWith works as expected', () {
      final base = AttendanceRecord(
        id: 401,
        userId: 'test_user',
        status: 'VALID',
        notes: 'Original note',
      );

      final updated = base.copyWith(
        status: 'MANUAL_EDIT',
        notes: 'Updated note after edit',
      );

      expect(updated.id, 401);
      expect(updated.userId, 'test_user');
      expect(updated.status, 'MANUAL_EDIT');
      expect(updated.notes, 'Updated note after edit');
    });
  });

  group('Employee Model Tests', () {
    test('Employee fromJson and toJson serialization', () {
      final emp = Employee(
        id: 'emp-001',
        userName: 'nv_ngoctruong',
        email: 'truong@hutech.edu.vn',
        role: 'Staff',
        initials: 'NT',
      );

      final json = emp.toJson();
      expect(json['id'], 'emp-001');
      expect(json['userName'], 'nv_ngoctruong');
      expect(json['email'], 'truong@hutech.edu.vn');
      expect(json['role'], 'Staff');
      expect(json['initials'], 'NT');

      final reconstructed = Employee.fromJson(json);
      expect(reconstructed.id, 'emp-001');
      expect(reconstructed.userName, 'nv_ngoctruong');
      expect(reconstructed.email, 'truong@hutech.edu.vn');
      expect(reconstructed.role, 'Staff');
      expect(reconstructed.initials, 'NT');
    });

    test('Employee fromJson handles roles list array from ASP.NET Identity', () {
      final identityJson = {
        'Id': 'admin-002',
        'UserName': 'admin_user',
        'Email': 'admin@test.com',
        'Roles': ['Admin'],
        'Initials': 'AU',
      };

      final emp = Employee.fromJson(identityJson);
      expect(emp.id, 'admin-002');
      expect(emp.userName, 'admin_user');
      expect(emp.role, 'Admin');
    });
  });

  group('AttendanceResult Tests', () {
    test('AttendanceResult conflict detection for 409 Conflict', () {
      final conflictResult = AttendanceResult(
        success: false,
        message: 'Bạn đã thực hiện check-in trong vòng 5 phút trước.',
        statusCode: 409,
      );

      expect(conflictResult.success, false);
      expect(conflictResult.statusCode, 409);
      expect(conflictResult.isConflict, true);
    });

    test('AttendanceResult success on 200 OK', () {
      final successResult = AttendanceResult(
        success: true,
        message: 'Chấm công thành công!',
        statusCode: 200,
      );

      expect(successResult.success, true);
      expect(successResult.statusCode, 200);
      expect(successResult.isConflict, false);
    });
  });
}
