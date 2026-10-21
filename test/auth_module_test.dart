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

    test('ApiClient correctly constructs baseUrl and face endpoints', () {
      final client = ApiClient();
      expect(client.baseUrl, equals(Config_URL.baseUrl));
    });

    test('Auth methods work with mock SharedPreferences and logout clears all', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', 'sample.jwt.token');
      await prefs.setString('user_role', 'Staff');
      await prefs.setString('user_name', 'staff1');

      expect(await Auth.getToken(), equals('sample.jwt.token'));
      expect(await Auth.getRole(), equals('Staff'));
      expect(await Auth.getUsername(), equals('staff1'));

      await Auth.logout();
      expect(await Auth.getToken(), isNull);
      expect(await Auth.getRole(), isNull);
      expect(await Auth.getUsername(), isNull);
      expect(await Auth.isLoggedIn(), isFalse);
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

    testWidgets('RegistrationScreen renders registration fields and default User role', (tester) async {
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

    testWidgets('RegistrationScreen defaults to User role and displays internal admin note without allowing Staff/Admin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );
      await tester.pump();

      // Form công khai hiển thị vai trò User mặc định
      expect(find.text('Khách hàng / Sinh viên (User)'), findsOneWidget);
      // Hiển thị ghi chú: "Tài khoản nhân viên được cấp quyền quản trị nội bộ"
      expect(find.text('Tài khoản nhân viên được cấp quyền quản trị nội bộ'), findsOneWidget);
      // Không có Dropdown để tự chọn vai trò Admin hay Staff
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Quản trị viên hệ thống (Admin)'), findsNothing);
    });

    testWidgets('LoginScreen blocks login when OTP is missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pump();

      // Nhập username và mật khẩu nhưng bỏ trống OTP
      await tester.enterText(find.byType(TextField).at(0), 'testuser');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      // Bấm nút Đăng nhập
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();

      // Bắt buộc phải có mã OTP gửi về email mới cho phép đăng nhập
      expect(find.text('Vui lòng nhập mã OTP được gửi về email để xác thực đăng nhập'), findsOneWidget);
    });

    test('FaceLivenessChecker evaluates head angles, smiles, and blink sequences accurately', () {
      // 1. Kiểm tra góc mặt trực diện trong khoảng [-15°, +15°]
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: 5.0, roll: -10.0, pitch: 8.0), isTrue);
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: 16.5, roll: 0.0, pitch: 0.0), isFalse);
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: 0.0, roll: -18.0, pitch: 0.0), isFalse);
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: 0.0, roll: 0.0, pitch: 22.0), isFalse);

      // 2. Kiểm tra nụ cười đạt chuẩn Liveness >= 0.7
      expect(FaceLivenessChecker.isSmiling(0.85), isTrue);
      expect(FaceLivenessChecker.isSmiling(0.70), isTrue);
      expect(FaceLivenessChecker.isSmiling(0.65), isFalse);
      expect(FaceLivenessChecker.isSmiling(null), isFalse);

      // 3. Kiểm tra chuỗi chớp mắt thật: Mở > 0.7 -> Nhắm < 0.25 -> Mở > 0.7
      expect(FaceLivenessChecker.verifyBlinkSequence([0.85, 0.12, 0.88]), isTrue);
      expect(FaceLivenessChecker.verifyBlinkSequence([0.75, 0.50, 0.80]), isFalse); // Không nhắm đủ sâu (< 0.25)
      expect(FaceLivenessChecker.verifyBlinkSequence([0.10, 0.85]), isFalse); // Thiếu pha mở đầu
    });

    testWidgets('FaceAuthScreen enforces anti-spoofing camera-only without gallery option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FaceAuthScreen(),
        ),
      );
      await tester.pump();

      // Xác minh nhãn chống giả mạo chỉ dùng camera trực tiếp
      expect(find.textContaining('Chống giả mạo: Chặn ảnh từ thư viện'), findsOneWidget);
      expect(find.text('Chụp Camera quét khuôn mặt xác thực'), findsOneWidget);
      // Xác minh tuyệt đối không có nút chọn ảnh từ thư viện
      expect(find.textContaining('Chọn ảnh từ bộ nhớ'), findsNothing);
      expect(find.byIcon(Icons.photo_library_rounded), findsNothing);
    });

    testWidgets('FaceAuthScreen locks enrollment when user is not logged in and restricts arbitrary username overwrite', (tester) async {
      // Khi người dùng CHƯA ĐĂNG NHẬP
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: FaceAuthScreen(initialEnrollmentMode: true),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tab Đăng ký mẫu hiển thị cảnh báo yêu cầu đăng nhập
      expect(find.text('Yêu cầu đăng nhập tài khoản'), findsOneWidget);
      expect(find.textContaining('Bạn không thể tự ý nhập tên bất kỳ để ghi đè mẫu'), findsOneWidget);
      expect(find.text('Đi đến Đăng nhập'), findsOneWidget);
      // Nút chụp camera đăng ký mẫu bị khoá/không hiển thị cho người chưa đăng nhập
      expect(find.text('Chụp Camera đăng ký mẫu khuôn mặt'), findsNothing);
    });

    testWidgets('FaceAuthScreen allows enrollment and displays authenticated username when user is logged in', (tester) async {
      // Giả lập người dùng ĐÃ ĐĂNG NHẬP với JWT hợp lệ chưa hết hạn
      const validJwtToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjI1MzQwMjMwMDc5OSwibmFtZSI6Im5nb2N0cnVvbmciLCJyb2xlIjoiU3RhZmYifQ.signature';
      SharedPreferences.setMockInitialValues({
        'jwt_token': validJwtToken,
        'user_name': 'ngoctruong',
        'user_role': 'Staff',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FaceAuthScreen(initialEnrollmentMode: true),
        ),
      );
      await tester.pumpAndSettle();

      // Hiển thị tài khoản đã đăng nhập được khoá bảo mật
      expect(find.text('Tài khoản đăng ký: ngoctruong'), findsOneWidget);
      expect(find.text('Đã xác thực'), findsOneWidget);
      expect(find.text('Chụp Camera đăng ký mẫu khuôn mặt'), findsOneWidget);
    });

    testWidgets('FaceAuthScreen authentication tab provides username input for face matching', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FaceAuthScreen(initialEnrollmentMode: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tab xác thực có trường nhập username để tải mẫu từ máy chủ
      expect(find.text('Tên người dùng (Username) hoặc Email'), findsOneWidget);
      expect(find.text('Chụp Camera quét khuôn mặt xác thực'), findsOneWidget);
    });

    test('Auth enrollFace and getFaceProfile return structured map with statusCode', () async {
      final enrollResult = await Auth.enrollFace(
        username: 'nonexistent_test_user',
        features: {'boxAspect': 1.0, 'eyeDistRatio': 0.35},
      );
      expect(enrollResult, isA<Map<String, dynamic>>());
      expect(enrollResult.containsKey('success'), isTrue);
      expect(enrollResult.containsKey('statusCode'), isTrue);

      final profileResult = await Auth.getFaceProfile('nonexistent_test_user');
      expect(profileResult, isA<Map<String, dynamic>>());
      expect(profileResult.containsKey('success'), isTrue);
      expect(profileResult.containsKey('statusCode'), isTrue);
    });

    test('FaceLivenessChecker strict boundary condition tests', () {
      // Exactly 15.0 degrees is allowed, 15.1 is rejected
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: 15.0, roll: 0.0, pitch: 0.0), isTrue);
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: 15.01, roll: 0.0, pitch: 0.0), isFalse);
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: -15.0, roll: 0.0, pitch: 0.0), isTrue);
      expect(FaceLivenessChecker.isHeadAngleDirect(yaw: -15.01, roll: 0.0, pitch: 0.0), isFalse);

      // Blink sequence: open > 0.7 -> closed < 0.25 -> open > 0.7
      expect(FaceLivenessChecker.verifyBlinkSequence([0.71, 0.24, 0.71]), isTrue);
      expect(FaceLivenessChecker.verifyBlinkSequence([0.70, 0.24, 0.71]), isFalse); // 0.70 is not > 0.7
      expect(FaceLivenessChecker.verifyBlinkSequence([0.71, 0.25, 0.71]), isFalse); // 0.25 is not < 0.25
    });
  });
}
