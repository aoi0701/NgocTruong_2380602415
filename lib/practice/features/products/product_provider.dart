import 'package:flutter/foundation.dart';

import 'product.dart';
import 'product_api.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({required ProductApi api}) : _api = api;

  final ProductApi _api;
  List<Product> _products = const [];
  String? _endpoint;
  String _name = '';
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isFinding = false;
  bool _disposed = false;
  String? _error;
  String? _mutationError;
  int _request = 0;
  int _source = 0;
  int _write = 0;
  int _lookup = 0;

  List<Product> get products => _products;
  String? get endpoint => _endpoint;
  String get nameQuery => _name;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isFinding => _isFinding;
  String? get error => _error;
  String? get mutationError => _mutationError;

  String _message(Object error) => error is ProductApiException
      ? error.message
      : 'Không thể thực hiện yêu cầu. Vui lòng thử lại.';

  void _resetSource(String? endpoint) {
    _endpoint = endpoint;
    ++_source;
    ++_request;
    ++_write;
    ++_lookup;
    _products = const [];
    _name = '';
    _error = null;
    _mutationError = null;
    _isLoading = false;
    _isSaving = false;
    _isFinding = false;
  }

  void clearEndpoint() {
    if (_disposed) return;
    _resetSource(null);
    notifyListeners();
  }

  Future<void> load(String endpoint, {String? name}) async {
    if (_disposed) return;
    endpoint = endpoint.trim();
    if (_endpoint != endpoint) _resetSource(endpoint);
    final request = ++_request;
    _name = name?.trim() ?? '';
    _isLoading = true;
    _error = null;
    _products = const [];
    notifyListeners();
    try {
      final result = await _api.fetchProducts(endpoint, name: _name);
      if (_disposed || request != _request) return;
      _products = List<Product>.unmodifiable(result);
    } catch (error) {
      if (_disposed || request != _request) return;
      _error = _message(error);
    } finally {
      if (!_disposed && request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Product?> findById(int id) async {
    if (_disposed || _endpoint == null || _isFinding || _isSaving) return null;
    final source = _source;
    final lookup = ++_lookup;
    final endpoint = _endpoint!;
    _isFinding = true;
    _mutationError = null;
    notifyListeners();
    try {
      final result = await _api.fetchProduct(endpoint, id);
      return !_disposed && source == _source && lookup == _lookup
          ? result
          : null;
    } catch (error) {
      if (!_disposed && source == _source && lookup == _lookup) {
        _mutationError = _message(error);
      }
      return null;
    } finally {
      if (!_disposed && source == _source && lookup == _lookup) {
        _isFinding = false;
        notifyListeners();
      }
    }
  }

  bool _matches(Product product) =>
      _name.isEmpty || product.name.toLowerCase().contains(_name.toLowerCase());

  Future<bool> _mutate(
    Future<void> Function(String endpoint, bool Function() current) action,
  ) async {
    if (_disposed ||
        _endpoint == null ||
        _isSaving ||
        _isLoading ||
        _isFinding) {
      return false;
    }
    final source = _source;
    final request = _request;
    final write = ++_write;
    bool current() =>
        !_disposed &&
        source == _source &&
        request == _request &&
        write == _write;
    _isSaving = true;
    _mutationError = null;
    notifyListeners();
    try {
      await action(_endpoint!, current);
      return current();
    } catch (error) {
      if (current()) _mutationError = _message(error);
      return false;
    } finally {
      if (!_disposed && source == _source && write == _write) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> create({
    required String name,
    required String description,
    required double price,
  }) => _mutate((endpoint, current) async {
    final product = await _api.createProduct(
      endpoint,
      name: name,
      description: description,
      price: price,
    );
    if (current() && _matches(product)) {
      _products = List<Product>.unmodifiable([..._products, product]);
    }
  });

  Future<bool> update(Product product) => _mutate((endpoint, current) async {
    final updated = await _api.updateProduct(endpoint, product);
    if (current()) {
      final remaining = _products
          .where((item) => item.id != updated.id)
          .toList();
      if (_matches(updated)) {
        final index = _products.indexWhere((item) => item.id == updated.id);
        remaining.insert(
          index < 0 || index > remaining.length ? remaining.length : index,
          updated,
        );
      }
      _products = List<Product>.unmodifiable(remaining);
    }
  });

  Future<bool> delete(int id) => _mutate((endpoint, current) async {
    await _api.deleteProduct(endpoint, id);
    if (current()) {
      _products = List<Product>.unmodifiable(
        _products.where((item) => item.id != id),
      );
    }
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_source;
    ++_request;
    _api.close();
    super.dispose();
  }
}
