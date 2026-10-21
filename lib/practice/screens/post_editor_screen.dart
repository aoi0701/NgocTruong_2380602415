import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/posts/post.dart';
import '../features/posts/posts_provider.dart';

class PostEditorScreen extends StatefulWidget {
  const PostEditorScreen({super.key, this.post, required this.sourceVersion});
  final Post? post;
  final int sourceVersion;
  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _userId = TextEditingController(
    text: '${widget.post?.userId ?? 1}',
  );
  late final _title = TextEditingController(text: widget.post?.title ?? '');
  late final _body = TextEditingController(text: widget.post?.body ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _userId.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = context.read<PostsProvider>();
    final post = widget.post;
    final result = post == null
        ? await provider.createPost(
            userId: int.parse(_userId.text.trim()),
            title: _title.text,
            body: _body.text,
            expectedSource: widget.sourceVersion,
          )
        : await provider.updatePost(
            Post(
              id: post.id,
              userId: int.parse(_userId.text.trim()),
              title: _title.text,
              body: _body.text,
            ),
            expectedSource: widget.sourceVersion,
          );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = result == null
          ? provider.mutationError ??
                'Nguồn dữ liệu đã đổi. Mở lại biểu mẫu từ nguồn hiện tại.'
          : null;
    });
    if (result != null) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostsProvider>();
    final sourceChanged = provider.sourceVersion != widget.sourceVersion;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.post == null ? 'Tạo bài viết' : 'Sửa bài viết'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.post != null)
                        Text('Bài #${widget.post!.id} • ID do máy chủ quản lý'),
                      if (sourceChanged)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Nguồn dữ liệu đã đổi. Quay lại và mở biểu mẫu mới.',
                          ),
                        ),
                      TextFormField(
                        key: const Key('post-user-id'),
                        controller: _userId,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ID người dùng',
                        ),
                        validator: (v) =>
                            (int.tryParse(v?.trim() ?? '') ?? 0) > 0
                            ? null
                            : 'ID người dùng phải là số nguyên lớn hơn 0.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('post-title'),
                        controller: _title,
                        enabled: !_saving,
                        maxLength: 200,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Tiêu đề'),
                        validator: (v) =>
                            v == null ||
                                v.trim().isEmpty ||
                                v.trim().length > 200
                            ? 'Nhập tiêu đề (1–200 ký tự).'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('post-body'),
                        controller: _body,
                        enabled: !_saving,
                        maxLength: 5000,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung',
                        ),
                        validator: (v) =>
                            v == null ||
                                v.trim().isEmpty ||
                                v.trim().length > 5000
                            ? 'Nhập nội dung (1–5000 ký tự).'
                            : null,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('post-save'),
                        onPressed:
                            _saving ||
                                provider.isSaving ||
                                sourceChanged ||
                                !provider.canWrite
                            ? null
                            : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Đang lưu…' : 'Lưu bài viết'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
