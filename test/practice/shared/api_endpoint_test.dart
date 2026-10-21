import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/practice/features/settings/endpoint_validation.dart';
import 'package:ngoc_truong_2380602415/practice/features/shared/api_endpoint.dart';

void main() {
  test(
    'emulator and loopback HTTP reach local backend without allowing remote HTTP',
    () {
      for (final host in ['10.0.2.2', 'localhost', '127.0.0.1']) {
        expect(
          normalizePostsEndpoint('http://$host:5186/api/posts'),
          'http://$host:5186/api/posts',
        );
      }
      expect(
        () => normalizePostsEndpoint('http://example.com/api/posts'),
        throwsFormatException,
      );
      expect(
        () => normalizePostsEndpoint('http://10.0.2.2.evil.test/api/posts'),
        throwsFormatException,
      );
    },
  );
  test('ID route appends before query and cannot target invalid IDs', () {
    expect(
      itemUri('https://demo.test/api/posts/?category=2', 42).toString(),
      'https://demo.test/api/posts/42?category=2',
    );
    expect(() => itemUri(emulatorPostsEndpoint, 0), throwsFormatException);
  });
  test(
    'product route preserves API prefix while removing collection filters',
    () {
      expect(
        productsEndpoint('https://demo.test/v1/api/posts/?search=old'),
        'https://demo.test/v1/api/products',
      );
      expect(
        productsEndpoint(emulatorPostsEndpoint),
        'http://10.0.2.2:5186/api/products',
      );
      expect(
        () => productsEndpoint('https://demo.test/other'),
        throwsFormatException,
      );
      expect(
        serverBase('https://demo.test/v1/api/posts'),
        'https://demo.test/v1/api',
      );
    },
  );
}
