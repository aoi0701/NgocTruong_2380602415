/// Một hàng ghi chú SQLite; trạng thái hoàn thành được lưu dưới dạng 0/1.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    this.isCompleted = false,
  });

  final int id;
  final String title;
  final String content;
  final bool isCompleted;

  Note copyWith({String? title, String? content, bool? isCompleted}) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  factory Note.fromMap(Map<String, Object?> row) => Note(
    id: row['id'] as int,
    title: row['title'] as String,
    content: row['content'] as String,
    isCompleted: row['is_completed'] == 1,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'content': content,
    'is_completed': isCompleted ? 1 : 0,
  };
}
