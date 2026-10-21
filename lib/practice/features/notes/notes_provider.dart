import 'package:flutter/foundation.dart';

import 'note.dart';
import 'notes_repository.dart';

/// Chỉ đổi dữ liệu trên màn hình sau khi SQLite xác nhận ghi thành công.
/// Repository được truyền vào và do bên gọi sở hữu/đóng.
class NotesProvider extends ChangeNotifier {
  NotesProvider({required NotesRepository repository})
    : _repository = repository;

  final NotesRepository _repository;
  List<Note> _notes = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;
  String? _error;
  String? _mutationError;

  List<Note> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get mutationError => _mutationError;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || _isLoading || _isSaving) return;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final notes = await _repository.getAll();
      if (!_disposed) _notes = notes;
    } catch (_) {
      if (!_disposed) _error = 'Không thể đọc ghi chú. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (_disposed || _isLoading || _isSaving || _error != null) return false;
    _isSaving = true;
    _mutationError = null;
    _notify();
    try {
      await action();
      return true;
    } on ArgumentError {
      _mutationError = 'Vui lòng nhập tiêu đề ghi chú.';
      return false;
    } catch (_) {
      _mutationError =
          'Không thể lưu thay đổi. Dữ liệu cũ vẫn được giữ. Hãy thử lại.';
      return false;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<bool> save({
    int? id,
    required String title,
    required String content,
    bool isCompleted = false,
  }) => _mutate(() async {
    final saved = id == null
        ? await _repository.create(title: title, content: content)
        : await _repository.update(
            Note(
              id: id,
              title: title,
              content: content,
              isCompleted: isCompleted,
            ),
          );
    if (_disposed) return;
    _notes = [saved, ..._notes.where((note) => note.id != saved.id)]
      ..sort((a, b) => b.id.compareTo(a.id));
  });

  Future<bool> toggleCompleted(Note note) => _mutate(() async {
    final saved = await _repository.update(
      note.copyWith(isCompleted: !note.isCompleted),
    );
    if (_disposed) return;
    _notes = [
      for (final item in _notes)
        if (item.id == saved.id) saved else item,
    ];
  });

  Future<bool> delete(Note note) => _mutate(() async {
    await _repository.delete(note.id);
    if (!_disposed) {
      _notes = _notes.where((item) => item.id != note.id).toList();
    }
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
