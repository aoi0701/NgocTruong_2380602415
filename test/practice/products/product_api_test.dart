import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Nhom_3_nguoi/practice/features/products/product.dart';
import 'package:Nhom_3_nguoi/practice/features/products/product_api.dart';

const endpoint = 'http://10.0.2.2:5186/api/products';
const fixture = {
  'id': 7,
  'name': 'Bút Việt',
  'description': 'Mực xanh',
  'price': 12.5,
};
http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'connection errors and invalid product inputs are controlled failures',
    () async {
      final api = ProductApi(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchProducts(endpoint),
        throwsA(isA<ProductApiException>()),
      );
      await expectLater(
        api.createProduct(endpoint, name: ' ', description: '', price: 1),
        throwsA(isA<ProductApiException>()),
      );
      await expectLater(
        api.createProduct(
          endpoint,
          name: 'Valid',
          description: '',
          price: double.nan,
        ),
        throwsA(isA<ProductApiException>()),
      );
    },
  );
  test('clearing name search removes existing endpoint name query', () async {
    final api = ProductApi(
      client: MockClient((request) async {
        expect(request.url.queryParameters.containsKey('name'), isFalse);
        return jsonResponse([]);
      }),
    );
    addTearDown(api.close);
    await api.fetchProducts('$endpoint?name=stale', name: '  ');
  });
  test(
    'strict product parser accepts numeric prices, rejects missing and wrong fields',
    () {
      expect(Product.fromJson(fixture).price, 12.5);
      expect(Product.fromJson({...fixture, 'price': 12}).price, 12.0);
      for (final value in [
        {...fixture}..remove('description'),
        {...fixture, 'id': '7'},
        {...fixture, 'price': '12.5'},
        {...fixture, 'price': -1},
        {...fixture, 'price': double.infinity},
      ]) {
        expect(() => Product.fromJson(value), throwsFormatException);
      }
    },
  );

  test(
    'name search is encoded in actual server query preserving other params',
    () async {
      final api = ProductApi(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/products');
          expect(request.url.queryParameters, {
            'tenant': '2',
            'name': "Bút & ' OR 1=1",
          });
          return jsonResponse([fixture]);
        }),
      );
      addTearDown(api.close);
      expect(
        (await api.fetchProducts(
          '$endpoint?tenant=2&name=old',
          name: " Bút & ' OR 1=1 ",
        )).single.name,
        'Bút Việt',
      );
    },
  );

  test(
    'find and CRUD use real IDs verbs numeric payload and empty 204',
    () async {
      var step = 0;
      final api = ProductApi(
        client: MockClient((request) async {
          step++;
          switch (step) {
            case 1:
              expect(request.method, 'GET');
              expect(request.url.path, '/api/products/7');
              return jsonResponse(fixture);
            case 2:
              expect(request.method, 'POST');
              expect(request.url.path, '/api/products');
              expect(jsonDecode(request.body), {
                'name': 'Bút Việt',
                'description': 'Mực xanh',
                'price': 12.5,
              });
              return jsonResponse(fixture, 201);
            case 3:
              expect(request.method, 'PUT');
              expect(request.url.path, '/api/products/7');
              return http.Response('', 204);
            case 4:
              expect(request.method, 'DELETE');
              expect(request.url.path, '/api/products/7');
              return http.Response('', 204);
            default:
              fail('Unexpected extra request');
          }
        }),
      );
      addTearDown(api.close);
      final product = await api.fetchProduct(endpoint, 7);
      expect(
        (await api.createProduct(
          endpoint,
          name: product.name,
          description: product.description,
          price: product.price,
        )).id,
        7,
      );
      expect((await api.updateProduct(endpoint, product)).name, 'Bút Việt');
      await api.deleteProduct(endpoint, 7);
      expect(step, 4);
    },
  );

  for (final status in [400, 404, 500]) {
    test(
      'HTTP $status yields actionable failure and never an invented product',
      () async {
        final api = ProductApi(
          client: MockClient(
            (_) async => jsonResponse({'title': 'Invalid input'}, status),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetchProduct(endpoint, 7),
          throwsA(
            isA<ProductApiException>().having(
              (e) => e.message,
              'message',
              contains('$status'),
            ),
          ),
        );
      },
    );
  }

  test('malformed collection and timeout are controlled errors', () async {
    final malformed = ProductApi(
      client: MockClient(
        (_) async => jsonResponse([
          {'id': 1},
        ]),
      ),
    );
    addTearDown(malformed.close);
    await expectLater(
      malformed.fetchProducts(endpoint),
      throwsA(isA<ProductApiException>()),
    );
    final timed = ProductApi(
      client: MockClient((_) => Completer<http.Response>().future),
      requestTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(timed.close);
    await expectLater(
      timed.fetchProducts(endpoint),
      throwsA(isA<ProductApiException>()),
    );
  });

  test('nonlocal cleartext endpoint is rejected before network', () async {
    final api = ProductApi(
      client: MockClient((_) async => throw StateError('Must not send')),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchProducts('http://example.com/api/products'),
      throwsA(isA<ProductApiException>()),
    );
  });
}
