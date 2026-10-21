/// Một bài viết bất biến; các số nguyên và chuỗi phải đúng kiểu JSON.
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  factory Post.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final userId = json['userId'];
    final title = json['title'];
    final body = json['body'];
    if (id is! int || userId is! int || title is! String || body is! String) {
      throw const FormatException(
        'Bài viết phải có id, userId là số nguyên và title, body là chuỗi.',
      );
    }
    return Post(id: id, userId: userId, title: title, body: body);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
  };
}
