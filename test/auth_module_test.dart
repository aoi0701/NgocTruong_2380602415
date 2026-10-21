import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Nhom_3_nguoi/config/config_url.dart';
import 'package:Nhom_3_nguoi/services/api_client.dart';
import 'package:Nhom_3_nguoi/utils/auth.dart';
import 'package:Nhom_3_nguoi/screens/login_screen.dart';
import 'package:Nhom_3_nguoi/screens/registration_screen.dart';
import 'package:Nhom_3_nguoi/screens/admin_screen.dart';
import 'package:Nhom_3_nguoi/screens/staff_screen.dart';
import 'package:Nhom_3_nguoi/screens/main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Auth Module Tests - Tuan 7', () {
    test('Config_URL returns fallback url if .env not loaded', () {
      expect(Config_URL.baseUrl, isNotEmpty);
      expect(Config_URL.baseUrl, contains('/api/'));
    });

    test('ApiClient correctly constructs baseUrl', () {
      final client = ApiClient();
      expect(client.baseUrl, equals(Config_URL.baseUrl));
    });

    test('Auth methods work with mock SharedPreferences', () async {
      expect(await Auth.isLoggedIn(), isFalse);
      expect(await Auth.getToken(), isNull);
      expect(await Auth.getRole(), isNull);

      await Auth.logout();
      expect(await Auth.getToken(), isNull);
    });

    testWidgets('LoginScreen renders Facebook branding, form, and OTP verification', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('facebook'), findsOneWidget);
      expect(find.text('Số điện thoại hoặc email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Gửi OTP'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Đăng ký ngay'), findsOneWidget);
    });

    testWidgets('RegistrationScreen renders registration fields and 3 roles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Tạo tài khoản mới'), findsOneWidget);
      expect(find.text('Tên người dùng (Username)'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Ký tự viết tắt (VD: NT)'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
    });

    testWidgets('AdminScreen renders Admin Dashboard and category management header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('Quản lý Danh mục sản phẩm (CRUD)'), findsOneWidget);
    });

    testWidgets('StaffScreen renders Staff Dashboard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StaffScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Dashboard Nhân Viên'), findsOneWidget);
      expect(find.text('Khu vực tác nghiệp nhân viên'), findsOneWidget);
    });

    testWidgets('MainScreen renders User Welcome and feature cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Hutech Social Hub'), findsOneWidget);
      expect(find.text('Chức năng chính'), findsOneWidget);
      expect(find.text('Chợ sản phẩm (MarketScreen)'), findsOneWidget);
      expect(find.text('Bảng tin bài đăng (FeedScreen)'), findsOneWidget);
    });
  });
}
