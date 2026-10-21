import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/post_api.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/posts_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/favorites_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/preferences_store.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/settings_provider.dart';
import 'package:Nhom_3_nguoi/practice/screens/posts_screen.dart';

void main() {
  Future<void> mount(WidgetTester tester, {bool failSave = false}) async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesStore(await SharedPreferences.getInstance());
    final settings = SettingsProvider(store: store);
    await settings.setEndpoint('http://localhost:5186/api/posts');
    final posts = PostsProvider(
      api: PostApi(
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(
              r.url.path.endsWith('/8')
                  ? '{"id":8,"userId":1,"title":"Lookup result","body":"From GET by ID"}'
                  : '[]',
              200,
            );
          }
          if (failSave) return http.Response('{"title":"Server refused"}', 400);
          if (r.method == 'DELETE') return http.Response('', 204);
          return http.Response(
            jsonEncode({'id': 8, ...jsonDecode(r.body) as Map}),
            r.method == 'POST' ? 201 : 200,
          );
        }),
      ),
    );
    final favorites = FavoritesProvider(store: store);
    addTearDown(posts.dispose);
    addTearDown(settings.dispose);
    addTearDown(favorites.dispose);
    await posts.load(settings.endpoint);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: posts),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: favorites),
        ],
        child: const MaterialApp(home: Scaffold(body: PostsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create edit delete complete through real forms and confirmed HTTP',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Tạo bài viết'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('post-user-id')), '2');
      await tester.enterText(
        find.byKey(const Key('post-title')),
        'Created title',
      );
      await tester.enterText(
        find.byKey(const Key('post-body')),
        'Created body',
      );
      await tester.tap(find.byKey(const Key('post-save')));
      await tester.pumpAndSettle();
      expect(find.text('Created title'), findsOneWidget);
      await tester.tap(find.text('Created title'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sửa bài viết'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('post-title')),
        'Edited title',
      );
      await tester.tap(find.byKey(const Key('post-save')));
      await tester.pumpAndSettle();
      expect(find.text('Edited title'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa bài viết'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Xóa').last);
      await tester.pumpAndSettle();
      expect(find.text('Edited title'), findsNothing);
      expect(find.text('API chưa có bài viết.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('server rejection stays on form and empty inputs cannot save', (
    tester,
  ) async {
    await mount(tester, failSave: true);
    await tester.tap(find.text('Tạo bài viết'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post-save')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tiêu đề (1–200 ký tự).'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('post-user-id')), '1');
    await tester.enterText(find.byKey(const Key('post-title')), 'Failed title');
    await tester.enterText(find.byKey(const Key('post-body')), 'Body');
    await tester.tap(find.byKey(const Key('post-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('400'), findsWidgets);
    expect(find.byKey(const Key('post-title')), findsOneWidget);
  });
  testWidgets('lookup by ID fetches missing feed item at narrow screen width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    await tester.enterText(find.byKey(const Key('post-lookup-id')), '8');
    await tester.tap(find.byTooltip('Tìm theo ID'));
    await tester.pumpAndSettle();
    expect(find.text('Lookup result'), findsOneWidget);
    expect(find.text('From GET by ID'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
