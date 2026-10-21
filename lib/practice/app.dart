import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/notes/notes_provider.dart';
import 'features/notes/notes_repository.dart';
import 'features/notes/notes_screen.dart';
import 'features/posts/posts_provider.dart';
import 'features/products/product_provider.dart';
import 'features/products/product_screen.dart';
import 'features/shared/api_endpoint.dart';
import 'features/settings/favorites_provider.dart';
import 'features/settings/settings_provider.dart';
import 'features/settings/settings_screen.dart';
import 'screens/posts_screen.dart';

/// App sở hữu và giải phóng các Provider được truyền vào.
class ExamPrepApp extends StatefulWidget {
  const ExamPrepApp({
    super.key,
    required this.settings,
    required this.favorites,
    required this.posts,
    required this.notes,
    this.notesRepository,
    this.onExit,
    this.products,
  });
  final SettingsProvider settings;
  final FavoritesProvider favorites;
  final PostsProvider posts;
  final NotesProvider notes;
  final NotesRepository? notesRepository;
  final VoidCallback? onExit;
  final ProductProvider? products;
  @override
  State<ExamPrepApp> createState() => _ExamPrepAppState();
}

class _ExamPrepAppState extends State<ExamPrepApp> {
  final _navigator = GlobalKey<NavigatorState>();
  bool _handlingBack = false;
  bool _exitRequested = false;
  late String _endpoint;
  String _productEndpoint = '';
  @override
  void initState() {
    super.initState();
    _endpoint = widget.settings.endpoint;
    widget.settings.addListener(_settingsChanged);
    widget.posts.addListener(_postsChanged);
    unawaited(widget.posts.load(_endpoint));
    unawaited(widget.notes.load());
    _syncProducts();
  }

  void _postsChanged() {
    widget.favorites.setSource(
      widget.posts.isSampleData ? 'sample://posts' : _endpoint,
    );
    _syncProducts();
  }

  void _syncProducts() {
    final products = widget.products;
    if (products == null) return;
    var next = '';
    if (!widget.posts.isSampleData && !isReadOnlyDemoEndpoint(_endpoint)) {
      try {
        next = productsEndpoint(_endpoint);
      } on FormatException {
        /* Source has no product collection. */
      }
    }
    if (next == _productEndpoint) return;
    _productEndpoint = next;
    if (next.isEmpty) {
      products.clearEndpoint();
    } else {
      unawaited(products.load(next));
    }
  }

  void _settingsChanged() {
    if (_endpoint != widget.settings.endpoint) {
      _endpoint = widget.settings.endpoint;
      unawaited(widget.posts.load(_endpoint));
    }
  }

  Future<void> _handleSystemBack() async {
    final navigator = _navigator.currentState;
    if (!mounted || navigator == null || _handlingBack || _exitRequested) {
      return;
    }
    _handlingBack = true;
    try {
      // maybePop also returns true when a child PopScope vetoes navigation,
      // such as a note editor waiting for its database write to finish.
      final handled = await navigator.maybePop();
      if (!handled && mounted) {
        _exitRequested = true;
        widget.onExit?.call();
      }
    } finally {
      _handlingBack = false;
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_settingsChanged);
    widget.posts.removeListener(_postsChanged);
    widget.posts.dispose();
    widget.products?.dispose();
    widget.notes.dispose();
    widget.favorites.dispose();
    widget.settings.dispose();
    unawaited(widget.notesRepository?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: widget.settings),
      ChangeNotifierProvider.value(value: widget.favorites),
      ChangeNotifierProvider.value(value: widget.posts),
      if (widget.products != null)
        ChangeNotifierProvider.value(value: widget.products!),
      ChangeNotifierProvider.value(value: widget.notes),
    ],
    child: Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final app = MaterialApp(
          navigatorKey: _navigator,
          title: 'Ôn tập bài 6–7',
          debugShowCheckedModeBanner: false,
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: _StudyShell(
            onExit: widget.onExit,
            hasProducts: widget.products != null,
          ),
        );
        if (widget.onExit == null) return app;
        // Register with the host route outside the inner MaterialApp so its
        // Navigator cannot discard the whole practice section on system Back.
        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_handleSystemBack());
          },
          child: app,
        );
      },
    ),
  );
  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2457A7),
      brightness: brightness,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

class _StudyShell extends StatefulWidget {
  const _StudyShell({this.onExit, required this.hasProducts});
  final VoidCallback? onExit;
  final bool hasProducts;
  @override
  State<_StudyShell> createState() => _StudyShellState();
}

class _StudyShellState extends State<_StudyShell> {
  int _selected = 0;
  static const _titles = [
    'Bài viết',
    'Yêu thích',
    'Ghi chú',
    'Cài đặt',
    'Sản phẩm',
  ];
  List<Widget> get _pages => [
    const PostsScreen(),
    const FavoritesScreen(),
    NotesScreen(onExit: widget.onExit),
    const SettingsScreen(),
    widget.hasProducts
        ? const ProductScreen()
        : const Center(child: Text('Mở backend để luyện API sản phẩm.')),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _selected == 2
        ? null
        : AppBar(
            leading: widget.onExit == null
                ? null
                : IconButton(
                    tooltip: 'Về ứng dụng',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onExit,
                  ),
            title: Text(_titles[_selected]),
            actions: [
              IconButton(
                tooltip: 'Hướng dẫn nhanh',
                icon: const Icon(Icons.help_outline),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Ôn tập bài 6–7'),
                    content: const SingleChildScrollView(
                      child: Text(
                        'Bài viết: API, JSON, tìm kiếm theo ID, thêm, sửa và xóa bài đăng.\n\n'
                        'Sản phẩm: CRUD và tìm tên qua API của backend.\n\n'
                        'Yêu thích: dữ liệu lưu trên máy, xem khi mất mạng.\n\n'
                        'Ghi chú: thêm, đọc, sửa, xóa bằng SQLite.\n\n'
                        'Cài đặt: chọn Backend máy ảo hoặc nhập URL Conveyor.\n\n'
                        'Mất mạng: chọn Dùng dữ liệu mẫu ở trang Bài viết.\n\n'
                        'Xem README.md tại thư mục dự án để biết nơi sửa code theo đề.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đã hiểu'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    body: SafeArea(child: _pages[_selected]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selected,
      onDestinationSelected: (value) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _selected = value);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.article_outlined),
          label: 'Bài viết',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          label: 'Yêu thích',
        ),
        NavigationDestination(icon: Icon(Icons.edit_note), label: 'Ghi chú'),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Cài đặt',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Sản phẩm',
        ),
      ],
    ),
  );
}
