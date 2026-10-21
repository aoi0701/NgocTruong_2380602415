import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/practice/features/posts/post.dart';

void main() {
  const valid = <String, dynamic>{
    'id': 7,
    'userId': 2,
    'title': 'Tiêu đề',
    'body': 'Nội dung có dấu',
  };

  test('JSON roundtrip preserves every typed field', () {
    final post = Post.fromJson(valid);
    expect(post.id, 7);
    expect(post.userId, 2);
    expect(post.title, 'Tiêu đề');
    expect(post.body, 'Nội dung có dấu');
    expect(post.toJson(), valid);
  });

  for (final field in valid.keys) {
    test('rejects missing $field', () {
      final json = Map<String, dynamic>.of(valid)..remove(field);
      expect(() => Post.fromJson(json), throwsFormatException);
    });
    test('rejects null $field', () {
      expect(
        () => Post.fromJson({...valid, field: null}),
        throwsFormatException,
      );
    });
  }

  for (final invalid in <Map<String, dynamic>>[
    {'id': '7'},
    {'id': 7.0},
    {'id': true},
    {'userId': 2.5},
    {'userId': '2'},
    {'title': 3},
    {'body': <String>[]},
  ]) {
    test('rejects wrong JSON types $invalid', () {
      expect(
        () => Post.fromJson({...valid, ...invalid}),
        throwsFormatException,
      );
    });
  }
}
