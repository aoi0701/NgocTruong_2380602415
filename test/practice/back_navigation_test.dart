import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Nhom_3_nguoi/practice/app.dart';
import 'package:Nhom_3_nguoi/practice/features/notes/notes_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/notes/notes_repository.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/post_api.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/posts_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/favorites_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/preferences_store.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late NotesRepository repository;
  late NotesProvider notes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = NotesRepository(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    notes = NotesProvider(repository: repository);
    await notes.load();
  });
  tearDown(() async => repository.close());

  Future<void> mount(WidgetTester tester, {VoidCallback? onExit}) async {
    final outer = GlobalKey<NavigatorState>();
    final store = PreferencesStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: outer,
        home: const Scaffold(body: Text('Host application')),
      ),
    );
    unawaited(
      outer.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => ExamPrepApp(
            settings: SettingsProvider(store: store),
            favorites: FavoritesProvider(store: store),
            posts: PostsProvider(
              api: PostApi(
                client: MockClient(
                  (_) async => http.Response(
                    '[{"id":1,"userId":1,"title":"Practice post","body":"Post body"}]',
                    200,
                  ),
                ),
              ),
            ),
            notes: notes,
            onExit: () {
              onExit?.call();
              outer.currentState!.pop();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('system Back closes inner detail before exiting to host', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Practice post'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết bài viết'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ExamPrepApp), findsOneWidget);
    expect(find.text('Chi tiết bài viết'), findsNothing);
    expect(find.text('Practice post'), findsOneWidget);
    expect(find.text('Host application'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Host application'), findsOneWidget);
    expect(find.byType(ExamPrepApp), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back closes note editor and dialog inside practice', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Ghi chú').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thêm ghi chú'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-title')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-title')), findsNothing);
    expect(find.text('Ghi chú SQLite'), findsOneWidget);
    expect(find.byType(ExamPrepApp), findsOneWidget);

    await tester.tap(find.text('Bài viết').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hướng dẫn nhanh'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ExamPrepApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inner PopScope denying Back cannot exit the outer app', (
    tester,
  ) async {
    var exits = 0;
    await mount(tester, onExit: () => exits++);
    final canLeave = ValueNotifier(false);
    addTearDown(canLeave.dispose);
    final inner = Navigator.of(tester.element(find.text('Practice post')));
    unawaited(
      inner.push<void>(
        MaterialPageRoute(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: canLeave,
            builder: (_, allowed, _) => PopScope<void>(
              canPop: allowed,
              child: const Scaffold(body: Text('Saving note')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Saving note'), findsOneWidget);
    expect(find.byType(ExamPrepApp), findsOneWidget);
    expect(exits, 0);

    canLeave.value = true;
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Saving note'), findsNothing);
    expect(find.text('Practice post'), findsOneWidget);
    expect(exits, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concurrent root Back requests exit the practice route once', (
    tester,
  ) async {
    var exits = 0;
    await mount(tester, onExit: () => exits++);
    await Future.wait([
      tester.binding.handlePopRoute(),
      tester.binding.handlePopRoute(),
    ]);
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(find.text('Host application'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
