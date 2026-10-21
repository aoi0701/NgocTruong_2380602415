import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngoc_truong_2380602415/main.dart';

void main() {
  testWidgets('App opens attendance login without legacy navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Chấm công'), findsOneWidget);
    expect(find.text('Gửi OTP'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}
