class Book {
  int id;
  String title;
  String coverPath;
  String filePath;
  String lastReadPosition;
  double readingPercentage;
  String author;
  bool isDeleted;
  String? description;
  DateTime createTime;
  DateTime updateTime;

  Book(
      {required this.id,
      required this.title,
      required this.coverPath,
      required this.filePath,
      required this.lastReadPosition,
      required this.readingPercentage,
      required this.author,
      required this.isDeleted,
      this.description,
      required this.createTime,
      required this.updateTime});

  Map<String, Object?> toMap() {
    return {
      'title': title,
      'cover_path': coverPath,
      'file_path': filePath,
      'last_read_position': lastReadPosition,
      'reading_percentage': readingPercentage,
      'author': author,
      'is_deleted': isDeleted ? 1 : 0,
      'description': description,
      'create_time': createTime.toIso8601String(),
      'update_time': updateTime.toIso8601String(),
    };
  }
}
