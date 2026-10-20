import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Nhom_3_nguoi/UnitConverterScreen.dart';

void main() {
  testWidgets('UnitConverterScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnitConverterScreen()));
    expect(find.byType(UnitConverterScreen), findsOneWidget);
  });
}
