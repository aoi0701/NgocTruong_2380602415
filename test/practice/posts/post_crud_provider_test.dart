import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/post.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/post_api.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/posts_provider.dart';

void main() {
  const endpoint = 'http://localhost:5186/api/posts';
  const original = Post(id: 1, userId: 2, title: 'Before', body: 'Body');
  PostsProvider make(Future<http.Response> Function(http.Request) handler) {
    final p = PostsProvider(api: PostApi(client: MockClient(handler)));
    addTearDown(p.dispose);
    return p;
  }

  test('real create update delete change list only after success', () async {
    final dynamic p = make((r) async {
      if (r.method == 'GET') return http.Response('[]', 200);
      if (r.method == 'DELETE') return http.Response('', 204);
      return http.Response(
        jsonEncode({'id': 1, ...jsonDecode(r.body) as Map}),
        r.method == 'POST' ? 201 : 200,
      );
    });
    await p.load(endpoint);
    expect(p.canWrite, isTrue);
    final Post created = await p.createPost(
      userId: 2,
      title: 'Before',
      body: 'Body',
    );
    expect(created.id, 1);
    expect(p.posts.single.title, 'Before');
    await p.updatePost(
      const Post(id: 1, userId: 2, title: 'After', body: 'New'),
    );
    expect(p.posts.single.title, 'After');
    await p.deletePost(1);
    expect(p.posts, isEmpty);
  });
  test('failed mutation preserves list and exposes server error', () async {
    final dynamic p = make(
      (r) async => r.method == 'GET'
          ? http.Response(jsonEncode([original.toJson()]), 200)
          : http.Response('{"title":"Bad input"}', 400),
    );
    await p.load(endpoint);
    expect(await p.updatePost(original), isNull);
    expect(p.posts.single.title, 'Before');
    expect(p.mutationError, contains('400'));
    expect(p.isSaving, isFalse);
  });
  for (final status in [201, 400]) {
    test('source switch ignores late mutation $status', () async {
      final response = Completer<http.Response>();
      final dynamic p = make(
        (r) => r.method == 'GET'
            ? Future.value(http.Response('[]', 200))
            : response.future,
      );
      await p.load(endpoint);
      final save = p.createPost(userId: 2, title: 'Before', body: 'Body');
      expect(p.isSaving, isTrue);
      expect(
        await p.createPost(userId: 2, title: 'Duplicate', body: 'x'),
        isNull,
      );
      await p.load('https://other.example/api/posts');
      response.complete(
        http.Response(
          status == 201 ? jsonEncode(original.toJson()) : '',
          status,
        ),
      );
      expect(await save, isNull);
      expect(p.posts, isEmpty);
      expect(p.mutationError, isNull);
      expect(p.isSaving, isFalse);
    });
  }
  test('sample and JSONPlaceholder cannot simulate persistence', () async {
    final requests = <String>[];
    final dynamic p = make((r) async {
      requests.add(r.method);
      return http.Response('[]', 200);
    });
    await p.load('https://jsonplaceholder.typicode.com/posts');
    expect(p.canWrite, isFalse);
    expect(await p.createPost(userId: 2, title: 'a', body: 'b'), isNull);
    p.loadSampleData();
    expect(p.canWrite, isFalse);
    expect(await p.deletePost(-1), isFalse);
    expect(requests, ['GET']);
  });
  test(
    'ID lookup actually calls item endpoint and discards stale result',
    () async {
      final response = Completer<http.Response>();
      final dynamic p = make(
        (r) => r.url.path.endsWith('/1')
            ? response.future
            : Future.value(http.Response('[]', 200)),
      );
      await p.load(endpoint);
      final lookup = p.findPost(1);
      p.loadSampleData();
      response.complete(http.Response(jsonEncode(original.toJson()), 200));
      expect(await lookup, isNull);
      expect(p.isSampleData, isTrue);
    },
  );
  test(
    'dispose cancels visible saving state and ignores pending mutation',
    () async {
      final response = Completer<http.Response>();
      final p = make(
        (r) => r.method == 'GET'
            ? Future.value(http.Response('[]', 200))
            : response.future,
      );
      await p.load(endpoint);
      final save = p.createPost(userId: 2, title: 'Before', body: 'Body');
      expect(p.isSaving, isTrue);
      p.dispose();
      expect(p.isSaving, isFalse);
      response.complete(http.Response(jsonEncode(original.toJson()), 201));
      expect(await save, isNull);
      expect(p.posts, isEmpty);
      expect(p.mutationError, isNull);
    },
  );
}
