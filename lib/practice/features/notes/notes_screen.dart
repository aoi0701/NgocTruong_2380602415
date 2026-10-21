import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'note.dart';
import 'notes_provider.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key, this.onExit});
  final VoidCallback? onExit;

  void _edit(BuildContext context, [Note? note]) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => _NoteEditor(note: note)));
  }

  Future<void> _delete(BuildContext context, Note note) async {
    final provider = context.read<NotesProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: Text('Ghi chú “${note.title}” sẽ bị xóa khỏi thiết bị.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await provider.delete(note);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotesProvider>();
    final busy = provider.isLoading || provider.isSaving;
    return Scaffold(
      appBar: AppBar(
        leading: onExit == null
            ? null
            : IconButton(
                tooltip: 'Về ứng dụng',
                icon: const Icon(Icons.arrow_back),
                onPressed: onExit,
              ),
        title: const Text('Ghi chú SQLite'),
        actions: [
          IconButton(
            tooltip: 'Tải lại ghi chú',
            onPressed: busy ? null : provider.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Thêm ghi chú',
        onPressed: busy || provider.error != null ? null : () => _edit(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (provider.isSaving) const LinearProgressIndicator(),
          if (provider.mutationError case final message?)
            _ErrorMessage(message: message),
          Expanded(child: _body(context, provider)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, NotesProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error case final message?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: provider.load,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (provider.notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.note_add_outlined, size: 56),
              SizedBox(height: 12),
              Text('Chưa có ghi chú'),
              SizedBox(height: 6),
              Text(
                'Nhấn + để tạo ghi chú ôn tập.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        itemCount: provider.notes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final note = provider.notes[index];
          return Card(
            child: Column(
              children: [
                ListTile(
                  onTap: provider.isSaving ? null : () => _edit(context, note),
                  leading: Checkbox(
                    value: note.isCompleted,
                    semanticLabel: 'Hoàn thành ${note.title}',
                    onChanged: provider.isSaving
                        ? null
                        : (_) => provider.toggleCompleted(note),
                  ),
                  title: Text(
                    note.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      decoration: note.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: note.content.isEmpty
                      ? null
                      : Text(
                          note.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          note.isCompleted
                              ? 'Đã hoàn thành'
                              : 'Chưa hoàn thành',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sửa ghi chú',
                        onPressed: provider.isSaving
                            ? null
                            : () => _edit(context, note),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Xóa ghi chú',
                        onPressed: provider.isSaving
                            ? null
                            : () => _delete(context, note),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({this.note});

  final Note? note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late bool _isCompleted;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _content = TextEditingController(text: widget.note?.content ?? '');
    _isCompleted = widget.note?.isCompleted ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final provider = context.read<NotesProvider>();
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await provider.save(
      id: widget.note?.id,
      title: _title.text,
      content: _content.text,
      isCompleted: _isCompleted,
    );
    if (!mounted) return;
    // Cho phép pop sau khi PopScope đã rebuild với canPop=true.
    setState(() {
      _saving = false;
      if (!saved) {
        _error = provider.mutationError ?? 'Đang xử lý. Vui lòng thử lại.';
      }
    });
    if (saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Thêm ghi chú' : 'Sửa ghi chú'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                key: const Key('note-title'),
                controller: _title,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập tiêu đề.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('note-content'),
                controller: _content,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
                minLines: 5,
                maxLines: 12,
              ),
              if (widget.note != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đã hoàn thành'),
                  value: _isCompleted,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isCompleted = value!),
                ),
              const SizedBox(height: 16),
              if (_error case final message?) _ErrorMessage(message: message),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Đang lưu…' : 'Lưu'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    ),
  );
}
