import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/practice/features/notes/notes_provider.dart';
import 'package:ngoc_truong_2380602415/practice/features/notes/notes_repository.dart';
import 'package:ngoc_truong_2380602415/practice/features/notes/notes_screen.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late NotesRepository repository;
  late NotesProvider provider;

  setUp(() async {
    repository = NotesRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    provider = NotesProvider(repository: repository);
    await provider.load();
  });

  tearDown(() async {
    provider.dispose();
    await repository.close();
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: NotesScreen()),
    ),
  );

  testWidgets('form validates, creates, edits, toggles and confirms deletion', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Chưa có ghi chú'), findsOneWidget);
    await tester.tap(find.byTooltip('Thêm ghi chú'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tiêu đề.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('note-title')), 'Ôn SQLite');
    await tester.enterText(
      find.byKey(const Key('note-content')),
      'Nội dung học',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Ôn SQLite'), findsOneWidget);
    expect((await repository.getAll()).single.content, 'Nội dung học');

    await tester.tap(find.text('Ôn SQLite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'Ôn Provider');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Ôn Provider'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect((await repository.getAll()).single.isCompleted, isTrue);

    await tester.tap(find.byTooltip('Xóa ghi chú'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa ghi chú?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(await repository.getAll(), hasLength(1));
    await tester.tap(find.byTooltip('Xóa ghi chú'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(await repository.getAll(), isEmpty);
    expect(find.text('Chưa có ghi chú'), findsOneWidget);
  });

  testWidgets('save error stays visible and keeps the draft for retry', (
    tester,
  ) async {
    await mount(tester);
    final connection = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    await connection.execute('PRAGMA query_only = ON');
    await tester.tap(find.byTooltip('Thêm ghi chú'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'Bản nháp');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không thể lưu thay đổi.'), findsOneWidget);
    expect(find.text('Bản nháp'), findsOneWidget);
    expect(await repository.getAll(), isEmpty);
    await connection.execute('PRAGMA query_only = OFF');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Bản nháp'), findsOneWidget);
    expect(await repository.getAll(), hasLength(1));
  });

  testWidgets('narrow screen and long content allow editing without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await provider.save(
      title: List.filled(30, 'Tiêu đề dài').join(' '),
      content: List.filled(80, 'Dòng dài').join('\n'),
    );
    await mount(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Sửa ghi chú'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
