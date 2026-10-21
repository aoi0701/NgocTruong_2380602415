import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ngoc_truong_2380602415/HomeScreen.dart';
import 'package:ngoc_truong_2380602415/main.dart' as app;
import 'package:ngoc_truong_2380602415/practice/app.dart';
import 'package:ngoc_truong_2380602415/practice/features/notes/notes_provider.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/post.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/posts_provider.dart';
import 'package:ngoc_truong_2380602415/practice/features/settings/favorites_provider.dart';
import 'package:ngoc_truong_2380602415/practice/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Chạy trên Android: không mock HTTP, SharedPreferences, path_provider hay SQLite.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'original app opens practice and retains native storage after restart',
    (tester) async {
      final token = 'smoke-${DateTime.now().microsecondsSinceEpoch}';
      final title = 'Ôn SQLite $token';
      final editedTitle = 'Đã sửa $token';
      const content = "Truong's note; DROP TABLE notes; -- Tiếng Việt";
      NotesProvider? notes;
      FavoritesProvider? favorites;
      SettingsProvider? settings;
      Post? selectedPost;
      Post? originalFavorite;
      bool? originalDarkMode;

      try {
        await _launchPractice(tester);
        notes = _read<NotesProvider>(tester);
        favorites = _read<FavoritesProvider>(tester);
        settings = _read<SettingsProvider>(tester);
        originalDarkMode = settings.darkMode;
        await _waitUntil(tester, () => !notes!.isLoading);
        expect(notes.error, isNull);

        // Hành động mẫu rõ ràng: không phụ thuộc mạng hoặc dữ liệu API lúc khởi động.
        final posts = _read<PostsProvider>(tester);
        posts.loadSampleData();
        selectedPost = posts.posts.firstWhere(
          (post) => !favorites!.contains(post.id),
          orElse: () => posts.posts.first,
        );
        final previous = favorites.favorites.where(
          (post) => post.id == selectedPost!.id,
        );
        if (previous.isNotEmpty) originalFavorite = previous.single;
        await tester.pumpAndSettle();

        // Đi qua UI chi tiết để lưu snapshot yêu thích, bất kể thứ tự danh sách.
        await tester.ensureVisible(find.text(selectedPost.title));
        await tester.tap(find.text(selectedPost.title));
        await tester.pumpAndSettle();
        if (favorites.contains(selectedPost.id)) {
          await tester.tap(find.byTooltip('Bỏ yêu thích'));
          await _waitUntil(
            tester,
            () => !favorites!.contains(selectedPost!.id),
          );
        }
        await tester.tap(find.byTooltip('Thêm yêu thích'));
        await _waitUntil(tester, () => favorites!.contains(selectedPost!.id));
        await tester.pageBack();
        await tester.pumpAndSettle();
        await _tab(tester, 'Yêu thích');
        expect(find.text(selectedPost.title), findsOneWidget);

        await _tab(tester, 'Ghi chú');
        await tester.tap(find.byTooltip('Thêm ghi chú'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('note-title')), title);
        await tester.enterText(find.byKey(const Key('note-content')), content);
        await _saveNote(tester, notes, title);
        expect(find.text(title), findsOneWidget);

        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('note-title')),
          editedTitle,
        );
        await _saveNote(tester, notes, editedTitle);
        final row = find.ancestor(
          of: find.text(editedTitle),
          matching: find.byType(ListTile),
        );
        await tester.tap(
          find.descendant(of: row, matching: find.byType(Checkbox)),
        );
        await _waitUntil(tester, () => !notes!.isSaving);
        final savedNote = notes.notes.singleWhere(
          (note) => note.title == editedTitle,
        );
        expect(savedNote.content, content);
        expect(savedNote.isCompleted, isTrue);

        await _tab(tester, 'Cài đặt');
        // Cả trường hợp thiết bị vốn đã bật tối cũng thực sự ghi qua UI.
        if (settings.darkMode) {
          await tester.tap(find.byType(Switch));
          await _waitUntil(tester, () => !settings!.darkMode);
        }
        await tester.tap(find.byType(Switch));
        await _waitUntil(tester, () => settings!.darkMode);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(SwitchListTile))).brightness,
          Brightness.dark,
        );

        // Chờ đóng SQLite trước khi dựng lại; dispose của app cũng gọi close().
        final oldApp = tester.widget<ExamPrepApp>(find.byType(ExamPrepApp));
        await oldApp.notesRepository!.close();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        notes = null;
        favorites = null;
        settings = null;
        // Buộc SharedPreferences đọc lại plugin thật thay vì chỉ tin cache Dart.
        await (await SharedPreferences.getInstance()).reload();
        await _launchPractice(tester);
        notes = _read<NotesProvider>(tester);
        favorites = _read<FavoritesProvider>(tester);
        settings = _read<SettingsProvider>(tester);
        _read<PostsProvider>(tester).loadSampleData();
        await _waitUntil(tester, () => !notes!.isLoading);
        await tester.pumpAndSettle();

        expect(notes.error, isNull);
        expect(
          notes.notes.singleWhere((note) => note.id == savedNote.id).title,
          editedTitle,
        );
        expect(
          notes.notes.singleWhere((note) => note.id == savedNote.id).content,
          content,
        );
        expect(
          notes.notes
              .singleWhere((note) => note.id == savedNote.id)
              .isCompleted,
          isTrue,
        );
        final restored = favorites.favorites.singleWhere(
          (post) => post.id == selectedPost!.id,
        );
        expect(restored.toJson(), selectedPost.toJson());
        expect(settings.darkMode, isTrue);

        await _tab(tester, 'Yêu thích');
        expect(find.text(selectedPost.title), findsOneWidget);
        await _tab(tester, 'Ghi chú');
        expect(find.text(editedTitle), findsOneWidget);
        await _tab(tester, 'Cài đặt');
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        expect(
          Theme.of(tester.element(find.byType(SwitchListTile))).brightness,
          Brightness.dark,
        );
        expect(tester.takeException(), isNull);
      } finally {
        // Chỉ xóa ghi chú của lần chạy này; giữ nguyên dữ liệu có sẵn trên máy.
        if (notes != null) {
          for (final note
              in notes.notes
                  .where((note) => note.title.contains(token))
                  .toList()) {
            expect(await notes.delete(note), isTrue);
          }
        }
        if (favorites != null && selectedPost != null) {
          if (favorites.contains(selectedPost.id)) {
            await favorites.toggle(selectedPost);
          }
          if (originalFavorite != null) {
            await favorites.toggle(originalFavorite);
          }
        }
        if (settings != null && originalDarkMode != null) {
          await settings.setDarkMode(originalDarkMode);
        }
      }

      // Thoát bằng nút sản phẩm, xác nhận trở về ứng dụng cũ và các tab cũ còn dùng được.
      await tester.tap(find.byTooltip('Về ứng dụng'));
      await _waitUntil(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExamPrepApp), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const Key('practice-entry')), findsOneWidget);
      expect(
        tester.widget<GButton>(find.byKey(const Key('practice-entry'))).active,
        isFalse,
      );
      expect(
        tester
            .widget<GButton>(
              find.byWidgetPredicate(
                (widget) => widget is GButton && widget.text == 'Chuyển đổi',
              ),
            )
            .active,
        isTrue,
      );
      expect(find.text('Công cụ chuyển đổi'), findsOneWidget);
      expect(find.text('Nhập nhiệt độ:'), findsOneWidget);
      await tester.tap(find.text('Đơn vị đo'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập giá trị:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _launchPractice(WidgetTester tester) async {
  app.main(); // Entry gốc khởi tạo Alarm và mở HomeScreen có sáu tab cũ.
  final entry = find.byKey(const Key('practice-entry'));
  await _waitUntil(tester, () => entry.evaluate().isNotEmpty);
  expect(find.byType(HomeScreen), findsOneWidget);
  // Thanh GNav cuộn ngang: mục thứ bảy có thể nằm ngoài viewport điện thoại.
  await tester.ensureVisible(entry);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(entry);
  await _waitUntil(
    tester,
    () => find.byType(NavigationBar).evaluate().isNotEmpty,
  );
}

T _read<T>(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar)).read<T>();

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveNote(
  WidgetTester tester,
  NotesProvider notes,
  String title,
) async {
  // Đóng bàn phím để nút lưu nằm trong vùng nhìn thấy trên thiết bị nhỏ.
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
  final save = find.widgetWithText(FilledButton, 'Lưu');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _waitUntil(tester, () => !notes.isSaving);
  await tester.pumpAndSettle();
  expect(notes.mutationError, isNull);
  expect(notes.notes.any((note) => note.title == title), isTrue);
}

Future<void> _waitUntil(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Tác vụ native chưa hoàn tất sau 30 giây.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}
