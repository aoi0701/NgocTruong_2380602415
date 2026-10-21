import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/post.dart';
import 'package:ngoc_truong_2380602415/practice/features/settings/favorites_provider.dart';
import 'package:ngoc_truong_2380602415/practice/features/settings/preferences_store.dart';
import 'package:ngoc_truong_2380602415/practice/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'preferences_test_support.dart';

const firstPost = Post(
  id: 1,
  userId: 8,
  title: 'Bài đã lưu',
  body: 'Nội dung offline',
);
const secondPost = Post(
  id: 2,
  userId: 9,
  title: 'Bài thứ hai',
  body: 'Đầy đủ nội dung',
);

Future<PreferencesStore> openStore() async =>
    PreferencesStore(await SharedPreferences.getInstance());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reopening retains theme, endpoint and complete offline snapshots',
    () async {
      final store = await openStore();
      final settings = SettingsProvider(store: store);
      final favorites = FavoritesProvider(store: store);
      await settings.setDarkMode(true);
      await settings.setEndpoint('  https://example.org/api/posts?limit=5  ');
      await favorites.toggle(firstPost);

      SharedPreferences.resetStatic();
      final reopened = await openStore();
      expect(reopened.darkMode, isTrue);
      expect(reopened.endpoint, 'https://example.org/api/posts?limit=5');
      expect(reopened.favorites.single.toJson(), {
        'id': 1,
        'userId': 8,
        'title': 'Bài đã lưu',
        'body': 'Nội dung offline',
      });
    },
  );

  test('defaults recover wrong preference types and malformed JSON', () async {
    SharedPreferences.setMockInitialValues({
      PreferencesStore.darkModeKey: 'not a bool',
      PreferencesStore.endpointKey: 42,
      PreferencesStore.favoritesKey: '{broken json',
    });
    final store = await openStore();
    expect(store.darkMode, isFalse);
    expect(store.endpoint, 'https://jsonplaceholder.typicode.com/posts');
    expect(store.favorites, isEmpty);
  });

  test('recovers invalid endpoint and non-list favorites', () async {
    SharedPreferences.setMockInitialValues({
      PreferencesStore.endpointKey: 'http://insecure.test/posts',
      PreferencesStore.favoritesKey: '{"id":1}',
    });
    final store = await openStore();
    expect(store.endpoint, SettingsProvider.defaultEndpoint);
    expect(store.favorites, isEmpty);
  });

  test(
    'keeps good snapshots, skips corrupt entries and deduplicates IDs',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferencesStore.favoritesKey: jsonEncode([
          firstPost.toJson(),
          {'id': 'bad'},
          null,
          4,
          firstPost.toJson(),
          secondPost.toJson(),
        ]),
      });
      final store = await openStore();
      expect(store.favorites.map((p) => p.id), [1, 2]);
      expect(() => store.favorites.clear(), throwsUnsupportedError);
    },
  );

  for (final endpoint in [
    '',
    '/posts',
    'http://example.org/posts',
    'https:///posts',
    'https://user:password@example.org/posts',
    'https://example.org/posts#part',
    'https://example.org',
    'https://example.org/',
    'https://exam ple.org/posts',
  ]) {
    test(
      'rejects invalid endpoint "$endpoint" without replacing saved URL',
      () async {
        final store = await openStore();
        final settings = SettingsProvider(store: store);
        await expectLater(
          settings.setEndpoint(endpoint),
          throwsFormatException,
        );
        expect(settings.endpoint, SettingsProvider.defaultEndpoint);
        expect(store.endpoint, SettingsProvider.defaultEndpoint);
      },
    );
  }

  test('store also validates endpoint passed without a provider', () async {
    final store = await openStore();
    await expectLater(
      store.saveEndpoint('http://example.org/posts'),
      throwsFormatException,
    );
    expect(store.endpoint, SettingsProvider.defaultEndpoint);
  });

  test(
    'rapid favorite toggles preserve distinct posts and same-ID parity',
    () async {
      final store = await openStore();
      final favorites = FavoritesProvider(store: store);
      await Future.wait([
        favorites.toggle(firstPost),
        favorites.toggle(secondPost),
        favorites.toggle(firstPost),
        favorites.toggle(firstPost),
      ]);
      expect(favorites.favorites.map((p) => p.id), [2, 1]);
      expect(favorites.contains(1), isTrue);
      expect(() => favorites.favorites.clear(), throwsUnsupportedError);
      SharedPreferences.resetStatic();
      expect((await openStore()).favorites.map((p) => p.id), [2, 1]);
    },
  );

  test('rapid settings writes preserve invocation order', () async {
    final settings = SettingsProvider(store: await openStore());
    await Future.wait([
      settings.setDarkMode(true),
      settings.setDarkMode(false),
      settings.setEndpoint('https://one.example/posts'),
      settings.setEndpoint('https://two.example/api/posts'),
    ]);
    expect(settings.darkMode, isFalse);
    expect(settings.endpoint, 'https://two.example/api/posts');
    SharedPreferences.resetStatic();
    expect((await openStore()).endpoint, 'https://two.example/api/posts');
  });

  group('native write outcomes', () {
    late ControlledPreferencesPlatform platform;
    setUp(() {
      SharedPreferences.resetStatic();
      platform = ControlledPreferencesPlatform();
      SharedPreferencesStorePlatform.instance = platform;
    });

    test('theme changes and notifications wait for durable write', () async {
      final settings = SettingsProvider(store: await openStore());
      var notifications = 0;
      settings.addListener(() => notifications++);
      final gate = Completer<void>();
      platform.gate = gate;
      var completed = false;
      final save = settings.setDarkMode(true).then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(settings.darkMode, isFalse);
      expect(notifications, 0);
      expect(completed, isFalse);
      gate.complete();
      await save;
      expect(settings.darkMode, isTrue);
      expect(notifications, 1);
    });

    test(
      'false native writes surface errors and repair optimistic plugin cache',
      () async {
        final store = await openStore();
        final settings = SettingsProvider(store: store);
        await settings.setEndpoint('https://old.example/posts');
        platform.failNextWrite = true;
        await expectLater(
          settings.setEndpoint('https://new.example/posts'),
          throwsException,
        );
        expect(settings.endpoint, 'https://old.example/posts');
        expect(store.endpoint, 'https://old.example/posts');
        expect((await openStore()).endpoint, 'https://old.example/posts');
        // The queue is still usable after a failure.
        await settings.setDarkMode(true);
        expect(settings.darkMode, isTrue);
      },
    );

    test(
      'native exceptions do not falsely add favorites and next toggle can save',
      () async {
        final store = await openStore();
        final favorites = FavoritesProvider(store: store);
        platform.throwNextWrite = true;
        await expectLater(favorites.toggle(firstPost), throwsException);
        expect(favorites.contains(1), isFalse);
        expect(store.favorites, isEmpty);
        expect((await openStore()).favorites, isEmpty);
        await favorites.toggle(firstPost);
        expect(favorites.favorites.single.body, 'Nội dung offline');
      },
    );

    test('failed removal retains full snapshot', () async {
      final favorites = FavoritesProvider(store: await openStore());
      await favorites.toggle(firstPost);
      platform.failNextWrite = true;
      await expectLater(favorites.toggle(firstPost), throwsException);
      expect(favorites.favorites.single.title, 'Bài đã lưu');
      SharedPreferences.resetStatic();
      expect((await openStore()).favorites.single.body, 'Nội dung offline');
    });

    test(
      'queued saves after provider disposal do not notify disposed listeners',
      () async {
        final store = await openStore();
        final settings = SettingsProvider(store: store);
        final favorites = FavoritesProvider(store: store);
        final gate = Completer<void>();
        platform.gate = gate;
        final first = settings.setDarkMode(true);
        final second = favorites.toggle(firstPost);
        await Future<void>.delayed(Duration.zero);
        settings.dispose();
        favorites.dispose();
        gate.complete();
        await Future.wait([first, second]);
        SharedPreferences.resetStatic();
        final reopened = await openStore();
        expect(reopened.darkMode, isTrue);
        expect(reopened.favorites.single.id, 1);
      },
    );
  });
}
