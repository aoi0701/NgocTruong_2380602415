import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/post_api.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/posts_provider.dart';

const endpoint = 'https://example.com/posts';
const payload =
    '['
    '{"id":3,"userId":1,"title":"Zebra","body":"Different content"},'
    '{"id":1,"userId":2,"title":"apple","body":"Learning Flutter"},'
    '{"id":2,"userId":1,"title":"Banana","body":"Learn Dart"}'
    ']';

PostsProvider providerWith(
  Future<http.Response> Function(http.Request) handler,
) {
  final provider = PostsProvider(api: PostApi(client: MockClient(handler)));
  addTearDown(provider.dispose);
  return provider;
}

void main() {
  test('announces loading then exposes successful posts', () async {
    final response = Completer<http.Response>();
    final provider = providerWith((_) => response.future);
    final states = <bool>[];
    provider.addListener(() => states.add(provider.isLoading));
    final load = provider.load(endpoint);
    expect(provider.isLoading, isTrue);
    expect(provider.error, isNull);
    response.complete(http.Response(payload, 200));
    await load;
    expect(states, [true, false]);
    expect(provider.posts.map((post) => post.id), [3, 1, 2]);
    expect(provider.isLoading, isFalse);
    expect(provider.isSampleData, isFalse);
  });

  test(
    'filters title and body without case or surrounding whitespace',
    () async {
      final provider = providerWith((_) async => http.Response(payload, 200));
      await provider.load(endpoint);
      provider.setQuery(' APPLE ');
      expect(provider.visiblePosts.map((post) => post.id), [1]);
      provider.setQuery('flutter');
      expect(provider.visiblePosts.map((post) => post.id), [1]);
      provider.setQuery('no matches');
      expect(provider.visiblePosts, isEmpty);
    },
  );

  test(
    'sorts titles in both directions without changing fetched order',
    () async {
      final provider = providerWith((_) async => http.Response(payload, 200));
      await provider.load(endpoint);
      expect(provider.sortAscending, isTrue);
      expect(provider.visiblePosts.map((post) => post.id), [1, 2, 3]);
      provider.setSortAscending(false);
      expect(provider.sortAscending, isFalse);
      expect(provider.visiblePosts.map((post) => post.id), [3, 2, 1]);
      expect(provider.posts.map((post) => post.id), [3, 1, 2]);
      expect(() => provider.posts.clear(), throwsUnsupportedError);
      expect(() => provider.visiblePosts.clear(), throwsUnsupportedError);
    },
  );

  test(
    'network failure is visible and never silently activates sample data',
    () async {
      final provider = providerWith(
        (_) async => http.Response('unavailable', 503),
      );
      await provider.load(endpoint);
      expect(provider.error, contains('503'));
      expect(provider.isLoading, isFalse);
      expect(provider.isSampleData, isFalse);
      expect(provider.posts, isEmpty);
    },
  );

  test('retry clears error and exposes a valid empty response', () async {
    var attempt = 0;
    final provider = providerWith(
      (_) async => ++attempt == 1
          ? http.Response('unavailable', 503)
          : http.Response('[]', 200),
    );
    await provider.load(endpoint);
    expect(provider.error, isNotNull);
    await provider.load(endpoint);
    expect(provider.error, isNull);
    expect(provider.posts, isEmpty);
    expect(provider.isLoading, isFalse);
  });

  test(
    'late success from an older endpoint cannot replace newer posts',
    () async {
      final first = Completer<http.Response>();
      final provider = providerWith(
        (request) => request.url.path == '/old'
            ? first.future
            : Future.value(http.Response(payload, 200)),
      );
      final oldLoad = provider.load('https://example.com/old');
      await provider.load(endpoint);
      first.complete(
        http.Response('[{"id":99,"userId":1,"title":"old","body":"old"}]', 200),
      );
      await oldLoad;
      expect(provider.posts.map((post) => post.id), [3, 1, 2]);
      expect(provider.error, isNull);
    },
  );

  test('late error from an older request cannot replace newer state', () async {
    final first = Completer<http.Response>();
    final provider = providerWith(
      (request) => request.url.path == '/old'
          ? first.future
          : Future.value(http.Response(payload, 200)),
    );
    final oldLoad = provider.load('https://example.com/old');
    await provider.load(endpoint);
    first.complete(http.Response('unavailable', 503));
    await oldLoad;
    expect(provider.error, isNull);
    expect(provider.posts, hasLength(3));
    expect(provider.isLoading, isFalse);
  });

  test(
    'older completion cannot clear loading for the pending latest request',
    () async {
      final first = Completer<http.Response>();
      final latest = Completer<http.Response>();
      final provider = providerWith(
        (request) => request.url.path == '/old' ? first.future : latest.future,
      );
      final oldLoad = provider.load('https://example.com/old');
      final newLoad = provider.load(endpoint);
      first.complete(http.Response(payload, 200));
      await oldLoad;
      expect(provider.isLoading, isTrue);
      latest.complete(http.Response('[]', 200));
      await newLoad;
      expect(provider.isLoading, isFalse);
      expect(provider.posts, isEmpty);
    },
  );

  test('explicit sample action supersedes pending network success', () async {
    final response = Completer<http.Response>();
    final provider = providerWith((_) => response.future);
    final load = provider.load(endpoint);
    provider.loadSampleData();
    final sample = provider.posts.map((post) => post.toJson()).toList();
    expect(sample, isNotEmpty);
    expect(provider.isSampleData, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
    response.complete(http.Response('[]', 200));
    await load;
    expect(provider.posts.map((post) => post.toJson()), sample);
    expect(provider.isSampleData, isTrue);
  });

  test('explicit sample action supersedes pending network failure', () async {
    final response = Completer<http.Response>();
    final provider = providerWith((_) => response.future);
    final load = provider.load(endpoint);
    provider.loadSampleData();
    response.complete(http.Response('unavailable', 503));
    await load;
    expect(provider.error, isNull);
    expect(provider.isSampleData, isTrue);
    expect(provider.posts, isNotEmpty);
  });

  test(
    'sample favorite identities do not match unrelated live posts',
    () async {
      final provider = providerWith((_) async => http.Response(payload, 200));
      provider.loadSampleData();
      final sampleIds = provider.posts.map((post) => post.id).toSet();
      expect(sampleIds, isNotEmpty);

      await provider.load(endpoint);

      final liveIds = provider.posts.map((post) => post.id).toSet();
      expect(liveIds, {1, 2, 3});
      expect(
        liveIds.intersection(sampleIds),
        isEmpty,
        reason:
            'Saved sample IDs must not favorite unrelated positive live IDs.',
      );
      expect(sampleIds, everyElement(lessThan(0)));
    },
  );

  test(
    'leaving sample mode clears samples before a new request can fail',
    () async {
      final provider = providerWith(
        (_) async => http.Response('unavailable', 503),
      );
      provider.loadSampleData();
      await provider.load(endpoint);
      expect(provider.isSampleData, isFalse);
      expect(provider.posts, isEmpty);
      expect(provider.error, contains('503'));
    },
  );

  for (final status in [200, 503]) {
    test(
      'disposed provider ignores pending HTTP $status completion and setters',
      () async {
        final response = Completer<http.Response>();
        final provider = PostsProvider(
          api: PostApi(client: MockClient((_) => response.future)),
        );
        final load = provider.load(endpoint);
        provider.dispose();
        response.complete(
          http.Response(status == 200 ? payload : 'unavailable', status),
        );
        await expectLater(load, completes);
        expect(provider.posts, isEmpty);
        expect(provider.error, isNull);
        expect(() => provider.setQuery('x'), returnsNormally);
        expect(() => provider.setSortAscending(false), returnsNormally);
        expect(() => provider.loadSampleData(), returnsNormally);
        await expectLater(provider.load(endpoint), completes);
        expect(provider.posts, isEmpty);
      },
    );
  }
}
