import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:Nhom_3_nguoi/HomeScreen.dart';
import 'package:Nhom_3_nguoi/main.dart' as app;
import 'package:Nhom_3_nguoi/practice/features/posts/post_api.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/posts_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/products/product_api.dart';
import 'package:Nhom_3_nguoi/practice/features/products/product_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/settings_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/shared/api_endpoint.dart';
import 'package:provider/provider.dart';

// Real Android plugins, HTTP and SQL backend; creates and removes only unique rows.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android UI persists post and product CRUD through SQL backend',
    (tester) async {
      final token = 'android-${DateTime.now().microsecondsSinceEpoch}';
      final postTitle = 'Bài Android $token';
      final editedPostTitle = 'Đã sửa bài $token';
      final productName = 'Sản phẩm $token';
      final editedProductName = 'Đã sửa sản phẩm $token';
      const body = "Truong's bài viết; DROP TABLE posts; -- Tiếng Việt";
      const description =
          "Truong's sản phẩm; DROP TABLE products; -- Tiếng Việt";
      const postsEndpoint = emulatorPostsEndpoint;
      final productsUrl = productsEndpoint(postsEndpoint);
      final postApi = PostApi();
      final productApi = ProductApi();
      SettingsProvider? settings;
      String? originalEndpoint;

      try {
        app.main();
        final entry = find.byKey(const Key('practice-entry'));
        await _wait(tester, () => entry.evaluate().isNotEmpty, 'original home');
        expect(find.byType(HomeScreen), findsOneWidget);
        await tester.ensureVisible(entry);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(entry);
        await _wait(
          tester,
          () => find.byType(NavigationBar).evaluate().isNotEmpty,
          'practice navigation',
        );
        settings = _read<SettingsProvider>(tester);
        originalEndpoint = settings.endpoint;
        final posts = _read<PostsProvider>(tester);
        final products = _read<ProductProvider>(tester);

        await _tab(tester, 'Cài đặt');
        await _tap(tester, find.text('Backend máy ảo'));
        await _wait(
          tester,
          () =>
              settings!.endpoint == postsEndpoint &&
              !posts.isLoading &&
              !products.isLoading,
          'local backend preset and initial HTTP lists',
        );
        expect(posts.error, isNull);
        expect(products.error, isNull);
        expect(posts.canWrite, isTrue);
        expect(products.endpoint, productsUrl);

        await _tab(tester, 'Bài viết');
        await _tap(tester, find.text('Tạo bài viết'));
        await tester.enterText(find.byKey(const Key('post-user-id')), '2');
        await tester.enterText(find.byKey(const Key('post-title')), postTitle);
        await tester.enterText(find.byKey(const Key('post-body')), body);
        await _save(tester, const Key('post-save'));
        await _wait(
          tester,
          () =>
              !posts.isSaving &&
              find.byKey(const Key('post-title')).evaluate().isEmpty,
          'post creation',
        );
        expect(posts.mutationError, isNull);
        final createdPost = posts.posts.singleWhere(
          (post) => post.title == postTitle,
        );
        final persistedPost = await postApi.fetchPost(
          postsEndpoint,
          createdPost.id,
        );
        expect(persistedPost.title, postTitle);
        expect(persistedPost.body, body);

        final postSearch = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Tìm tiêu đề hoặc nội dung',
        );
        await tester.ensureVisible(postSearch);
        await tester.enterText(postSearch, token);
        await _hideKeyboard(tester);
        await _tap(tester, find.text(postTitle));
        await _tap(tester, find.byTooltip('Sửa bài viết'));
        await tester.enterText(
          find.byKey(const Key('post-title')),
          editedPostTitle,
        );
        await _save(tester, const Key('post-save'));
        await _wait(
          tester,
          () =>
              !posts.isSaving &&
              find.byKey(const Key('post-title')).evaluate().isEmpty,
          'post update',
        );
        expect(posts.mutationError, isNull);
        expect(
          (await postApi.fetchPost(postsEndpoint, createdPost.id)).title,
          editedPostTitle,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('post-lookup-id')));
        await tester.enterText(
          find.byKey(const Key('post-lookup-id')),
          '${createdPost.id}',
        );
        await _hideKeyboard(tester);
        await _tap(tester, find.byTooltip('Tìm theo ID'));
        await _wait(
          tester,
          () => find.text('Chi tiết bài viết').evaluate().isNotEmpty,
          'post GET by ID',
        );
        expect(find.text(editedPostTitle), findsOneWidget);
        expect(find.text(body), findsOneWidget);
        await _tap(tester, find.byTooltip('Xóa bài viết'));
        await _tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Xóa'),
          ),
        );
        await _wait(
          tester,
          () =>
              !posts.isSaving &&
              !posts.posts.any((post) => post.id == createdPost.id),
          'post deletion',
        );
        expect(posts.mutationError, isNull);
        await expectLater(
          postApi.fetchPost(postsEndpoint, createdPost.id),
          throwsA(
            isA<PostApiException>().having(
              (error) => error.message,
              'missing post',
              contains('404'),
            ),
          ),
        );

        await _tab(tester, 'Sản phẩm');
        await _tap(tester, find.byKey(const Key('product-add')));
        await tester.enterText(
          find.byKey(const Key('product-name')),
          productName,
        );
        await tester.enterText(
          find.byKey(const Key('product-description')),
          description,
        );
        await tester.enterText(
          find.byKey(const Key('product-price')),
          '12345.5',
        );
        await _save(tester, const Key('product-save'));
        await _wait(
          tester,
          () =>
              !products.isSaving &&
              find.byKey(const Key('product-name')).evaluate().isEmpty,
          'product creation',
        );
        expect(products.mutationError, isNull);
        final createdProduct = products.products.singleWhere(
          (product) => product.name == productName,
        );
        final persistedProduct = await productApi.fetchProduct(
          productsUrl,
          createdProduct.id,
        );
        expect(persistedProduct.name, productName);
        expect(persistedProduct.description, description);
        expect(persistedProduct.price, 12345.5);

        await tester.ensureVisible(find.byKey(const Key('product-search')));
        await tester.enterText(find.byKey(const Key('product-search')), token);
        await _hideKeyboard(tester);
        await _tap(tester, find.byKey(const Key('product-search-submit')));
        await _wait(
          tester,
          () => !products.isLoading,
          'SQL product name search',
        );
        expect(products.error, isNull);
        expect(products.nameQuery, token);
        expect(products.products.map((product) => product.id), [
          createdProduct.id,
        ]);
        expect(
          (await productApi.fetchProducts(productsUrl, name: token)).single.id,
          createdProduct.id,
        );

        await _tap(
          tester,
          find.byKey(Key('product-edit-${createdProduct.id}')),
        );
        await tester.enterText(
          find.byKey(const Key('product-name')),
          editedProductName,
        );
        await tester.enterText(
          find.byKey(const Key('product-price')),
          '9876.25',
        );
        await _save(tester, const Key('product-save'));
        await _wait(
          tester,
          () =>
              !products.isSaving &&
              find.byKey(const Key('product-name')).evaluate().isEmpty,
          'product update',
        );
        expect(products.mutationError, isNull);
        final edited = await productApi.fetchProduct(
          productsUrl,
          createdProduct.id,
        );
        expect(edited.name, editedProductName);
        expect(edited.price, 9876.25);

        await tester.ensureVisible(find.byKey(const Key('product-id')));
        await tester.enterText(
          find.byKey(const Key('product-id')),
          '${createdProduct.id}',
        );
        await _hideKeyboard(tester);
        await _tap(tester, find.byKey(const Key('product-id-submit')));
        await _wait(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
          'product GET by ID',
        );
        expect(
          find.text('Chi tiết sản phẩm #${createdProduct.id}'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining(editedProductName),
          ),
          findsOneWidget,
        );
        await _tap(tester, find.text('Đóng'));
        await _tap(
          tester,
          find.byKey(Key('product-delete-${createdProduct.id}')),
        );
        await _tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Xóa'),
          ),
        );
        await _wait(
          tester,
          () =>
              !products.isSaving &&
              !products.products.any(
                (product) => product.id == createdProduct.id,
              ),
          'product deletion',
        );
        expect(products.mutationError, isNull);
        await expectLater(
          productApi.fetchProduct(productsUrl, createdProduct.id),
          throwsA(
            isA<ProductApiException>().having(
              (error) => error.message,
              'missing product',
              contains('404'),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      } finally {
        // Discover rows by unique token too, so cleanup also works after UI failures.
        try {
          for (final post in await postApi.fetchPosts(postsEndpoint)) {
            if (post.title.contains(token)) {
              await postApi.deletePost(postsEndpoint, post.id);
            }
          }
          for (final product in await productApi.fetchProducts(
            productsUrl,
            name: token,
          )) {
            if (product.name.contains(token)) {
              await productApi.deleteProduct(productsUrl, product.id);
            }
          }
        } finally {
          try {
            if (settings != null && originalEndpoint != null) {
              await settings.setEndpoint(originalEndpoint);
              expect(settings.endpoint, originalEndpoint);
            }
          } finally {
            postApi.close();
            productApi.close();
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

T _read<T>(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar)).read<T>();

Future<void> _wait(
  WidgetTester tester,
  bool Function() condition,
  String task,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Native operation timed out: $task');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Future<void> _tab(WidgetTester tester, String label) async {
  await _tap(
    tester,
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, Key key) async {
  await _hideKeyboard(tester);
  await _tap(tester, find.byKey(key));
}
