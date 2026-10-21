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

const originalPost = Post(
  id: 1,
  userId: 1,
  title: 'Bài nguồn mặc định',
  body: 'Nội dung gốc',
);
const customPost = Post(
  id: 1,
  userId: 8,
  title: 'Bài nguồn tùy chỉnh',
  body: 'Nội dung khác cùng ID',
);
const customSource = 'https://custom.example/api/posts';
const defaultSource = SettingsProvider.defaultEndpoint;
const sampleSource = 'sample://posts';

Future<PreferencesStore> openStore() async =>
    PreferencesStore(await SharedPreferences.getInstance());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'same post ID at another endpoint does not select or remove old favorite',
    () async {
      final store = await openStore();
      final original = FavoritesProvider(store: store);
      await original.toggle(originalPost);
      await store.saveEndpoint(customSource);
      final custom = FavoritesProvider(store: store);
      expect(custom.contains(1), isFalse);
      await custom.toggle(customPost);
      expect(custom.favorites.single.title, 'Bài nguồn tùy chỉnh');
      expect(original.favorites.single.title, 'Bài nguồn mặc định');
    },
  );

  test(
    'switching source restores each list and namespaces survive restart',
    () async {
      final store = await openStore();
      final favorites = FavoritesProvider(store: store);
      await favorites.toggle(originalPost);
      favorites.setSource(customSource);
      expect(favorites.favorites, isEmpty);
      await favorites.toggle(customPost);
      favorites.setSource(sampleSource);
      expect(favorites.contains(1), isFalse);
      await favorites.toggle(
        const Post(
          id: 1,
          userId: 99,
          title: 'Bài dữ liệu mẫu',
          body: 'Nội dung mẫu',
        ),
      );
      favorites.setSource(defaultSource);
      expect(favorites.favorites.single.title, 'Bài nguồn mặc định');
      favorites.setSource(customSource);
      expect(favorites.favorites.single.title, 'Bài nguồn tùy chỉnh');

      SharedPreferences.resetStatic();
      final reopened = await openStore();
      expect(reopened.favoritesFor(defaultSource).single.body, 'Nội dung gốc');
      expect(
        reopened.favoritesFor(customSource).single.body,
        'Nội dung khác cùng ID',
      );
      expect(reopened.favoritesFor(sampleSource).single.body, 'Nội dung mẫu');
      expect(
        () => reopened.favoritesFor(customSource).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'legacy snapshots migrate to default namespace even with custom current endpoint',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferencesStore.endpointKey: customSource,
        PreferencesStore.favoritesKey: jsonEncode([originalPost.toJson()]),
      });
      final store = await openStore();
      final favorites = FavoritesProvider(store: store);
      expect(favorites.favorites, isEmpty);
      expect(
        store.favoritesFor(defaultSource).single.title,
        'Bài nguồn mặc định',
      );
      await favorites.toggle(customPost);
      SharedPreferences.resetStatic();
      final reopened = await openStore();
      expect(
        reopened.favoritesFor(defaultSource).single.title,
        'Bài nguồn mặc định',
      );
      expect(
        reopened.favoritesFor(customSource).single.title,
        'Bài nguồn tùy chỉnh',
      );
    },
  );

  test(
    'removing migrated favorite does not resurrect untouched legacy JSON',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferencesStore.favoritesKey: jsonEncode([originalPost.toJson()]),
      });
      final favorites = FavoritesProvider(store: await openStore());
      await favorites.toggle(originalPost);
      SharedPreferences.resetStatic();
      expect((await openStore()).favoritesFor(defaultSource), isEmpty);
    },
  );

  test('legacy aliases remain tied to default source', () async {
    final store = await openStore();
    await store.saveEndpoint(customSource);
    await store.saveFavorites([originalPost]);
    expect(store.favorites.single.title, 'Bài nguồn mặc định');
    expect(
      store.favoritesFor(defaultSource).single.title,
      'Bài nguồn mặc định',
    );
    expect(store.favoritesFor(customSource), isEmpty);
  });

  for (final corrupt in ['{broken', '[]', 42]) {
    test(
      'corrupt v2 value $corrupt recovers legacy default snapshots',
      () async {
        SharedPreferences.setMockInitialValues({
          PreferencesStore.favoritesBySourceKey: corrupt,
          PreferencesStore.favoritesKey: jsonEncode([originalPost.toJson()]),
        });
        final store = await openStore();
        expect(
          store.favoritesFor(defaultSource).single.title,
          'Bài nguồn mặc định',
        );
        expect(store.favoritesFor(customSource), isEmpty);
      },
    );
  }

  test(
    'v2 corruption stays local to each snapshot and each namespace',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferencesStore.favoritesBySourceKey: jsonEncode({
          defaultSource: [
            originalPost.toJson(),
            originalPost.toJson(),
            {'id': 'bad'},
          ],
          customSource: [null, 7, customPost.toJson()],
          sampleSource: 'not a list',
        }),
      });
      final store = await openStore();
      expect(store.favoritesFor(defaultSource).single.body, 'Nội dung gốc');
      expect(
        store.favoritesFor(customSource).single.body,
        'Nội dung khác cùng ID',
      );
      expect(store.favoritesFor(sampleSource), isEmpty);
    },
  );

  test(
    'valid empty v2 map does not resurrect obsolete legacy snapshots',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferencesStore.favoritesBySourceKey: '{}',
        PreferencesStore.favoritesKey: jsonEncode([originalPost.toJson()]),
      });
      expect((await openStore()).favoritesFor(defaultSource), isEmpty);
    },
  );

  test(
    'concurrent store writes merge different namespaces inside the queue',
    () async {
      final store = await openStore();
      await Future.wait([
        store.saveFavoritesFor(defaultSource, [originalPost]),
        store.saveFavoritesFor(customSource, [customPost]),
      ]);
      SharedPreferences.resetStatic();
      final reopened = await openStore();
      expect(
        reopened.favoritesFor(defaultSource).single.title,
        'Bài nguồn mặc định',
      );
      expect(
        reopened.favoritesFor(customSource).single.title,
        'Bài nguồn tùy chỉnh',
      );
    },
  );

  group('delayed source writes', () {
    late ControlledPreferencesPlatform platform;
    setUp(() {
      SharedPreferences.resetStatic();
      platform = ControlledPreferencesPlatform();
      SharedPreferencesStorePlatform.instance = platform;
    });

    test(
      'queued toggles keep invocation source across a switch during native save',
      () async {
        final store = await openStore();
        final favorites = FavoritesProvider(store: store);
        final gate = Completer<void>();
        platform.gate = gate;
        final first = favorites.toggle(originalPost);
        await Future<void>.delayed(Duration.zero);
        final queued = favorites.toggle(
          const Post(
            id: 2,
            userId: 1,
            title: 'Bài gốc xếp hàng',
            body: 'Vẫn thuộc nguồn gốc',
          ),
        );
        favorites.setSource(customSource);
        expect(favorites.favorites, isEmpty);
        final custom = favorites.toggle(customPost);
        gate.complete();
        await Future.wait([first, queued, custom]);

        expect(store.favoritesFor(defaultSource).map((post) => post.id), [
          1,
          2,
        ]);
        expect(favorites.favorites.single.title, 'Bài nguồn tùy chỉnh');
        favorites.setSource(defaultSource);
        expect(favorites.favorites.map((post) => post.title), [
          'Bài nguồn mặc định',
          'Bài gốc xếp hàng',
        ]);
        SharedPreferences.resetStatic();
        final reopened = await openStore();
        expect(reopened.favoritesFor(defaultSource).length, 2);
        expect(
          reopened.favoritesFor(customSource).single.body,
          'Nội dung khác cùng ID',
        );
      },
    );

    test(
      'failed delayed removal preserves both sources and repairs plugin cache',
      () async {
        final store = await openStore();
        await store.saveFavoritesFor(defaultSource, [originalPost]);
        await store.saveFavoritesFor(customSource, [customPost]);
        final favorites = FavoritesProvider(store: store);
        final gate = Completer<void>();
        platform.gate = gate;
        platform.failNextWrite = true;
        final pending = favorites.toggle(originalPost);
        final failure = expectLater(
          pending,
          throwsA(isA<PreferencesSaveException>()),
        );
        await Future<void>.delayed(Duration.zero);
        favorites.setSource(customSource);
        gate.complete();
        await failure;

        expect(favorites.favorites.single.title, 'Bài nguồn tùy chỉnh');
        favorites.setSource(defaultSource);
        expect(favorites.favorites.single.title, 'Bài nguồn mặc định');
        final reopened = await openStore();
        expect(
          reopened.favoritesFor(defaultSource).single.body,
          'Nội dung gốc',
        );
        expect(
          reopened.favoritesFor(customSource).single.body,
          'Nội dung khác cùng ID',
        );
        // Failure does not poison the queue or mix the two lists on retry.
        await favorites.toggle(originalPost);
        SharedPreferences.resetStatic();
        final retried = await openStore();
        expect(retried.favoritesFor(defaultSource), isEmpty);
        expect(
          retried.favoritesFor(customSource).single.title,
          'Bài nguồn tùy chỉnh',
        );
      },
    );
  });
}
