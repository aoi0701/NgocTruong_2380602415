import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ngoc_truong_2380602415/practice/features/products/product_api.dart';
import 'package:ngoc_truong_2380602415/practice/features/products/product_provider.dart';
import 'package:ngoc_truong_2380602415/practice/features/products/product_screen.dart';

import 'product_api_test.dart' show endpoint, fixture, jsonResponse;

Widget app(ProductProvider provider) => ChangeNotifierProvider.value(
  value: provider,
  child: const MaterialApp(home: Scaffold(body: ProductScreen())),
);

void main() {
  testWidgets(
    'failed create keeps user input and disables duplicate save until response',
    (tester) async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final provider = ProductProvider(
        api: ProductApi(
          client: MockClient((request) async {
            if (request.method == 'GET') return jsonResponse([]);
            if (request.method == 'POST') {
              writes++;
              return pending.future;
            }
            fail('Unexpected HTTP request');
          }),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load(endpoint);
      await tester.pumpWidget(app(provider));
      await tester.tap(find.byKey(const Key('product-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('product-name')), 'Giữ lại');
      await tester.enterText(find.byKey(const Key('product-price')), '15');
      await tester.tap(find.byKey(const Key('product-save')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('product-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('product-save')));
      await tester.pump();
      expect(writes, 1);
      pending.complete(http.Response('', 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 400'), findsOneWidget);
      expect(find.text('Giữ lại'), findsOneWidget);
      expect(provider.products, isEmpty);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('product-save')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'unconfigured products explain backend selection without network',
    (tester) async {
      final provider = ProductProvider(
        api: ProductApi(
          client: MockClient((_) async => throw StateError('Must not fetch')),
        ),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(app(provider));
      expect(find.textContaining('Cài đặt'), findsOneWidget);
      expect(find.byKey(const Key('product-add')), findsNothing);
    },
  );

  testWidgets(
    'narrow screen server search, ID lookup, create edit and delete use HTTP',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rows = <Map<String, Object>>[
        {...fixture},
      ];
      final requestedNames = <String?>[];
      final provider = ProductProvider(
        api: ProductApi(
          client: MockClient((r) async {
            if (r.method == 'GET' && r.url.path == '/api/products/7') {
              return jsonResponse(fixture);
            }
            if (r.method == 'GET' && r.url.path == '/api/products') {
              requestedNames.add(r.url.queryParameters['name']);
              return jsonResponse(rows);
            }
            if (r.method == 'POST') {
              final data = jsonDecode(r.body) as Map<String, dynamic>;
              expect(data['price'], 20);
              final created = <String, Object>{
                'id': 8,
                ...data.cast<String, Object>(),
              };
              rows.add(created);
              return jsonResponse(created, 201);
            }
            if (r.method == 'PUT' && r.url.path == '/api/products/8') {
              final data = jsonDecode(r.body) as Map<String, dynamic>;
              return jsonResponse({'id': 8, ...data});
            }
            if (r.method == 'DELETE' && r.url.path == '/api/products/8') {
              return http.Response('', 204);
            }
            fail('Unexpected HTTP ${r.method} ${r.url}');
          }),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load(endpoint);
      await tester.pumpWidget(app(provider));
      await tester.enterText(find.byKey(const Key('product-search')), 'Bút');
      await tester.tap(find.byKey(const Key('product-search-submit')));
      await tester.pumpAndSettle();
      expect(requestedNames, [null, 'Bút']);
      await tester.enterText(find.byKey(const Key('product-id')), '7');
      await tester.tap(find.byKey(const Key('product-id-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết sản phẩm #7'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('product-search')), '');
      await tester.tap(find.byKey(const Key('product-search-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('product-name')), 'Bút mới');
      await tester.enterText(find.byKey(const Key('product-price')), '20');
      await tester.tap(find.byKey(const Key('product-save')));
      await tester.pumpAndSettle();
      expect(find.text('Bút mới'), findsOneWidget);
      await tester.tap(find.byKey(const Key('product-edit-8')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('product-name')), 'Bút sửa');
      await tester.tap(find.byKey(const Key('product-save')));
      await tester.pumpAndSettle();
      expect(find.text('Bút sửa'), findsOneWidget);
      await tester.tap(find.byKey(const Key('product-delete-8')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa').last);
      await tester.pumpAndSettle();
      expect(find.text('Bút sửa'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('load failure offers retry and empty result is explicit', (
    tester,
  ) async {
    var failRequest = true;
    final provider = ProductProvider(
      api: ProductApi(
        client: MockClient(
          (_) async => failRequest ? http.Response('', 500) : jsonResponse([]),
        ),
      ),
    );
    addTearDown(provider.dispose);
    await provider.load(endpoint);
    await tester.pumpWidget(app(provider));
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    failRequest = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Không có sản phẩm phù hợp.'), findsOneWidget);
  });
}
