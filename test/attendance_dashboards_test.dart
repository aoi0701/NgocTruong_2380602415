import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngoc_truong_2380602415/screens/admin_screen.dart';
import 'package:ngoc_truong_2380602415/screens/main_screen.dart';
import 'package:ngoc_truong_2380602415/screens/staff_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_name': 'attendance-user',
      'user_role': 'User',
    });
  });

  void expectAttendanceOnly() {
    expect(find.textContaining('MarketScreen'), findsNothing);
    expect(find.textContaining('FeedScreen'), findsNothing);
    expect(find.textContaining('sản phẩm'), findsNothing);
    expect(find.textContaining('Sản phẩm'), findsNothing);
    expect(find.textContaining('Tiện ích'), findsNothing);
    expect(find.textContaining('Bảng tin'), findsNothing);
  }

  testWidgets('account landing has attendance methods and logout', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng, attendance-user!'), findsOneWidget);
    expect(find.text('Vai trò: User'), findsOneWidget);
    expect(find.text('Chấm công khuôn mặt'), findsOneWidget);
    expect(find.text('Chấm công bằng mã QR'), findsOneWidget);
    expect(find.text('Chấm công bằng vị trí GPS'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expectAttendanceOnly();

    await tester.tap(find.byTooltip('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn có chắc chắn muốn đăng xuất?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng, attendance-user!'), findsOneWidget);
  });

  testWidgets('staff retains shift controls and all advanced methods', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StaffScreen()));
    await tester.pump();
    expect(find.text('Dashboard Nhân Viên'), findsOneWidget);
    expect(find.text('Vào ca (Check-in)'), findsOneWidget);
    expect(find.text('Ra ca (Check-out)'), findsOneWidget);
    expect(find.text('Lịch sử chấm công SQL Server'), findsOneWidget);
    expect(find.text('Phương thức chấm công'), findsOneWidget);
    expectAttendanceOnly();

    await tester.ensureVisible(find.text('Chọn cách chấm công'));
    await tester.tap(find.text('Chọn cách chấm công'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Chấm công khuôn mặt'), findsOneWidget);
    expect(find.text('1. Quét mã QR chấm công địa điểm'), findsOneWidget);
    expect(find.text('2. Điểm danh định vị GPS thực tế'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'admin has only attendance and employees tabs with matching refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
      await tester.pump();

      expect(find.byType(Tab), findsNWidgets(2));
      expect(find.text('Chấm công Nhân viên'), findsOneWidget);
      expect(find.text('Quản lý Nhân viên'), findsOneWidget);
      expect(find.text('Tải lại chấm công'), findsOneWidget);
      expectAttendanceOnly();

      await tester.tap(find.text('Quản lý Nhân viên'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tải lại DS Nhân viên'), findsOneWidget);
      expect(find.text('Tải lại chấm công'), findsNothing);
      await tester.tap(find.text('Chấm công Nhân viên'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tải lại chấm công'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
