import 'package:hive/hive.dart';
part 'history_entry.g.dart';

@HiveType(typeId: 2)
class HistoryEntry {
  @HiveField(0)
  final String workId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final int chapterIndex;

  @HiveField(4)
  final double scrollPosition;

  @HiveField(5)
  final DateTime accessedAt;

  HistoryEntry({
    required this.workId,
    required this.title,
    required this.author,
    required this.chapterIndex,
    required this.scrollPosition,
    required this.accessedAt,
  });

  Map<String, dynamic> toJson() => {
        'workId': workId,
        'title': title,
        'author': author,
        'chapterIndex': chapterIndex,
        'scrollPosition': scrollPosition,
        'accessedAt': accessedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        workId: json['workId'],
        title: json['title'],
        author: json['author'],
        chapterIndex: json['chapterIndex'] ?? 0,
        scrollPosition: (json['scrollPosition'] ?? 0.0).toDouble(),
        accessedAt: DateTime.parse(json['accessedAt']),
      );
}
