import 'dart:async';
import 'dart:convert';

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
  tearDown(() async {
    await repository.close();
  });

  Future<void> mount(
    WidgetTester tester,
    Future<http.Response> Function(http.Request request) handler,
  ) async {
    // Preference mutation queues must be created in the widget test's fake
    // async zone, while native SQLite setup above needs the real async zone.
    final store = PreferencesStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      ExamPrepApp(
        settings: SettingsProvider(store: store),
        favorites: FavoritesProvider(store: store),
        posts: PostsProvider(api: PostApi(client: MockClient(handler))),
        notes: notes,
      ),
    );
  }

  final fixture = jsonEncode([
    {
      'id': 1,
      'userId': 2,
      'title': 'Bài viết kiểm tra',
      'body': 'Nội dung chi tiết',
    },
    {
      'id': 2,
      'userId': 2,
      'title': 'Học Provider',
      'body': 'Quản lý trạng thái',
    },
  ]);

  testWidgets('API list opens detail and favorite appears in offline tab', (
    tester,
  ) async {
    await mount(
      tester,
      (_) async => http.Response.bytes(utf8.encode(fixture), 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bài viết kiểm tra'), findsOneWidget);
    await tester.tap(find.text('Bài viết kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung chi tiết'), findsOneWidget);
    await tester.tap(find.byTooltip('Thêm yêu thích'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yêu thích').last);
    await tester.pumpAndSettle();
    expect(find.text('Bài viết kiểm tra'), findsOneWidget);
    expect(find.text('Học Provider'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network error stays explicit until sample mode is requested', (
    tester,
  ) async {
    await mount(tester, (_) async => http.Response('unavailable', 503));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Dữ liệu mẫu • Không phải dữ liệu API'), findsNothing);
    await tester.tap(find.text('Dùng dữ liệu mẫu'));
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu mẫu • Không phải dữ liệu API'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search filters real posts and empty results have an explanation',
    (tester) async {
      await mount(
        tester,
        (_) async => http.Response.bytes(utf8.encode(fixture), 200),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'không tồn tại');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy bài viết phù hợp.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'provider');
      await tester.pumpAndSettle();
      expect(find.text('Học Provider'), findsOneWidget);
      expect(find.text('Bài viết kiểm tra'), findsNothing);
    },
  );

  testWidgets('320px navigation and settings remain usable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(
      tester,
      (_) async => http.Response.bytes(utf8.encode(fixture), 200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt').last);
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SwitchListTile));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-flight API response is harmless after app is disposed', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await mount(tester, (_) => response.future);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response.bytes(utf8.encode(fixture), 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
