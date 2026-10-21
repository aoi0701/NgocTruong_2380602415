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
import '../screens/login_screen.dart';
import '../screens/market_screen.dart';
import '../screens/feed_screen.dart';

/// Màn hình trung tâm chọn bài thực hành Tuần 6 & Tuần 7.
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
        return _PracticeHubScreen(
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

class _PracticeHubScreen extends StatelessWidget {
  const _PracticeHubScreen({required this.preferences, required this.onExit});
  final SharedPreferences preferences;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Về ứng dụng chính',
            onPressed: onExit,
          ),
          title: const Text(
            'Thực hành Bài 6 & Bài 7',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Chọn nội dung ôn tập & kiểm tra:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Card 1: Tuần 7 - Xác thực & Phân quyền
            _buildActionCard(
              context,
              title: 'Tuần 7: Xác thực & Phân quyền 3 vai trò',
              subtitle: 'Đăng ký Email, Đăng nhập OTP, Phân quyền chuẩn xác (Admin / Nhân viên / Khách hàng), SmartAuth, Quản lý Danh mục.',
              icon: Icons.security_rounded,
              color: Colors.blue[700]!,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 2: Tuần 6 - Chợ sản phẩm
            _buildActionCard(
              context,
              title: 'Tuần 6: Chợ sản phẩm (MarketScreen)',
              subtitle: 'Sử dụng FutureBuilder theo đúng mẫu của giảng viên, hiển thị ảnh, tìm kiếm theo tên, xem theo ID, CRUD sản phẩm.',
              icon: Icons.storefront_rounded,
              color: Colors.teal[700]!,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MarketScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 3: Tuần 6 - Bảng tin bài viết
            _buildActionCard(
              context,
              title: 'Tuần 6: Bảng tin bài đăng (FeedScreen)',
              subtitle: 'Bảng tin phong cách Facebook kết nối REST API Posts, hỗ trợ đăng bài mới, sửa, xóa, Thích và Bình luận.',
              icon: Icons.dynamic_feed_rounded,
              color: Colors.indigo[700]!,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // Card 4: Tổng hợp ôn tập
            _buildActionCard(
              context,
              title: 'Tổng hợp ôn tập (ExamPrepApp)',
              subtitle: 'Bộ giao diện tích hợp Provider, SQLite ghi chú ngoại tuyến, Yêu thích và Cài đặt endpoint nâng cao.',
              icon: Icons.auto_stories_rounded,
              color: Colors.deepPurple[700]!,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ReadyApp(
                      preferences: preferences,
                      onExit: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
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
