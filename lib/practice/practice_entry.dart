import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'app.dart';
import 'features/notes/notes_provider.dart';
import 'features/notes/notes_repository.dart';
import 'features/posts/post_api.dart';
import 'features/posts/posts_provider.dart';
import 'features/products/product_api.dart';
import 'features/products/product_provider.dart';
import 'features/settings/favorites_provider.dart';
import 'features/settings/preferences_store.dart';
import 'features/settings/settings_provider.dart';

/// Màn hình luyện tập trong ứng dụng hiện tại; không tạo ứng dụng/entrypoint mới.
class PracticeEntry extends StatefulWidget {
  const PracticeEntry({super.key});
  @override
  State<PracticeEntry> createState() => _PracticeEntryState();
}

class _PracticeEntryState extends State<PracticeEntry> {
  late Future<SharedPreferences> _preferences;
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      sqlite.databaseFactory = ffi.databaseFactoryFfi;
    }
    _preferences = SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: _preferences,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return _ReadyApp(
          preferences: snapshot.requireData,
          onExit: () => Navigator.of(context).pop(),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Không mở được dữ liệu cài đặt trên máy.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(
                            () =>
                                _preferences = SharedPreferences.getInstance(),
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

class _ReadyApp extends StatefulWidget {
  const _ReadyApp({required this.preferences, required this.onExit});
  final SharedPreferences preferences;
  final VoidCallback onExit;
  @override
  State<_ReadyApp> createState() => _ReadyAppState();
}

class _ReadyAppState extends State<_ReadyApp> {
  late final _store = PreferencesStore(widget.preferences);
  late final _repository = NotesRepository();
  late final _settings = SettingsProvider(store: _store);
  late final _favorites = FavoritesProvider(store: _store);
  late final _posts = PostsProvider(api: PostApi());
  late final _products = ProductProvider(api: ProductApi());
  late final _notes = NotesProvider(repository: _repository);
  @override
  Widget build(BuildContext context) => ExamPrepApp(
    settings: _settings,
    favorites: _favorites,
    posts: _posts,
    products: _products,
    notes: _notes,
    notesRepository: _repository,
    onExit: widget.onExit,
  );
}
