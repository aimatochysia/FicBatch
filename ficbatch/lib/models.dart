import 'dart:convert';

enum LogKind { downloaded, started, progress, finished, restarted, deleted, error }

String logKindLabel(LogKind k) {
  switch (k) {
    case LogKind.downloaded: return "DOWNLOADED";
    case LogKind.started: return "STARTED";
    case LogKind.progress: return "PROGRESSES";
    case LogKind.finished: return "FINISHED";
    case LogKind.restarted: return "RESTARTED";
    case LogKind.deleted: return "DELETED";
    case LogKind.error: return "ERROR";
  }
}

class WorkItem {
  final String id;           // numeric work id (string)
  final String title;
  final String publisher;
  final List<String> tags;
  final String filePath;     // absolute path to .html
  final DateTime addedAt;
  bool favorite;
  // Progress
  double progress;           // 0.0..1.0
  int lastScrollY;           // last saved scroll Y
  int lastContentHeight;     // last saved full scrollable height

  WorkItem({
    required this.id,
    required this.title,
    required this.publisher,
    required this.tags,
    required this.filePath,
    required this.addedAt,
    this.favorite = false,
    this.progress = 0.0,
    this.lastScrollY = 0,
    this.lastContentHeight = 0,
  });

  WorkItem copyWith({
    String? title,
    String? publisher,
    List<String>? tags,
    String? filePath,
    bool? favorite,
    double? progress,
    int? lastScrollY,
    int? lastContentHeight,
  }) {
    return WorkItem(
      id: id,
      title: title ?? this.title,
      publisher: publisher ?? this.publisher,
      tags: tags ?? this.tags,
      filePath: filePath ?? this.filePath,
      addedAt: addedAt,
      favorite: favorite ?? this.favorite,
      progress: progress ?? this.progress,
      lastScrollY: lastScrollY ?? this.lastScrollY,
      lastContentHeight: lastContentHeight ?? this.lastContentHeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'publisher': publisher,
    'tags': tags,
    'filePath': filePath,
    'addedAt': addedAt.toIso8601String(),
    'favorite': favorite,
    'progress': progress,
    'lastScrollY': lastScrollY,
    'lastContentHeight': lastContentHeight,
  };

  static WorkItem fromJson(Map<String, dynamic> j) => WorkItem(
    id: j['id'],
    title: j['title'],
    publisher: j['publisher'] ?? 'Unknown Publisher',
    tags: (j['tags'] as List).map((e) => e.toString()).toList(),
    filePath: j['filePath'],
    addedAt: DateTime.parse(j['addedAt']),
    favorite: j['favorite'] ?? false,
    progress: (j['progress'] ?? 0.0).toDouble(),
    lastScrollY: j['lastScrollY'] ?? 0,
    lastContentHeight: j['lastContentHeight'] ?? 0,
  );

  static List<WorkItem> listFromJsonString(String? s) {
    if (s == null || s.isEmpty) return [];
    final arr = jsonDecode(s) as List;
    return arr.map((e) => WorkItem.fromJson(e)).toList();
  }

  static String listToJsonString(List<WorkItem> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}

class LogEntry {
  final DateTime at;
  final LogKind kind;
  final String message; // "[DOWNLOADED] <title> - <id>" etc.
  final String? id;
  final String? title;

  LogEntry({required this.at, required this.kind, required this.message, this.id, this.title});

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'kind': kind.index,
    'message': message,
    'id': id,
    'title': title,
  };

  static LogEntry fromJson(Map<String, dynamic> j) => LogEntry(
    at: DateTime.parse(j['at']),
    kind: LogKind.values[j['kind']],
    message: j['message'],
    id: j['id'],
    title: j['title'],
  );

  static List<LogEntry> listFromJsonString(String? s) {
    if (s == null || s.isEmpty) return [];
    final arr = jsonDecode(s) as List;
    return arr.map((e) => LogEntry.fromJson(e)).toList();
  }

  static String listToJsonString(List<LogEntry> entries) {
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }
}
