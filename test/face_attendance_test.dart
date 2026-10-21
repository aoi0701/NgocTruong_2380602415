import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngoc_truong_2380602415/screens/face_auth_screen.dart';

const _validToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjI1MzQwMjMwMDc5OSwibmFtZSI6InRlc3Rfc3RhZmYiLCJyb2xlIjoiU3RhZmYifQ.signature';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('face attendance requires an existing authenticated session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FaceAuthScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('Vui lòng đăng nhập trước khi chấm công.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Check-in · Vào ca'), findsNothing);
  });

  testWidgets('signed in employee uses face for attendance rather than login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': _validToken,
      'user_name': 'test_staff',
      'user_role': 'Staff',
    });
    await tester.pumpWidget(const MaterialApp(home: FaceAuthScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Chấm công khuôn mặt'), findsOneWidget);
    expect(find.text('Tài khoản: test_staff'), findsOneWidget);
    expect(find.text('Check-in · Vào ca'), findsOneWidget);
    expect(find.text('Check-out · Ra ca'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Đăng nhập bằng khuôn mặt'), findsNothing);
    expect(find.textContaining('OTP'), findsNothing);
  });
}
