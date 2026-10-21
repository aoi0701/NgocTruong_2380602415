import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/post.dart';
import 'package:Nhom_3_nguoi/practice/features/posts/post_api.dart';

void main() {
  const endpoint = 'http://10.0.2.2:5186/api/posts?tenant=exam';
  const post = Post(id: 7, userId: 2, title: 'Bài mới', body: 'Nội dung');
  test('GET by ID preserves collection query and decodes post', () async {
    final dynamic api = PostApi(
      client: MockClient((r) async {
        if (r.method != 'GET' ||
            r.url.toString() !=
                'http://10.0.2.2:5186/api/posts/7?tenant=exam') {
          return http.Response('', 400);
        }
        return http.Response.bytes(utf8.encode(jsonEncode(post.toJson())), 200);
      }),
    );
    addTearDown(() => api.close());
    final Post result = await api.fetchPost(endpoint, 7);
    expect(result.toJson(), post.toJson());
  });
  test('POST sends input only and accepts server identity at 201', () async {
    final dynamic api = PostApi(
      client: MockClient((r) async {
        if (r.method != 'POST' ||
            r.headers['content-type'] != 'application/json; charset=utf-8' ||
            jsonEncode(jsonDecode(r.body)) !=
                jsonEncode({
                  'userId': 2,
                  'title': 'Bài mới',
                  'body': 'Nội dung',
                })) {
          return http.Response('', 400);
        }
        return http.Response.bytes(utf8.encode(jsonEncode(post.toJson())), 201);
      }),
    );
    addTearDown(() => api.close());
    final Post result = await api.createPost(
      endpoint,
      userId: 2,
      title: '  Bài mới ',
      body: ' Nội dung ',
    );
    expect(result.id, 7);
  });
  for (final status in [200, 204]) {
    test('PUT supports $status and DELETE accepts empty 204', () async {
      final dynamic api = PostApi(
        client: MockClient((r) async {
          if (r.url.path != '/api/posts/7') return http.Response('', 400);
          if (r.method == 'DELETE') return http.Response('', 204);
          if (r.method != 'PUT') return http.Response('', 400);
          return http.Response.bytes(
            utf8.encode(status == 200 ? jsonEncode(post.toJson()) : ''),
            status,
          );
        }),
      );
      addTearDown(() => api.close());
      final Post result = await api.updatePost(endpoint, post);
      expect(result.toJson(), post.toJson());
      await expectLater(api.deletePost(endpoint, 7), completes);
    });
  }
  for (final status in [400, 404, 500]) {
    test(
      'mutation HTTP $status is visible instead of fabricated success',
      () async {
        final dynamic api = PostApi(
          client: MockClient(
            (_) async => http.Response('{"title":"Invalid input"}', status),
          ),
        );
        addTearDown(() => api.close());
        await expectLater(
          api.updatePost(endpoint, post),
          throwsA(
            isA<PostApiException>().having(
              (e) => e.message,
              'status',
              contains('$status'),
            ),
          ),
        );
        await expectLater(
          api.deletePost(endpoint, 7),
          throwsA(isA<PostApiException>()),
        );
      },
    );
  }
  test('malformed successful creation is an error', () async {
    final dynamic api = PostApi(
      client: MockClient((_) async => http.Response('{}', 201)),
    );
    addTearDown(() => api.close());
    await expectLater(
      api.createPost(endpoint, userId: 2, title: 'a', body: 'b'),
      throwsA(isA<PostApiException>()),
    );
  });
  test('lookup timeout is translated to a useful error', () async {
    final response = Completer<http.Response>();
    final dynamic api = PostApi(
      client: MockClient((_) => response.future),
      requestTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(() => api.close());
    await expectLater(
      api.fetchPost(endpoint, 7),
      throwsA(isA<PostApiException>()),
    );
    response.complete(http.Response('', 404));
  });
}
