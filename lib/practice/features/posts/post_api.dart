import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../shared/api_endpoint.dart';
import 'post.dart';

class PostApiException implements Exception {
  const PostApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns its HTTP client; only successful server responses change local state.
class PostApi {
  PostApi({
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout;

  final http.Client _client;
  final Duration _requestTimeout;
  static const _headers = {'Content-Type': 'application/json; charset=utf-8'};

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TimeoutException {
      throw const PostApiException(
        'Đã hết thời gian chờ máy chủ. Hãy thử lại.',
      );
    } on http.ClientException {
      throw const PostApiException(
        'Không thể kết nối máy chủ. Hãy kiểm tra mạng và endpoint.',
      );
    } on FormatException {
      throw const PostApiException(
        'Endpoint hoặc dữ liệu JSON không hợp lệ. Bài viết cần id, userId, title, body.',
      );
    }
  }

  void _check(http.Response response, List<int> statuses) {
    if (statuses.contains(response.statusCode)) return;
    var detail = '';
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, dynamic>) {
        final errors = json['errors'];
        if (errors is Map) {
          detail = errors.values
              .expand((value) => value is List ? value : [value])
              .join(' ');
        } else {
          detail = '${json['detail'] ?? json['title'] ?? ''}';
        }
      }
    } on FormatException {
      // HTML/empty error bodies still have a useful HTTP status.
    }
    throw PostApiException(
      'Máy chủ trả về lỗi HTTP ${response.statusCode}.${detail.isEmpty ? '' : ' $detail'}',
    );
  }

  Post _decodePost(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return Post.fromJson(decoded);
  }

  Map<String, dynamic> _input(int userId, String title, String body) {
    title = title.trim();
    body = body.trim();
    if (userId <= 0 ||
        title.isEmpty ||
        title.length > 200 ||
        body.isEmpty ||
        body.length > 5000) {
      throw const PostApiException(
        'Người dùng phải lớn hơn 0; tiêu đề 1–200 ký tự, nội dung 1–5000 ký tự.',
      );
    }
    return {'userId': userId, 'title': title, 'body': body};
  }

  Future<List<Post>> fetchPosts(String endpoint) => _guard(() async {
    final response = await _client
        .get(collectionUri(endpoint))
        .timeout(_requestTimeout);
    _check(response, [200]);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException();
    return List<Post>.unmodifiable(
      decoded.map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException();
        return Post.fromJson(item);
      }),
    );
  });

  Future<Post> fetchPost(String endpoint, int id) => _guard(() async {
    final response = await _client
        .get(itemUri(endpoint, id))
        .timeout(_requestTimeout);
    _check(response, [200]);
    return _decodePost(response);
  });

  Future<Post> createPost(
    String endpoint, {
    required int userId,
    required String title,
    required String body,
  }) => _guard(() async {
    final response = await _client
        .post(
          collectionUri(endpoint),
          headers: _headers,
          body: jsonEncode(_input(userId, title, body)),
        )
        .timeout(_requestTimeout);
    _check(response, [201, 200]);
    return _decodePost(response);
  });

  Future<Post> updatePost(String endpoint, Post post) => _guard(() async {
    final input = _input(post.userId, post.title, post.body);
    final response = await _client
        .put(
          itemUri(endpoint, post.id),
          headers: _headers,
          body: jsonEncode(input),
        )
        .timeout(_requestTimeout);
    _check(response, [200, 204]);
    if (response.statusCode == 204) {
      return Post(
        id: post.id,
        userId: input['userId'] as int,
        title: input['title'] as String,
        body: input['body'] as String,
      );
    }
    return _decodePost(response);
  });

  Future<void> deletePost(String endpoint, int id) => _guard(() async {
    final response = await _client
        .delete(itemUri(endpoint, id))
        .timeout(_requestTimeout);
    _check(response, [200, 204]);
  });

  void close() => _client.close();
}
