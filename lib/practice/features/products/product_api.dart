import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../shared/api_endpoint.dart';
import 'product.dart';

class ProductApiException implements Exception {
  const ProductApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns its HTTP client, including a client supplied by the caller.
class ProductApi {
  ProductApi({
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout;

  final http.Client _client;
  final Duration _requestTimeout;

  Uri _uri(String endpoint, [int? id]) {
    try {
      return id == null ? collectionUri(endpoint) : itemUri(endpoint, id);
    } on FormatException catch (error) {
      throw ProductApiException(error.message);
    }
  }

  Future<T> _request<T>(
    Future<http.Response> Function() send,
    List<int> statuses,
    T Function(http.Response) parse,
  ) async {
    try {
      final response = await send().timeout(_requestTimeout);
      if (!statuses.contains(response.statusCode)) {
        final hint = switch (response.statusCode) {
          400 => 'Kiểm tra dữ liệu nhập.',
          404 => 'Không tìm thấy sản phẩm hoặc endpoint.',
          _ => 'Hãy thử lại hoặc kiểm tra máy chủ.',
        };
        throw ProductApiException('HTTP ${response.statusCode}. $hint');
      }
      return parse(response);
    } on TimeoutException {
      throw const ProductApiException(
        'Hết thời gian chờ máy chủ. Hãy thử lại.',
      );
    } on http.ClientException {
      throw const ProductApiException(
        'Không thể kết nối. Kiểm tra mạng và endpoint.',
      );
    } on FormatException {
      throw const ProductApiException(
        'JSON sản phẩm không hợp lệ: cần id, name, description và price dạng số.',
      );
    }
  }

  dynamic _decode(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));
  Product _product(http.Response response) {
    final decoded = _decode(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected product object');
    }
    return Product.fromJson(decoded);
  }

  Future<List<Product>> fetchProducts(String endpoint, {String? name}) async {
    final base = _uri(endpoint);
    final query = Map<String, String>.from(base.queryParameters)
      ..remove('name');
    if (name != null && name.trim().isNotEmpty) query['name'] = name.trim();
    final uri = query.isEmpty
        ? base.replace(query: '')
        : base.replace(queryParameters: query);
    return _request(() => _client.get(uri), [200], (response) {
      final data = _decode(response);
      if (data is! List) throw const FormatException('Expected array');
      return List<Product>.unmodifiable(
        data.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Expected object');
          }
          return Product.fromJson(item);
        }),
      );
    });
  }

  Future<Product> fetchProduct(String endpoint, int id) async {
    final uri = _uri(endpoint, id);
    return _request(() => _client.get(uri), [200], _product);
  }

  Map<String, dynamic> _input(String name, String description, double price) {
    if (name.trim().isEmpty ||
        name.trim().length > 200 ||
        description.trim().length > 2000 ||
        !price.isFinite ||
        price < 0) {
      throw const ProductApiException(
        'Tên từ 1–200 ký tự, mô tả tối đa 2000 ký tự, giá là số không âm.',
      );
    }
    return {
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
    };
  }

  Future<Product> createProduct(
    String endpoint, {
    required String name,
    required String description,
    required double price,
  }) async {
    final uri = _uri(endpoint);
    final body = jsonEncode(_input(name, description, price));
    return _request(
      () => _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ),
      [200, 201],
      _product,
    );
  }

  Future<Product> updateProduct(String endpoint, Product product) async {
    final uri = _uri(endpoint, product.id);
    final body = jsonEncode(
      _input(product.name, product.description, product.price),
    );
    return _request(
      () => _client.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ),
      [200, 204],
      (response) => response.statusCode == 204 ? product : _product(response),
    );
  }

  Future<void> deleteProduct(String endpoint, int id) async {
    final uri = _uri(endpoint, id);
    return _request(() => _client.delete(uri), [200, 204], (_) {});
  }

  void close() => _client.close();
}
