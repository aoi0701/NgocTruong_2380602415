import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/config_url.dart';
import '../models/post_item.dart';
import '../services/api_client.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiClient _apiClient = ApiClient(baseUrl: Config_URL.baseUrl);
  late Future<List<PostItem>> _postsFuture;

  // Quản lý trạng thái tương tác kiểu Facebook (Like & Comment)
  final Map<int, bool> _likedMap = {};
  final Map<int, int> _likeCountMap = {};
  final Map<int, List<String>> _commentsMap = {};

  @override
  void initState() {
    super.initState();
    _postsFuture = fetchPosts();
  }

  /// Lấy danh sách các bài đăng từ GET ${Config_URL.baseUrl}posts
  /// Hỗ trợ fallback sang PostApi nếu backend cấu hình theo tên controller
  Future<List<PostItem>> fetchPosts() async {
    http.Response response = await _apiClient.get('posts');
    if (response.statusCode == 404) {
      response = await _apiClient.get('PostApi');
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      final posts = data
          .map((item) => PostItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Khởi tạo số lượng like ngẫu nhiên ban đầu cho sống động
      for (var post in posts) {
        final id = post.id ?? 0;
        _likeCountMap.putIfAbsent(id, () => (id * 7 + 12) % 45 + 3);
        _commentsMap.putIfAbsent(id, () => ['Bài viết rất hay và hữu ích!', 'Tuyệt vời ạ!']);
      }

      return posts;
    } else {
      throw Exception('Failed to load posts: ${response.statusCode}');
    }
  }

  void _reloadPosts() {
    setState(() {
      _postsFuture = fetchPosts();
    });
  }

  void _toggleLike(int postId) {
    setState(() {
      final isLiked = _likedMap[postId] ?? false;
      _likedMap[postId] = !isLiked;
      final currentCount = _likeCountMap[postId] ?? 0;
      _likeCountMap[postId] = !isLiked ? currentCount + 1 : (currentCount > 0 ? currentCount - 1 : 0);
    });
  }

  // --- Chức năng: Thêm bài đăng mới (POST) ---
  void _showAddPostDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text('Tạo bài viết mới', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề bài viết (*)',
                  hintText: 'Nhập tiêu đề...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nội dung chia sẻ (*)',
                  hintText: 'Bạn đang nghĩ gì thế?...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();

              if (title.isEmpty || body.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập cả tiêu đề và nội dung bài viết'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              await _createPost(title, body);
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Đăng bài'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPost(String title, String body) async {
    try {
      final Map<String, dynamic> postData = {
        'title': title,
        'body': body,
        'userId': 1,
      };

      http.Response response = await _apiClient.post('posts', body: postData);
      if (response.statusCode == 404) {
        response = await _apiClient.post('PostApi', body: postData);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã đăng bài viết thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _reloadPosts();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi đăng bài: ${response.statusCode} - ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối máy chủ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Chức năng: Sửa bài đăng (PUT) ---
  void _showEditPostDialog(PostItem post) {
    final titleController = TextEditingController(text: post.title ?? '');
    final bodyController = TextEditingController(text: post.body ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Chỉnh sửa bài viết #${post.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề (*)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nội dung (*)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();

              if (title.isEmpty || body.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tiêu đề và nội dung không được để trống'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              await _updatePost(post.id ?? 0, title, body, post.userId ?? 1);
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePost(int id, String title, String body, int userId) async {
    try {
      final Map<String, dynamic> postData = {
        'id': id,
        'title': title,
        'body': body,
        'userId': userId,
      };

      http.Response response = await _apiClient.put('posts/$id', body: postData);
      if (response.statusCode == 404) {
        response = await _apiClient.put('PostApi/$id', body: postData);
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật bài viết thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _reloadPosts();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi cập nhật bài viết: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối máy chủ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Chức năng: Xóa bài đăng (DELETE) ---
  void _confirmDeletePost(PostItem post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa bài viết'),
        content: Text(
          'Bạn có chắc chắn muốn xóa bài viết "${post.title ?? 'N/A'}" không? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deletePost(post.id ?? 0);
            },
            child: const Text('Xóa bài', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(int id) async {
    try {
      http.Response response = await _apiClient.delete('posts/$id');
      if (response.statusCode == 404) {
        response = await _apiClient.delete('PostApi/$id');
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa bài viết thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _reloadPosts();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa bài viết: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối máy chủ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Chức năng: Mở bình luận bài viết ---
  void _showCommentsBottomSheet(PostItem post) {
    final commentController = TextEditingController();
    final postId = post.id ?? 0;
    final comments = _commentsMap[postId] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SizedBox(
            height: 450,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bình luận (${comments.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Divider(),
                Expanded(
                  child: comments.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có bình luận nào. Hãy là người đầu tiên!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: comments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade200,
                                  child: Text(
                                    'U${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Người dùng Facebook',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(comments[index]),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Viết bình luận...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: () {
                          final text = commentController.text.trim();
                          if (text.isNotEmpty) {
                            setModalState(() {
                              comments.add(text);
                              _commentsMap[postId] = comments;
                            });
                            setState(() {});
                            commentController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Màu nền xám nhạt đặc trưng của Facebook
      appBar: AppBar(
        title: const Text(
          'Bảng tin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _reloadPosts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reloadPosts(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Hộp "Bạn đang nghĩ gì thế?" kiểu Facebook
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue.shade700,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _showAddPostDialog,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'Bạn đang nghĩ gì thế?...',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton.icon(
                          onPressed: _showAddPostDialog,
                          icon: const Icon(Icons.videocam, color: Colors.red),
                          label: const Text(
                            'Phát trực tiếp',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddPostDialog,
                          icon: const Icon(Icons.photo_library, color: Colors.green),
                          label: const Text(
                            'Ảnh/video',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddPostDialog,
                          icon: const Icon(Icons.mood, color: Colors.amber),
                          label: const Text(
                            'Cảm xúc',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Danh sách bài đăng Facebook
              FutureBuilder<List<PostItem>>(
                future: _postsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _reloadPosts,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Text(
                          'Chưa có bài đăng nào. Hãy đăng bài đầu tiên!',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    );
                  } else {
                    final posts = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final postId = post.id ?? index;
                        final isLiked = _likedMap[postId] ?? false;
                        final likeCount = _likeCountMap[postId] ?? 0;
                        final comments = _commentsMap[postId] ?? [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header bài đăng: Avatar, Tác giả, Thời gian & Menu
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.blue.shade100,
                                      child: Text(
                                        post.userId != null
                                            ? 'U${post.userId}'
                                            : 'FB',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Người dùng #${post.userId ?? post.id ?? index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '${(index + 1) * 3} giờ trước · ',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Icon(
                                                Icons.public,
                                                size: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_horiz),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showEditPostDialog(post);
                                        } else if (val == 'delete') {
                                          _confirmDeletePost(post);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit,
                                                  color: Colors.blue, size: 20),
                                              SizedBox(width: 8),
                                              Text('Chỉnh sửa'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color: Colors.red, size: 20),
                                              SizedBox(width: 8),
                                              Text('Xóa bài'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Tiêu đề & Nội dung bài đăng
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                child: Text(
                                  post.title ?? 'Không có tiêu đề',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                child: Text(
                                  post.body ?? 'Không có nội dung',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Thống kê tương tác (Lượt like & Bình luận)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.thumb_up,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$likeCount',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${comments.length} bình luận',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1),

                              // Thanh nút tương tác Facebook: Thích - Bình luận - Chia sẻ
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _toggleLike(postId),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isLiked
                                                  ? Icons.thumb_up
                                                  : Icons.thumb_up_alt_outlined,
                                              size: 18,
                                              color: isLiked
                                                  ? Colors.blue.shade700
                                                  : Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Thích',
                                              style: TextStyle(
                                                fontWeight: isLiked
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isLiked
                                                    ? Colors.blue.shade700
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showCommentsBottomSheet(post),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.chat_bubble_outline,
                                              size: 18,
                                              color: Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Bình luận',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Đã chia sẻ bài viết lên Bảng tin của bạn!',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.share_outlined,
                                              size: 18,
                                              color: Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Chia sẻ',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tạo bài viết',
        onPressed: _showAddPostDialog,
        child: const Icon(Icons.post_add),
      ),
    );
  }
}
