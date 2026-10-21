import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngoc_truong_2380602415/screens/login_screen.dart';
import 'package:ngoc_truong_2380602415/screens/registration_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'login offers account and email OTP without biometric entry routes',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Chấm công'), findsOneWidget);
      expect(find.text('Tên đăng nhập hoặc email'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
      expect(find.byIcon(Icons.face_rounded), findsNothing);
      expect(find.text('facebook'), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), 'staff1');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Đăng nhập'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
      await tester.pump();
      expect(
        find.text(
          'Vui lòng nhập mã OTP để xác thực đăng nhập',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('public registration asks only for username email and password', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(
      find.text(
        'Tài khoản mặc định: User. Quyền nhân viên do quản trị viên cấp.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'three registration inputs reach email validation without initials',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.enterText(find.byType(TextField).at(0), 'staff1');
      await tester.enterText(find.byType(TextField).at(1), 'invalid-email');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Đăng ký'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
      await tester.pump();
      expect(
        find.text(
          'Định dạng email không hợp lệ (Ví dụ: sinhvien@domain.edu.vn)',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'three registration inputs reject passwords below six characters',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.enterText(find.byType(TextField).at(0), 'staff1');
      await tester.enterText(
        find.byType(TextField).at(1),
        'staff1@example.com',
      );
      await tester.enterText(find.byType(TextField).at(2), '12345');
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Đăng ký'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
      await tester.pump();
      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
    },
  );

  testWidgets('registration requires username email and password', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
    await tester.pump();
    expect(
      find.text('Vui lòng nhập đầy đủ tất cả các trường thông tin'),
      findsOneWidget,
    );
  });

  testWidgets('auth forms scroll on a narrow screen with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.reset);

    for (final screen in <Widget>[
      const LoginScreen(),
      const RegistrationScreen(),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ElevatedButton).first);
      expect(tester.takeException(), isNull);
    }
  });
}
