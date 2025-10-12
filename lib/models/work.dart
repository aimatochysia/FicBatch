import 'package:hive/hive.dart';
import 'reading_progress.dart';
part 'work.g.dart';

@HiveType(typeId: 1)
class Work {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final List<String> tags;

  @HiveField(4)
  final DateTime? publishedAt;

  @HiveField(5)
  final DateTime? updatedAt;

  @HiveField(6)
  final int? wordsCount;

  @HiveField(7)
  final int? chaptersCount;

  @HiveField(8)
  final int? kudosCount;

  @HiveField(9)
  final int? hitsCount;

  @HiveField(10)
  final int? commentsCount;

  @HiveField(11)
  final DateTime userAddedDate;

  @HiveField(12)
  final DateTime? lastSyncDate;

  @HiveField(13)
  final DateTime? downloadedAt;

  @HiveField(14)
  final DateTime? lastUserOpened;

  @HiveField(15)
  final bool isFavorite;

  @HiveField(16)
  final String? categoryId;

  @HiveField(17)
  final ReadingProgress readingProgress;

  @HiveField(18)
  final bool isDownloaded;

  @HiveField(19)
  final bool hasUpdate;

  Work({
    required this.id,
    required this.title,
    required this.author,
    required this.tags,
    required this.userAddedDate,
    this.publishedAt,
    this.updatedAt,
    this.wordsCount,
    this.chaptersCount,
    this.kudosCount,
    this.hitsCount,
    this.commentsCount,
    this.lastSyncDate,
    this.downloadedAt,
    this.lastUserOpened,
    this.isFavorite = false,
    this.categoryId,
    ReadingProgress? readingProgress,
    this.isDownloaded = false,
    this.hasUpdate = false,
  }) : readingProgress = readingProgress ?? ReadingProgress.empty();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'tags': tags,
    'publishedAt': publishedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'wordsCount': wordsCount,
    'chaptersCount': chaptersCount,
    'kudosCount': kudosCount,
    'hitsCount': hitsCount,
    'commentsCount': commentsCount,
    'userAddedDate': userAddedDate.toIso8601String(),
    'lastSyncDate': lastSyncDate?.toIso8601String(),
    'downloadedAt': downloadedAt?.toIso8601String(),
    'lastUserOpened': lastUserOpened?.toIso8601String(),
    'isFavorite': isFavorite,
    'categoryId': categoryId,
    'isDownloaded': isDownloaded,
    'hasUpdate': hasUpdate,
    'readingProgress': readingProgress.toJson(),
  };

  factory Work.fromJson(Map<String, dynamic> json) => Work(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Untitled',
    author: json['author'] ?? 'Unknown',
    tags: List<String>.from(json['tags'] ?? []),
    publishedAt: _tryParseDate(json['publishedAt']),
    updatedAt: _tryParseDate(json['updatedAt']),
    wordsCount: json['wordsCount'],
    chaptersCount: json['chaptersCount'],
    kudosCount: json['kudosCount'],
    hitsCount: json['hitsCount'],
    commentsCount: json['commentsCount'],
    userAddedDate: _tryParseDate(json['userAddedDate']) ?? DateTime.now(),
    lastSyncDate: _tryParseDate(json['lastSyncDate']),
    downloadedAt: _tryParseDate(json['downloadedAt']),
    lastUserOpened: _tryParseDate(json['lastUserOpened']),
    isFavorite: json['isFavorite'] ?? false,
    categoryId: json['categoryId'],
    isDownloaded: json['isDownloaded'] ?? false,
    hasUpdate: json['hasUpdate'] ?? false,
    readingProgress: json['readingProgress'] != null
        ? ReadingProgress.fromJson(
            Map<String, dynamic>.from(json['readingProgress']),
          )
        : ReadingProgress.empty(),
  );

  Work copyWith({
    String? title,
    String? author,
    List<String>? tags,
    DateTime? updatedAt,
    DateTime? lastSyncDate,
    DateTime? lastUserOpened,
    bool? isFavorite,
    bool? isDownloaded,
    bool? hasUpdate,
    String? categoryId,
    ReadingProgress? readingProgress,
  }) {
    return Work(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      publishedAt: publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wordsCount: wordsCount,
      chaptersCount: chaptersCount,
      kudosCount: kudosCount,
      hitsCount: hitsCount,
      commentsCount: commentsCount,
      userAddedDate: userAddedDate,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      downloadedAt: downloadedAt,
      lastUserOpened: lastUserOpened ?? this.lastUserOpened,
      isFavorite: isFavorite ?? this.isFavorite,
      categoryId: categoryId ?? this.categoryId,
      readingProgress: readingProgress ?? this.readingProgress,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      hasUpdate: hasUpdate ?? this.hasUpdate,
    );
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
