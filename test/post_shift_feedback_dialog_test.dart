import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/widgets/post_shift_feedback_dialog.dart';

void main() {
  testWidgets('Post-shift mood can be selected or skipped without sending', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () =>
                    showPostShiftFeedbackDialog(context: context, recordId: 1),
                child: const Text('Ra ca'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Ra ca'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay bạn cảm thấy thế nào?'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(
      find.text('Vui lòng chọn một cảm nhận trước khi gửi.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mệt'));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mệt'))
          .selected,
      isTrue,
    );
    expect(
      find.text('Vui lòng chọn một cảm nhận trước khi gửi.'),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'Ca hôm nay hơi mệt');
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Ra ca'), findsOneWidget);
  });
}
