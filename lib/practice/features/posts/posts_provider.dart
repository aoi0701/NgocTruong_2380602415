import 'package:flutter/foundation.dart';

import '../shared/api_endpoint.dart';
import 'post.dart';
import 'post_api.dart';

class PostsProvider extends ChangeNotifier {
  PostsProvider({required PostApi api}) : _api = api;

  final PostApi _api;
  List<Post> _posts = const [];
  bool _isLoading = false;
  String? _error;
  bool _isSampleData = false;
  String _query = '';
  bool _sortAscending = true;
  int _requestId = 0;
  bool _disposed = false;
  String? _endpoint;
  bool _isSaving = false;
  String? _mutationError;
  bool _isLookingUp = false;
  String? _lookupError;
  int _lookupId = 0;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSampleData => _isSampleData;
  bool get sortAscending => _sortAscending;
  String? get endpoint => _endpoint;
  int get sourceVersion => _requestId;
  bool get isSaving => _isSaving;
  String? get mutationError => _mutationError;
  bool get isLookingUp => _isLookingUp;
  String? get lookupError => _lookupError;
  bool get canWrite =>
      !_disposed &&
      !_isSampleData &&
      !_isLoading &&
      _endpoint != null &&
      !isReadOnlyDemoEndpoint(_endpoint!);

  void _resetOperations() {
    _isSaving = false;
    _mutationError = null;
    _isLookingUp = false;
    _lookupError = null;
    ++_lookupId;
  }

  List<Post> get visiblePosts {
    final result = _posts
        .where(
          (post) =>
              post.title.toLowerCase().contains(_query) ||
              post.body.toLowerCase().contains(_query),
        )
        .toList();
    result.sort((first, second) {
      final byTitle = first.title.toLowerCase().compareTo(
        second.title.toLowerCase(),
      );
      final order = byTitle == 0 ? first.id.compareTo(second.id) : byTitle;
      return _sortAscending ? order : -order;
    });
    return List<Post>.unmodifiable(result);
  }

  Future<void> load(String endpoint) async {
    if (_disposed) return;
    final request = ++_requestId;
    _endpoint = endpoint;
    _resetOperations();
    _isLoading = true;
    _error = null;
    _isSampleData = false;
    _posts = const [];
    notifyListeners();
    try {
      final result = await _api.fetchPosts(endpoint);
      if (_disposed || request != _requestId) return;
      _posts = List<Post>.unmodifiable(result);
    } catch (error) {
      if (_disposed || request != _requestId) return;
      _error = error is PostApiException
          ? error.message
          : 'Không thể tải bài viết. Vui lòng thử lại.';
    } finally {
      if (!_disposed && request == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Chỉ hành động rõ ràng của người dùng mới bật dữ liệu mẫu.
  /// ID âm dành riêng cho mẫu cục bộ; không gửi các ID này lên máy chủ.
  void loadSampleData() {
    if (_disposed) return;
    ++_requestId;
    _resetOperations();
    _posts = const [
      Post(
        id: -1,
        userId: 1,
        title: 'Ôn tập gọi API',
        body: 'Dùng http để tải JSON, kiểm tra mã HTTP và chuyển sang model.',
      ),
      Post(
        id: -2,
        userId: 1,
        title: 'Quản lý trạng thái với Provider',
        body:
            'ChangeNotifier thông báo khi tải dữ liệu, tìm kiếm hoặc thay đổi trạng thái.',
      ),
      Post(
        id: -3,
        userId: 2,
        title: 'Lưu dữ liệu trên thiết bị',
        body:
            'SharedPreferences lưu cài đặt và yêu thích; SQLite lưu ghi chú có cấu trúc.',
      ),
    ];
    _isSampleData = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void setQuery(String value) {
    if (_disposed) return;
    final query = value.trim().toLowerCase();
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  Future<Post?> findPost(int id) async {
    if (_disposed || _isSampleData || _endpoint == null || _isLoading) {
      return null;
    }
    final source = _requestId;
    final lookup = ++_lookupId;
    final endpoint = _endpoint!;
    _isLookingUp = true;
    _lookupError = null;
    notifyListeners();
    try {
      if (id <= 0) {
        throw const PostApiException('ID phải là số nguyên lớn hơn 0.');
      }
      final post = await _api.fetchPost(endpoint, id);
      if (_disposed || source != _requestId || lookup != _lookupId) return null;
      return post;
    } catch (error) {
      if (!_disposed && source == _requestId && lookup == _lookupId) {
        _lookupError = error is PostApiException
            ? error.message
            : 'Không tìm được bài viết.';
      }
      return null;
    } finally {
      if (!_disposed && source == _requestId && lookup == _lookupId) {
        _isLookingUp = false;
        notifyListeners();
      }
    }
  }

  Future<T?> _mutate<T>(
    Future<T> Function(String endpoint) action,
    void Function(T result) apply, {
    int? expectedSource,
  }) async {
    if (_disposed || _isSaving) return null;
    if (!canWrite || (expectedSource != null && expectedSource != _requestId)) {
      _mutationError =
          'Nguồn dữ liệu đã đổi hoặc chỉ cho phép đọc. Chọn backend trong Cài đặt và mở lại bài viết.';
      notifyListeners();
      return null;
    }
    final source = _requestId;
    final endpoint = _endpoint!;
    _isSaving = true;
    _mutationError = null;
    notifyListeners();
    try {
      final result = await action(endpoint);
      if (_disposed || source != _requestId) return null;
      apply(result);
      return result;
    } catch (error) {
      if (!_disposed && source == _requestId) {
        _mutationError = error is PostApiException
            ? error.message
            : 'Không lưu được thay đổi. Hãy thử lại.';
      }
      return null;
    } finally {
      if (!_disposed && source == _requestId) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  void _upsert(Post post) {
    _posts = List<Post>.unmodifiable([
      for (final old in _posts)
        if (old.id != post.id) old,
      post,
    ]);
  }

  Future<Post?> createPost({
    required int userId,
    required String title,
    required String body,
    int? expectedSource,
  }) => _mutate(
    (endpoint) =>
        _api.createPost(endpoint, userId: userId, title: title, body: body),
    _upsert,
    expectedSource: expectedSource,
  );

  Future<Post?> updatePost(Post post, {int? expectedSource}) => _mutate(
    (endpoint) => _api.updatePost(endpoint, post),
    _upsert,
    expectedSource: expectedSource,
  );

  Future<bool> deletePost(int id, {int? expectedSource}) async =>
      await _mutate(
        (endpoint) async {
          await _api.deletePost(endpoint, id);
          return true;
        },
        (_) {
          _posts = List<Post>.unmodifiable(
            _posts.where((post) => post.id != id),
          );
        },
        expectedSource: expectedSource,
      ) ??
      false;

  void setSortAscending(bool value) {
    if (_disposed || value == _sortAscending) return;
    _sortAscending = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_requestId;
    _resetOperations();
    _isLoading = false;
    _api.close();
    super.dispose();
  }
}
