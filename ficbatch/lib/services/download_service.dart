import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../utils/html_utils.dart';
import 'history_service.dart';
import 'library_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';

class DownloadTask {
  final String id;
  String status;
  String? error;
  DownloadTask(this.id, {this.status = 'queued'});
}

class DownloadService with ChangeNotifier {
  final SettingsService settings;
  final LibraryService library;
  final HistoryService history;
  final StorageService storage;

  DownloadService({
    required this.settings,
    required this.library,
    required this.history,
    required this.storage,
  });

  final List<DownloadTask> _queue = [];
  List<DownloadTask> get queue => List.unmodifiable(_queue);
  final List<String> _historyIds = [];

  bool _running = false;

  Future<void> addFromInput(String input) async {
    final ids = _extractIds(input);
    for (final id in ids) {
      final alreadyQueued = _queue.any((t) => t.id == id);
      final alreadyDownloaded = _historyIds.contains(id);
      if (!alreadyQueued && !alreadyDownloaded) {
        _queue.add(DownloadTask(id));
      }
    }
    if (ids.isNotEmpty) {
      notifyListeners();
      _processQueue();
    }
  }

  Set<String> _extractIds(String input) {
    final ids = <String>{};

    final urlRegex = RegExp(
      r'https?://archiveofourown\.org/works/(\d+)',
      caseSensitive: false,
    );
    for (final match in urlRegex.allMatches(input)) {
      ids.add(match.group(1)!);
    }

    final rawIdRegex = RegExp(r'(?<=\s|^)(\d{6,})(?=\s|$)');
    for (final match in rawIdRegex.allMatches(input)) {
      ids.add(match.group(1)!);
    }

    return ids;
  }

  Future<void> _processQueue() async {
    if (_running) return;
    _running = true;
    final rnd = Random();

    while (_queue.any((t) => t.status == 'queued')) {
      final task = _queue.firstWhere((t) => t.status == 'queued');
      task.status = 'downloading';
      notifyListeners();

      try {
        await _downloadWork(task.id);
        task.status = 'done';
      } catch (e) {
        task.status = 'error';
        task.error = e.toString();
      }
      notifyListeners();

      final delayMs = 1000 + rnd.nextInt(1001);
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    _running = false;
  }

  String injectParagraphIds(String html) {
    int counter = 0;
    return html.replaceAllMapped(
      RegExp(r'<p(.*?)>'),
      (match) {
        counter++;
        final existingAttributes = match.group(1) ?? '';
        // If it already has an id attribute, skip or replace it (optional)
        if (existingAttributes.contains('id=')) {
          return '<p$existingAttributes>';
        }
        return '<p id="para-$counter"$existingAttributes>';
      },
    );
  }

  Future<void> _downloadWork(String workId) async {
    final url =
        Uri.parse('https://archiveofourown.org/downloads/$workId/$workId.html');
    history.add(LogKind.started,
        id: workId, title: null, extra: "[STARTED] $workId");

    final res = await http.get(url);
    if (res.statusCode != 200) {
      history.add(LogKind.error,
          id: workId,
          extra: "[ERROR] Fetch failed ${res.statusCode} - $workId");
      throw Exception('Failed to fetch: ${res.statusCode}');
    }

    var htmlText = res.body;
    final meta = extractMeta(htmlText);

    // Inject unique IDs into paragraphs
    htmlText = injectParagraphIds(htmlText);

    // Inject simple metadata header
    final injected = '''
<div id="metadata" style="padding:12px;margin:8px 0;border-bottom:1px solid #888;font-family:system-ui, -apple-system, Roboto, Segoe UI;">
  <h1 style="margin:0;font-size:1.5em;">${meta.title}</h1>
  <h3 style="margin:4px 0 0 0; font-weight:500;">by ${meta.publisher}</h3>
  <p style="margin:4px 0 0 0;"><strong>Tags:</strong> ${meta.tags.join(', ')}</p>
</div>
''';
    htmlText = injected + htmlText;

    final fileName = '$workId.html';
    final path = storage.resolvePath(fileName);
    final file = File(path);
    await file.writeAsString(htmlText);
    await library.rescan();
    history.add(LogKind.downloaded,
        id: workId,
        title: meta.title,
        extra: "[DOWNLOADED] ${meta.title} - $workId");

    _historyIds.insert(0, workId);
    if (_historyIds.length > 50) _historyIds.removeLast();
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }
}
