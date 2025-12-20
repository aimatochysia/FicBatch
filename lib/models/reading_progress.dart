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

  @HiveField(5)
  final String? chapterName;

  /// First visible paragraph text (up to 200 chars) for cross-format position matching
  @HiveField(6)
  final String? paragraphAnchor;

  ReadingProgress({
    required this.chapterIndex,
    this.chapterAnchor,
    this.lastReadAt,
    required this.scrollPosition,
    this.isCompleted = false,
    this.chapterName,
    this.paragraphAnchor,
  });

  factory ReadingProgress.empty() =>
      ReadingProgress(chapterIndex: 0, scrollPosition: 0.0, isCompleted: false, chapterName: null, paragraphAnchor: null);

  Map<String, dynamic> toJson() => {
    'chapterIndex': chapterIndex,
    'chapterAnchor': chapterAnchor,
    'lastReadAt': lastReadAt?.toIso8601String(),
    'scrollPosition': scrollPosition,
    'isCompleted': isCompleted,
    'chapterName': chapterName,
    'paragraphAnchor': paragraphAnchor,
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
        chapterName: json['chapterName'],
        paragraphAnchor: json['paragraphAnchor'],
      );

  ReadingProgress copyWith({
    int? chapterIndex,
    String? chapterAnchor,
    DateTime? lastReadAt,
    double? scrollPosition,
    bool? isCompleted,
    String? chapterName,
    String? paragraphAnchor,
  }) {
    return ReadingProgress(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterAnchor: chapterAnchor ?? this.chapterAnchor,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      isCompleted: isCompleted ?? this.isCompleted,
      chapterName: chapterName ?? this.chapterName,
      paragraphAnchor: paragraphAnchor ?? this.paragraphAnchor,
    );
  }

  bool get hasProgress => chapterIndex > 0 || scrollPosition > 0.0 || (paragraphAnchor != null && paragraphAnchor!.isNotEmpty);
}
