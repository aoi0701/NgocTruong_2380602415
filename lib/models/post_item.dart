class PostItem {
  PostItem({
    this.id,
    this.userId,
    required this.title,
    required this.body,
  });

  final int? id;
  final int? userId;
  final String? title;
  final String? body;

  factory PostItem.fromJson(Map<String, dynamic> json) {
    return PostItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId']}'),
      title: json['title'] as String?,
      body: json['body'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (userId != null) 'userId': userId,
        'title': title,
        'body': body,
      };
}
