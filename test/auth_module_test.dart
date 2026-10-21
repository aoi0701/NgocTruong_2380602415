import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngoc_truong_2380602415/config/config_url.dart';
import 'package:ngoc_truong_2380602415/services/api_client.dart';
import 'package:ngoc_truong_2380602415/utils/auth.dart';
import 'package:ngoc_truong_2380602415/screens/login_screen.dart';
import 'package:ngoc_truong_2380602415/screens/registration_screen.dart';
import 'package:ngoc_truong_2380602415/screens/admin_screen.dart';
import 'package:ngoc_truong_2380602415/screens/staff_screen.dart';
import 'package:ngoc_truong_2380602415/screens/main_screen.dart';
import 'package:ngoc_truong_2380602415/screens/face_auth_screen.dart';

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

    testWidgets('RegistrationScreen has only User and Staff roles in dropdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );
      await tester.pump();

      // Find dropdown and tap to open
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Check User and Staff exist, Admin does NOT exist
      expect(find.text('Khách hàng / Sinh viên (User)'), findsWidgets);
      expect(find.text('Nhân viên vận hành (Staff)'), findsWidgets);
      expect(find.text('Quản trị viên hệ thống (Admin)'), findsNothing);
    });

    testWidgets('LoginScreen blocks login when OTP is missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump();

      // Enter username and password without OTP
      await tester.enterText(find.byType(TextField).at(0), 'testuser');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      // Tap Đăng nhập button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();

      // SnackBar should alert that OTP is required
      expect(find.text('Vui lòng nhập mã OTP được gửi về email để xác thực đăng nhập'), findsOneWidget);
    });

    testWidgets('FaceAuthScreen enforces anti-spoofing camera-only without gallery option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FaceAuthScreen(),
        ),
      );
      await tester.pump();

      // Verify anti-spoofing badge and camera action
      expect(find.textContaining('Chống giả mạo: Chặn ảnh từ thư viện'), findsOneWidget);
      expect(find.text('Chụp Camera quét khuôn mặt xác thực'), findsOneWidget);
      // Ensure no gallery button exists
      expect(find.textContaining('Chọn ảnh từ bộ nhớ'), findsNothing);
      expect(find.byIcon(Icons.photo_library_rounded), findsNothing);
    });
  });
}
