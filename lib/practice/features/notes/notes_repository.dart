import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'note.dart';

/// Sở hữu kết nối SQLite. Bên tạo repository phải gọi [close] khi kết thúc.
class NotesRepository {
  NotesRepository({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath;

  final DatabaseFactory _factory;
  final String? _databasePath;
  Future<Database>? _opening;

  Future<Database> _database() async {
    final existing = _opening;
    if (existing != null) return existing;
    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } catch (_) {
      // Mở thất bại không được giữ Future lỗi: nút thử lại phải mở lại được.
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    String path;
    if (_databasePath != null) {
      path = _databasePath;
    } else {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      path = p.join(directory.path, 'exam_notes.db');
    }
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL CHECK(length(trim(title)) > 0),
              content TEXT NOT NULL DEFAULT '',
              is_completed INTEGER NOT NULL DEFAULT 0
                CHECK(is_completed IN (0, 1))
            )
          ''');
        },
      ),
    );
  }

  String _validateTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Vui lòng nhập tiêu đề.');
    }
    return normalized;
  }

  Future<List<Note>> getAll() async {
    final database = await _database();
    final rows = await database.query('notes', orderBy: 'id DESC');
    return rows.map(Note.fromMap).toList(growable: false);
  }

  Future<Note> create({required String title, required String content}) async {
    final normalized = _validateTitle(title);
    final database = await _database();
    final id = await database.insert('notes', {
      'title': normalized,
      'content': content,
      'is_completed': 0,
    });
    return Note(id: id, title: normalized, content: content);
  }

  Future<Note> update(Note note) async {
    final normalized = note.copyWith(title: _validateTitle(note.title));
    final database = await _database();
    final count = await database.update(
      'notes',
      normalized.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    if (count != 1) throw StateError('Ghi chú không còn tồn tại.');
    return normalized;
  }

  Future<void> delete(int id) async {
    final database = await _database();
    final count = await database.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('Ghi chú không còn tồn tại.');
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening == null) return;
    Database database;
    try {
      database = await opening;
    } catch (_) {
      return; // Một lần mở lỗi chưa tạo ra kết nối để đóng.
    }
    await database.close();
  }
}
