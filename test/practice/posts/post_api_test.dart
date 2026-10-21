import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/post_api.dart';

void main() {
  const endpoint = 'https://example.com/posts?page=2';
  const json = '[{"id":1,"userId":2,"title":"Tiêu đề","body":"Nội dung"}]';

  test('fetches HTTPS endpoint and decodes a UTF-8 post list', () async {
    final api = PostApi(
      client: MockClient((request) async {
        if (request.url.toString() != endpoint || request.method != 'GET') {
          return http.Response('wrong endpoint or method', 400);
        }
        return http.Response.bytes(utf8.encode(json), 200);
      }),
    );
    addTearDown(api.close);
    final posts = await api.fetchPosts(endpoint);
    expect(posts, hasLength(1));
    expect(posts.single.toJson(), {
      'id': 1,
      'userId': 2,
      'title': 'Tiêu đề',
      'body': 'Nội dung',
    });
  });

  test('accepts an empty list as a valid empty state', () async {
    final api = PostApi(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(api.close);
    expect(await api.fetchPosts(endpoint), isEmpty);
  });

  test('reports non-success HTTP status without parsing its body', () async {
    final api = PostApi(
      client: MockClient(
        (_) async => http.Response('<html>unavailable</html>', 503),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchPosts(endpoint),
      throwsA(
        isA<PostApiException>().having(
          (e) => e.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });

  for (final body in [
    'not JSON',
    '{}',
    '{"data":[]}',
    '[null]',
    '[4]',
    '[{"id":1,"userId":2,"title":"ok"}]',
    '[{"id":1.5,"userId":2,"title":"ok","body":"ok"}]',
  ]) {
    test('reports malformed payload: $body', () async {
      final api = PostApi(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchPosts(endpoint),
        throwsA(isA<PostApiException>()),
      );
    });
  }

  test('reports timeout when server does not respond', () async {
    final response = Completer<http.Response>();
    final api = PostApi(
      client: MockClient((_) => response.future),
      requestTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchPosts(endpoint),
      throwsA(
        isA<PostApiException>().having(
          (e) => e.message,
          'message',
          contains('thời gian'),
        ),
      ),
    );
    response.complete(http.Response.bytes(utf8.encode(json), 200));
  });

  test('reports connection failure', () async {
    final api = PostApi(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchPosts(endpoint),
      throwsA(isA<PostApiException>()),
    );
  });

  for (final endpoint in [
    'http://example.com/posts',
    'bad url',
    'https:///posts',
  ]) {
    test('rejects invalid HTTPS endpoint: $endpoint', () async {
      final api = PostApi(
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchPosts(endpoint),
        throwsA(isA<PostApiException>()),
      );
    });
  }
}
