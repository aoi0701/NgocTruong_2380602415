import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Nhom_3_nguoi/practice/features/notes/note.dart';
import 'package:Nhom_3_nguoi/practice/features/notes/notes_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/notes/notes_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporaryDirectory;
  late String databasePath;
  late NotesRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('exam_notes_');
    databasePath = p.join(temporaryDirectory.path, 'notes.db');
    repository = NotesRepository(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
  });

  tearDown(() async {
    await repository.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'SQLite creates, reads, updates completion and deletes records',
    () async {
      expect(await repository.getAll(), isEmpty);
      final created = await repository.create(
        title: '  Ôn Flutter  ',
        content: 'SQLite',
      );
      expect(created.id, greaterThan(0));
      expect(created.title, 'Ôn Flutter');
      expect(created.isCompleted, isFalse);

      final edited = await repository.update(
        created.copyWith(
          title: 'Ôn Provider',
          content: 'Đã học',
          isCompleted: true,
        ),
      );
      final rows = await repository.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.id, created.id);
      expect(rows.single.title, 'Ôn Provider');
      expect(rows.single.content, 'Đã học');
      expect(rows.single.isCompleted, isTrue);
      expect(edited.isCompleted, isTrue);

      await repository.delete(created.id);
      expect(await repository.getAll(), isEmpty);
    },
  );

  test('blank titles cannot create or overwrite a note', () async {
    await expectLater(
      repository.create(title: ' \n ', content: ''),
      throwsArgumentError,
    );
    final note = await repository.create(title: 'Giữ lại', content: '');
    await expectLater(
      repository.update(note.copyWith(title: '\t ')),
      throwsArgumentError,
    );
    expect((await repository.getAll()).single.title, 'Giữ lại');
  });

  test('apostrophes and SQL-looking text stay literal data', () async {
    const title = "Truong's note'); DROP TABLE notes; --";
    const content = "UPDATE notes SET title = 'hacked'; Tiếng Việt 😀";
    final note = await repository.create(title: title, content: content);
    expect((await repository.getAll()).single.title, title);
    await repository.update(
      note.copyWith(content: "It's safe; DELETE FROM notes;"),
    );
    expect(
      (await repository.getAll()).single.content,
      "It's safe; DELETE FROM notes;",
    );
    await repository.create(title: 'Bảng vẫn tồn tại', content: '');
    expect(await repository.getAll(), hasLength(2));
  });

  test('reopening the actual file retains completion and content', () async {
    final note = await repository.create(title: 'Ngày mai', content: 'Bài 6–7');
    await repository.update(note.copyWith(isCompleted: true));
    await repository.close();
    repository = NotesRepository(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final restored = (await repository.getAll()).single;
    expect(restored.id, note.id);
    expect(restored.title, 'Ngày mai');
    expect(restored.content, 'Bài 6–7');
    expect(restored.isCompleted, isTrue);
  });

  test('missing note updates and deletions report failure', () async {
    await expectLater(
      repository.update(const Note(id: 999, title: 'Missing', content: '')),
      throwsStateError,
    );
    await expectLater(repository.delete(999), throwsStateError);
  });

  test('provider keeps saved state when SQLite rejects mutations', () async {
    final original = await repository.create(
      title: 'Bản gốc',
      content: 'Không mất',
    );
    final provider = NotesProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();
    final connection = await databaseFactoryFfi.openDatabase(databasePath);
    await connection.execute('PRAGMA query_only = ON');
    addTearDown(() => connection.execute('PRAGMA query_only = OFF'));

    expect(
      await provider.save(id: original.id, title: 'Sửa lỗi', content: 'Mới'),
      isFalse,
    );
    expect(provider.notes.single.title, 'Bản gốc');
    expect(provider.mutationError, isNotNull);
    expect(provider.isSaving, isFalse);
    expect(await provider.toggleCompleted(original), isFalse);
    expect(provider.notes.single.isCompleted, isFalse);
    expect(await provider.delete(original), isFalse);
    expect(provider.notes, hasLength(1));

    await connection.execute('PRAGMA query_only = OFF');
    expect(
      await provider.save(id: original.id, title: 'Thành công', content: 'Mới'),
      isTrue,
    );
    expect(provider.notes.single.title, 'Thành công');
    expect(provider.mutationError, isNull);
  });

  test('provider load exposes an error and retry recovers', () async {
    await File(databasePath).writeAsString('not a sqlite database');
    final provider = NotesProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
    await repository.close();
    await File(databasePath).delete();
    await provider.load();
    expect(provider.error, isNull);
    expect(provider.notes, isEmpty);
  });

  test(
    'provider blocks mutations after failed load until retry succeeds',
    () async {
      await File(databasePath).writeAsString('not a sqlite database');
      final provider = NotesProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.load();
      expect(provider.error, isNotNull);
      await repository.close();
      await File(databasePath).delete();

      // Storage is writable now, but the provider has not recovered the full list.
      expect(await provider.save(title: 'Chưa được tải', content: ''), isFalse);
      expect(await repository.getAll(), isEmpty);
      expect(provider.error, isNotNull);

      await provider.load();
      expect(provider.error, isNull);
      expect(await provider.save(title: 'Đã tải lại', content: ''), isTrue);
      expect((await repository.getAll()).single.title, 'Đã tải lại');
    },
  );

  test('provider publishes durable CRUD and rejects duplicate save', () async {
    final provider = NotesProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();
    final first = provider.save(title: 'Một lần', content: '');
    final duplicate = provider.save(title: 'Một lần', content: '');
    expect(await duplicate, isFalse);
    expect(await first, isTrue);
    expect(await repository.getAll(), hasLength(1));
    final note = provider.notes.single;
    expect(await provider.toggleCompleted(note), isTrue);
    expect(provider.notes.single.isCompleted, isTrue);
    expect(await provider.delete(provider.notes.single), isTrue);
    expect(provider.notes, isEmpty);
    expect(await repository.getAll(), isEmpty);
  });

  test(
    'disposing during a pending load or save does not notify listeners',
    () async {
      final provider = NotesProvider(repository: repository);
      final load = provider.load();
      provider.dispose();
      await load;
      final another = NotesProvider(repository: repository);
      final save = another.save(title: 'An toàn', content: '');
      another.dispose();
      await save;
      expect((await repository.getAll()).single.title, 'An toàn');
    },
  );
}
