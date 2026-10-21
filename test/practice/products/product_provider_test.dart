import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ngoc_truong_2380602415/practice/features/products/product.dart';
import 'package:ngoc_truong_2380602415/practice/features/products/product_api.dart';
import 'package:ngoc_truong_2380602415/practice/features/products/product_provider.dart';

import 'product_api_test.dart' show endpoint, fixture, jsonResponse;

void main() {
  test('late successful search cannot overwrite newer server result', () async {
    final pending = Completer<http.Response>();
    final provider = ProductProvider(
      api: ProductApi(
        client: MockClient((request) async {
          if (request.url.queryParameters['name'] == 'old') {
            return pending.future;
          }
          return jsonResponse([
            {...fixture, 'name': 'Newest'},
          ]);
        }),
      ),
    );
    addTearDown(provider.dispose);
    final older = provider.load(endpoint, name: 'old');
    await provider.load(endpoint, name: 'new');
    pending.complete(
      jsonResponse([
        {...fixture, 'name': 'Stale'},
      ]),
    );
    await older;
    expect(provider.products.single.name, 'Newest');
  });
  test(
    'latest server name search wins over older success and failure',
    () async {
      final requests = <String, Completer<http.Response>>{};
      final provider = ProductProvider(
        api: ProductApi(
          client: MockClient((r) {
            return (requests[r.url.queryParameters['name']!] =
                    Completer<http.Response>())
                .future;
          }),
        ),
      );
      addTearDown(provider.dispose);
      final old = provider.load(endpoint, name: 'old');
      final newest = provider.load(endpoint, name: 'new');
      await Future<void>.delayed(Duration.zero);
      requests['new']!.complete(
        jsonResponse([
          {...fixture, 'name': 'New server match'},
        ]),
      );
      await newest;
      requests['old']!.complete(http.Response('error', 500));
      await old;
      expect(provider.products.single.name, 'New server match');
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
    },
  );

  test(
    'CRUD only updates list after confirmed server results and preserves failure',
    () async {
      var rejectDelete = true;
      final provider = ProductProvider(
        api: ProductApi(
          client: MockClient((r) async {
            if (r.method == 'GET') return jsonResponse([fixture]);
            if (r.method == 'POST') {
              return jsonResponse({
                ...fixture,
                'id': 8,
                'name': 'Created',
              }, 201);
            }
            if (r.method == 'PUT') {
              return jsonResponse({...fixture, 'name': 'Updated'});
            }
            if (r.method == 'DELETE') {
              return http.Response('', rejectDelete ? 500 : 204);
            }
            fail('Unexpected request');
          }),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load(endpoint);
      expect(
        await provider.create(name: 'Created', description: '', price: 1),
        isTrue,
      );
      expect(provider.products.map((p) => p.id), [7, 8]);
      expect(
        await provider.update(
          const Product(id: 7, name: 'Updated', description: '', price: 2),
        ),
        isTrue,
      );
      expect(provider.products.first.name, 'Updated');
      expect(await provider.delete(7), isFalse);
      expect(provider.products.length, 2);
      expect(provider.mutationError, contains('500'));
      rejectDelete = false;
      expect(await provider.delete(7), isTrue);
      expect(provider.products.single.id, 8);
    },
  );

  test(
    'busy mutation is rejected; source switch cannot accept stale mutation',
    () async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final provider = ProductProvider(
        api: ProductApi(
          client: MockClient((r) async {
            if (r.method == 'GET') return jsonResponse([fixture]);
            writes++;
            return pending.future;
          }),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load(endpoint);
      final create = provider.create(
        name: 'Pending',
        description: '',
        price: 1,
      );
      expect(provider.isSaving, isTrue);
      expect(await provider.delete(7), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      provider.clearEndpoint();
      pending.complete(jsonResponse({...fixture, 'id': 9}, 201));
      expect(await create, isFalse);
      expect(provider.products, isEmpty);
      expect(provider.endpoint, isNull);
    },
  );

  test(
    'lookup uses ID endpoint and disposal suppresses pending notifications',
    () async {
      final pending = Completer<http.Response>();
      final provider = ProductProvider(
        api: ProductApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/7')) return jsonResponse(fixture);
            return pending.future;
          }),
        ),
      );
      final load = provider.load(endpoint);
      expect((await provider.findById(7))?.name, 'Bút Việt');
      provider.dispose();
      pending.complete(jsonResponse([fixture]));
      await load;
      expect(provider.products, isEmpty);
    },
  );
}
