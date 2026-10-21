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
import 'package:provider/provider.dart';
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

  Future<void> mount(WidgetTester tester, {bool fail = false}) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final store = PreferencesStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      ExamPrepApp(
        settings: SettingsProvider(store: store),
        favorites: FavoritesProvider(store: store),
        posts: PostsProvider(
          api: PostApi(
            client: MockClient(
              (_) async => fail
                  ? http.Response('unavailable', 503)
                  : http.Response.bytes(
                      utf8.encode(
                        jsonEncode([
                          {
                            'id': 1,
                            'userId': 1,
                            'title': 'Học Flutter',
                            'body': 'API và Provider',
                          },
                          {
                            'id': 2,
                            'userId': 1,
                            'title': 'SQLite',
                            'body': 'Lưu ghi chú',
                          },
                        ]),
                      ),
                      200,
                    ),
            ),
          ),
        ),
        notes: notes,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openKeyboard(WidgetTester tester, Finder field) async {
    await tester.tap(field);
    await tester.showKeyboard(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await tester.pumpAndSettle();
  }

  testWidgets('landscape posts search and list scroll above the keyboard', (
    tester,
  ) async {
    await mount(tester);
    final search = find.byType(TextField).first;
    await openKeyboard(tester, search);
    await tester.enterText(search, 'Flutter');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Học Flutter'));
    await tester.pumpAndSettle();
    expect(find.text('Học Flutter').hitTestable(), findsOneWidget);
    expect(find.text('SQLite'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'landscape keyboard still allows error recovery into sample mode',
    (tester) async {
      await mount(tester, fail: true);
      await openKeyboard(tester, find.byType(TextField).first);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Dùng dữ liệu mẫu').hitTestable(),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dùng dữ liệu mẫu'));
      await tester.pumpAndSettle();
      expect(
        tester
            .element(find.byType(CustomScrollView))
            .read<PostsProvider>()
            .isSampleData,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.text('Dữ liệu mẫu • Không phải dữ liệu API').hitTestable(),
        -40,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Dữ liệu mẫu • Không phải dữ liệu API').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('landscape settings keyboard does not lay out hidden pages', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Cài đặt').last);
    await tester.pumpAndSettle();
    final endpoint = find.byType(TextFormField);
    await tester.scrollUntilVisible(
      endpoint.hitTestable(),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(endpoint.hitTestable(), findsOneWidget);
    await openKeyboard(tester, endpoint);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Lưu địa chỉ API'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu địa chỉ API').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs restores search text and matching results', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField).first, 'Flutter');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bài viết').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Flutter',
    );
    expect(find.text('Học Flutter'), findsOneWidget);
    expect(find.text('SQLite'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
