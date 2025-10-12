import 'package:hive/hive.dart';
part 'reading_progress.g.dart';

@HiveType(typeId: 0)
class ReadingProgress {
  @HiveField(0)
  final int chapterIndex;

  @HiveField(1)
  final String? chapterAnchor;

  @HiveField(2)
  final DateTime? lastReadAt;

  @HiveField(3)
  final double scrollPosition;

  @HiveField(4)
  final bool isCompleted;

  ReadingProgress({
    required this.chapterIndex,
    this.chapterAnchor,
    this.lastReadAt,
    required this.scrollPosition,
    this.isCompleted = false,
  });

  factory ReadingProgress.empty() =>
      ReadingProgress(chapterIndex: 0, scrollPosition: 0.0, isCompleted: false);

  Map<String, dynamic> toJson() => {
    'chapterIndex': chapterIndex,
    'chapterAnchor': chapterAnchor,
    'lastReadAt': lastReadAt?.toIso8601String(),
    'scrollPosition': scrollPosition,
    'isCompleted': isCompleted,
  };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      ReadingProgress(
        chapterIndex: json['chapterIndex'] ?? 0,
        chapterAnchor: json['chapterAnchor'],
        lastReadAt: json['lastReadAt'] != null
            ? DateTime.tryParse(json['lastReadAt'])
            : null,
        scrollPosition: (json['scrollPosition'] ?? 0.0).toDouble(),
        isCompleted: json['isCompleted'] ?? false,
      );

  ReadingProgress copyWith({
    int? chapterIndex,
    String? chapterAnchor,
    DateTime? lastReadAt,
    double? scrollPosition,
    bool? isCompleted,
  }) {
    return ReadingProgress(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterAnchor: chapterAnchor ?? this.chapterAnchor,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  bool get hasProgress => chapterIndex > 0 || scrollPosition > 0.0;
}
