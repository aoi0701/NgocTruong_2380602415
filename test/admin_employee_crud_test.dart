import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngoc_truong_2380602415/models/attendance.dart';
import 'package:ngoc_truong_2380602415/screens/admin_screen.dart';
import 'package:ngoc_truong_2380602415/services/attendance_service.dart';

class MockAttendanceService extends AttendanceService {
  List<Employee> mockEmployees;
  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;
  AttendanceResult? mockResult;

  MockAttendanceService({List<Employee>? initialEmployees})
    : mockEmployees =
          initialEmployees ??
          [
            Employee(
              id: 'emp-101',
              userName: 'van_a',
              email: 'vana@example.com',
              role: 'Staff',
            ),
            Employee(
              id: 'emp-102',
              userName: 'thi_b',
              email: 'thib@example.com',
              role: 'User',
            ),
          ];

  @override
  Future<List<Employee>> getEmployees() async {
    return List.from(mockEmployees);
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendances() async {
    return [];
  }

  @override
  Future<AttendanceResult> createEmployee({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    createCalled = true;
    if (mockResult != null) return mockResult!;
    final newEmp = Employee(
      id: 'emp-${DateTime.now().millisecondsSinceEpoch}',
      userName: username,
      email: email,
      role: role,
    );
    mockEmployees.add(newEmp);
    return AttendanceResult(
      success: true,
      message: 'Tạo tài khoản nhân viên thành công!',
    );
  }

  @override
  Future<AttendanceResult> updateEmployee({
    required String employeeId,
    required String username,
    required String email,
    required String role,
  }) async {
    updateCalled = true;
    if (mockResult != null) return mockResult!;
    final index = mockEmployees.indexWhere((e) => e.id == employeeId);
    if (index != -1) {
      mockEmployees[index] = Employee(
        id: employeeId,
        userName: username,
        email: email,
        role: role,
      );
    }
    return AttendanceResult(
      success: true,
      message: 'Cập nhật tài khoản nhân viên thành công!',
    );
  }

  @override
  Future<AttendanceResult> deleteEmployee(String employeeId) async {
    deleteCalled = true;
    if (mockResult != null) return mockResult!;
    mockEmployees.removeWhere((e) => e.id == employeeId);
    return AttendanceResult(
      success: true,
      message: 'Đã xóa tài khoản nhân viên thành công!',
    );
  }
}

void main() {
  late MockAttendanceService mockService;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'fake_admin_jwt',
      'user_role': 'Admin',
      'user_name': 'admin_test',
    });
    mockService = MockAttendanceService();
    AttendanceService.instance = mockService;
  });

  tearDown(() {
    AttendanceService.instance = AttendanceService();
  });

  Future<void> openEmployeeTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();

    // Chuyển sang Tab 2: Quản lý Nhân viên
    await tester.tap(find.text('Quản lý Nhân viên'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Admin screen displays prominent Create Account button and employee cards',
    (tester) async {
      await openEmployeeTab(tester);

      // Nút "Tạo tài khoản" hiển thị nổi bật
      final createBtn = find.byKey(const Key('createEmployeeButton'));
      expect(createBtn, findsOneWidget);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);

      // Thẻ nhân viên hiển thị thông tin và các nút thao tác
      expect(find.text('van_a'), findsOneWidget);
      expect(find.text('Email: vana@example.com'), findsOneWidget);
      expect(find.text('thi_b'), findsOneWidget);

      // Các nút thao tác trên thẻ nhân viên
      expect(find.text('Đổi vai trò'), findsNWidgets(2));
      expect(find.text('Sửa'), findsNWidgets(2));
      expect(find.text('Xóa'), findsNWidgets(2));
    },
  );

  testWidgets(
    'Create account dialog opens, validates required fields and can be canceled',
    (tester) async {
      await openEmployeeTab(tester);

      // Mở hộp thoại tạo tài khoản
      await tester.tap(find.byKey(const Key('createEmployeeButton')));
      await tester.pumpAndSettle();

      expect(find.text('Tạo tài khoản mới'), findsOneWidget);
      expect(find.byKey(const Key('createUsernameField')), findsOneWidget);
      expect(find.byKey(const Key('createEmailField')), findsOneWidget);
      expect(find.byKey(const Key('createPasswordField')), findsOneWidget);
      expect(find.byKey(const Key('createRoleDropdown')), findsOneWidget);

      // Bấm Tạo khi chưa nhập dữ liệu -> kích hoạt validation
      await tester.tap(find.byKey(const Key('submitCreateEmployeeButton')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên đăng nhập'), findsOneWidget);
      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);

      // Bấm Hủy -> đóng dialog
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(find.text('Tạo tài khoản mới'), findsNothing);
    },
  );

  testWidgets(
    'Create account submits valid data, shows SnackBar and refreshes employee list',
    (tester) async {
      await openEmployeeTab(tester);

      await tester.tap(find.byKey(const Key('createEmployeeButton')));
      await tester.pumpAndSettle();

      // Điền thông tin hợp lệ
      await tester.enterText(
        find.byKey(const Key('createUsernameField')),
        'nguyen_van_c',
      );
      await tester.enterText(
        find.byKey(const Key('createEmailField')),
        'vanc@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('createPasswordField')),
        'password123',
      );
      await tester.pumpAndSettle();

      // Bấm nút Tạo tài khoản
      await tester.tap(find.byKey(const Key('submitCreateEmployeeButton')));
      await tester.pumpAndSettle();

      // Kiểm tra API được gọi và SnackBar hiển thị
      expect(mockService.createCalled, isTrue);
      expect(find.text('Tạo tài khoản nhân viên thành công!'), findsOneWidget);

      // Nhân viên mới xuất hiện trong danh sách
      expect(find.text('nguyen_van_c'), findsOneWidget);
    },
  );

  testWidgets(
    'Edit account dialog pre-fills data without password, submits update',
    (tester) async {
      await openEmployeeTab(tester);

      // Bấm Sửa trên thẻ của van_a (emp-101)
      final editBtn = find.byKey(const Key('editEmployeeButton_emp-101'));
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Kiểm tra hiển thị dialog sửa
      expect(find.text('Sửa tài khoản: van_a'), findsOneWidget);
      expect(find.byKey(const Key('editUsernameField')), findsOneWidget);
      expect(find.byKey(const Key('editEmailField')), findsOneWidget);
      // Không có trường mật khẩu trong dialog sửa
      expect(find.byKey(const Key('createPasswordField')), findsNothing);

      // Sửa email
      await tester.enterText(
        find.byKey(const Key('editEmailField')),
        'vana_updated@example.com',
      );
      await tester.pumpAndSettle();

      // Lưu thay đổi
      await tester.tap(find.byKey(const Key('submitUpdateEmployeeButton')));
      await tester.pumpAndSettle();

      expect(mockService.updateCalled, isTrue);
      expect(find.text('Cập nhật tài khoản nhân viên thành công!'), findsOneWidget);
      expect(find.text('Email: vana_updated@example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'Delete account dialog shows confirmation and executes deletion',
    (tester) async {
      await openEmployeeTab(tester);

      // Bấm Xóa trên thẻ của thi_b (emp-102)
      final deleteBtn = find.byKey(const Key('deleteEmployeeButton_emp-102'));
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Kiểm tra dialog xác nhận
      expect(find.text('Xác nhận xóa tài khoản'), findsOneWidget);
      expect(
        find.text('Bạn có chắc chắn muốn xóa tài khoản thi_b không?'),
        findsOneWidget,
      );

      // Bấm Xóa xác nhận
      await tester.tap(find.byKey(const Key('confirmDeleteEmployeeButton')));
      await tester.pumpAndSettle();

      expect(mockService.deleteCalled, isTrue);
      expect(find.text('Đã xóa tài khoản nhân viên thành công!'), findsOneWidget);

      // thi_b đã bị xóa khỏi danh sách
      expect(find.text('thi_b'), findsNothing);
    },
  );

  testWidgets(
    'API error alert is shown when delete fails with reason (e.g. attendance records exist)',
    (tester) async {
      mockService.mockResult = AttendanceResult(
        success: false,
        message:
            'Không thể xóa nhân viên vì đã có lịch sử chấm công liên kết.',
        statusCode: 400,
      );

      await openEmployeeTab(tester);

      final deleteBtn = find.byKey(const Key('deleteEmployeeButton_emp-101'));
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmDeleteEmployeeButton')));
      await tester.pumpAndSettle();

      // Dialog thông báo lỗi từ API
      expect(find.text('Xóa tài khoản thất bại'), findsOneWidget);
      expect(
        find.text(
          'Không thể xóa nhân viên vì đã có lịch sử chấm công liên kết.',
        ),
        findsOneWidget,
      );

      // Bấm Đóng
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa tài khoản thất bại'), findsNothing);
    },
  );
}
