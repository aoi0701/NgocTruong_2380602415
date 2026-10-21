import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/posts/post.dart';
import '../features/posts/posts_provider.dart';
import '../features/settings/favorites_provider.dart';
import '../features/settings/settings_provider.dart';
import 'post_editor_screen.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});
  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final _search = TextEditingController();
  final _lookupId = TextEditingController();
  String? _idError;
  static const _queryStorageKey = ValueKey('posts-search-query');
  bool _restoredSearch = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredSearch) return;
    _restoredSearch = true;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _queryStorageKey);
    if (saved is String) _search.text = saved;
  }

  void _setQuery(String value) {
    PageStorage.maybeOf(
      context,
    )?.writeState(context, value, identifier: _queryStorageKey);
    context.read<PostsProvider>().setQuery(value);
  }

  @override
  void dispose() {
    _search.dispose();
    _lookupId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PostsProvider>();
    final endpoint = context.watch<SettingsProvider>().endpoint;
    return RefreshIndicator(
      onRefresh: () => state.load(endpoint),
      child: CustomScrollView(
        key: const PageStorageKey('posts-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (state.canWrite)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        onPressed: !state.canWrite || state.isSaving
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<Post>(
                                  builder: (_) => PostEditorScreen(
                                    sourceVersion: state.sourceVersion,
                                  ),
                                ),
                              ),
                        label: const Text('Tạo bài viết'),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: _setQuery,
                    decoration: InputDecoration(
                      labelText: 'Tìm tiêu đề hoặc nội dung',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _setQuery('');
                        },
                      ),
                    ),
                  ),
                ),
                if (state.canWrite)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      key: const Key('post-lookup-id'),
                      controller: _lookupId,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _findById(state),
                      decoration: InputDecoration(
                        labelText: 'Tìm bài viết theo ID trên máy chủ',
                        errorText: _idError ?? state.lookupError,
                        suffixIcon: state.isLookingUp
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Tìm theo ID',
                                icon: const Icon(Icons.manage_search),
                                onPressed: state.isLoading || state.isSampleData
                                    ? null
                                    : () => _findById(state),
                              ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${state.visiblePosts.length} / ${state.posts.length} bài viết${state.canWrite ? '' : ' • Chỉ đọc'}',
                        ),
                      ),
                      if (!state.canWrite) ...[
                        const Tooltip(
                          message:
                              'Dữ liệu mẫu và JSONPlaceholder chỉ đọc. Chọn backend trong Cài đặt để thêm, sửa, xóa.',
                          child: Icon(Icons.lock_outline, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Tìm theo ID',
                          icon: state.isLookingUp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.manage_search),
                          onPressed:
                              state.isSampleData ||
                                  state.isLoading ||
                                  state.isLookingUp
                              ? null
                              : () => _lookupDialog(state),
                        ),
                      ],
                      IconButton(
                        tooltip: state.sortAscending
                            ? 'Sắp xếp Z–A'
                            : 'Sắp xếp A–Z',
                        onPressed: () =>
                            state.setSortAscending(!state.sortAscending),
                        icon: Icon(
                          state.sortAscending ? Icons.south : Icons.north,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tải lại API',
                        onPressed: state.isLoading
                            ? null
                            : () => state.load(endpoint),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                if (!state.canWrite && (_idError ?? state.lookupError) != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      (_idError ?? state.lookupError)!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (state.isSampleData)
                  const _StatusBanner(
                    text: 'Dữ liệu mẫu • Không phải dữ liệu API',
                    icon: Icons.science_outlined,
                  ),
              ],
            ),
          ),
          _content(state, endpoint),
        ],
      ),
    );
  }

  Widget _content(PostsProvider state, String endpoint) {
    if (state.isLoading) {
      return SliverToBoxAdapter(
        child: _MessagePanel(
          scrollable: false,
          title: 'Đang tải bài viết…',
          icon: Icons.cloud_download_outlined,
          progress: true,
          actions: [
            TextButton(
              onPressed: state.loadSampleData,
              child: const Text('Dùng dữ liệu mẫu'),
            ),
          ],
        ),
      );
    }
    if (state.error != null) {
      return SliverToBoxAdapter(
        child: _MessagePanel(
          scrollable: false,
          title: 'Không tải được dữ liệu',
          message: state.error,
          icon: Icons.cloud_off_outlined,
          actions: [
            FilledButton(
              onPressed: () => state.load(endpoint),
              child: const Text('Thử lại'),
            ),
            TextButton(
              onPressed: state.loadSampleData,
              child: const Text('Dùng dữ liệu mẫu'),
            ),
          ],
        ),
      );
    }
    if (state.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: _MessagePanel(
          scrollable: false,
          title: 'API chưa có bài viết.',
          icon: Icons.inbox_outlined,
          actions: [
            TextButton(
              onPressed: state.loadSampleData,
              child: const Text('Dùng dữ liệu mẫu'),
            ),
          ],
        ),
      );
    }
    if (state.visiblePosts.isEmpty) {
      return const SliverToBoxAdapter(
        child: _MessagePanel(
          scrollable: false,
          title: 'Không tìm thấy bài viết phù hợp.',
          icon: Icons.search_off,
        ),
      );
    }
    final visiblePosts = state.visiblePosts;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => PostTile(
            post: visiblePosts[index],
            sourceVersion: state.sourceVersion,
          ),
          childCount: visiblePosts.length,
        ),
      ),
    );
  }

  Future<void> _findById(PostsProvider state) async {
    if (state.isLookingUp) return;
    final id = int.tryParse(_lookupId.text.trim());
    setState(
      () => _idError = id == null || id <= 0
          ? 'ID phải là số nguyên lớn hơn 0.'
          : null,
    );
    if (_idError != null) return;
    final source = state.sourceVersion;
    final post = await state.findPost(id!);
    if (!mounted || post == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(post: post, sourceVersion: source),
      ),
    );
  }

  Future<void> _lookupDialog(PostsProvider state) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tìm bài viết theo ID'),
        content: TextField(
          controller: _lookupId,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'ID bài viết'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tìm'),
          ),
        ],
      ),
    );
    if (mounted && accepted == true) await _findById(state);
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>().favorites;
    if (favorites.isEmpty) {
      return const _MessagePanel(
        icon: Icons.favorite_border,
        title: 'Chưa có bài viết yêu thích.',
        message:
            'Bấm trái tim ở danh sách hoặc trang chi tiết để lưu bài viết trên máy.',
      );
    }
    return Column(
      children: [
        const _StatusBanner(
          text: 'Đã lưu trên máy • Có thể xem khi mất mạng',
          icon: Icons.offline_pin_outlined,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: favorites.length,
            itemBuilder: (context, index) => PostTile(post: favorites[index]),
          ),
        ),
      ],
    );
  }
}

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, this.sourceVersion});
  final Post post;
  final int? sourceVersion;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bài #${post.id} · Người dùng #${post.userId}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(post.body, maxLines: 4, overflow: TextOverflow.ellipsis),
      ),
      trailing: FavoriteButton(post: post),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PostDetailScreen(post: post, sourceVersion: sourceVersion),
        ),
      ),
    ),
  );
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post, this.sourceVersion});
  final Post post;
  final int? sourceVersion;
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post = widget.post;
  bool _deleting = false;
  String? _error;

  Future<void> _edit(PostsProvider provider) async {
    final result = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) =>
            PostEditorScreen(post: _post, sourceVersion: widget.sourceVersion!),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _post = result;
        _error = null;
      });
    }
  }

  Future<void> _delete(PostsProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài viết?'),
        content: Text('Bài #${_post.id} sẽ bị xóa khỏi máy chủ.'),
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
    if (!mounted || confirm != true) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final success = await provider.deletePost(
      _post.id,
      expectedSource: widget.sourceVersion,
    );
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _error = success
          ? null
          : provider.mutationError ??
                'Nguồn dữ liệu đã đổi. Mở lại bài viết từ nguồn hiện tại.';
    });
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostsProvider>();
    final canEdit =
        provider.canWrite &&
        widget.sourceVersion != null &&
        widget.sourceVersion == provider.sourceVersion;
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết bài viết'),
          actions: [
            if (canEdit) ...[
              IconButton(
                tooltip: 'Sửa bài viết',
                icon: const Icon(Icons.edit_outlined),
                onPressed: provider.isSaving || _deleting
                    ? null
                    : () => _edit(provider),
              ),
              IconButton(
                tooltip: 'Xóa bài viết',
                icon: const Icon(Icons.delete_outline),
                onPressed: provider.isSaving || _deleting
                    ? null
                    : () => _delete(provider),
              ),
            ],
            FavoriteButton(post: _post),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_deleting) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Text(
                      'Bài #${_post.id} · Người dùng #${_post.userId}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      _post.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    SelectableText(
                      _post.body,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.post});
  final Post post;
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _saving = false;
  Future<void> _toggle() async {
    setState(() => _saving = true);
    try {
      await context.read<FavoritesProvider>().toggle(widget.post);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được yêu thích: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<FavoritesProvider>().contains(widget.post.id);
    return IconButton(
      tooltip: saved ? 'Bỏ yêu thích' : 'Thêm yêu thích',
      onPressed: _saving ? null : _toggle,
      icon: _saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              color: saved ? Theme.of(context).colorScheme.primary : null,
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    this.message,
    this.progress = false,
    this.actions = const [],
    this.scrollable = true,
  });
  final IconData icon;
  final String title;
  final String? message;
  final bool progress;
  final List<Widget> actions;
  final bool scrollable;
  @override
  Widget build(BuildContext context) => Center(
    child: scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _body(context),
          )
        : Padding(padding: const EdgeInsets.all(24), child: _body(context)),
  );

  Widget _body(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress)
          const CircularProgressIndicator()
        else
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(message!, textAlign: TextAlign.center),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: actions,
          ),
        ],
      ],
    ),
  );
}
