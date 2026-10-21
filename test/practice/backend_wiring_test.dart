import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Nhom_3_nguoi/practice/app.dart';
import 'package:Nhom_3_nguoi/practice/features/notes/notes_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/notes/notes_repository.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/post_api.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/posts_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/products/product_api.dart';
import 'package:Nhom_3_nguoi/practice/features/products/product_provider.dart';
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

  testWidgets(
    'backend preset loads posts and derived products API in the original study shell',
    (tester) async {
      final calls = <Uri>[];
      Future<http.Response> respond(http.Request request) async {
        calls.add(request.url);
        final isProducts = request.url.path.endsWith('/products');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(
              isProducts
                  ? [
                      {
                        'id': 8,
                        'name': 'Sản phẩm máy chủ',
                        'description': 'Từ SQL Server',
                        'price': 12500,
                      },
                    ]
                  : [
                      {
                        'id': 1,
                        'userId': 1,
                        'title': 'Bài từ backend',
                        'body': 'Nội dung',
                      },
                    ],
            ),
          ),
          200,
        );
      }

      final store = PreferencesStore(await SharedPreferences.getInstance());
      final products = ProductProvider(
        api: ProductApi(client: MockClient(respond)),
      );
      final posts = PostsProvider(api: PostApi(client: MockClient(respond)));
      await tester.pumpWidget(
        ExamPrepApp(
          settings: SettingsProvider(store: store),
          favorites: FavoritesProvider(store: store),
          posts: posts,
          notes: notes,
          products: products,
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.where((url) => url.path.endsWith('/products')), isEmpty);
      await tester.tap(find.text('Cài đặt').last);
      await tester.pumpAndSettle();
      final preset = find.text('Backend máy ảo');
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await tester.pumpAndSettle();
      expect(
        calls.any(
          (url) =>
              url.host == '10.0.2.2' &&
              url.port == 5186 &&
              url.path == '/api/products',
        ),
        isTrue,
      );
      expect(
        calls.any((url) => url.toString() == 'http://10.0.2.2:5186/api/posts'),
        isTrue,
      );
      await tester.tap(find.text('Sản phẩm').last);
      await tester.pumpAndSettle();
      expect(find.text('Sản phẩm máy chủ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
