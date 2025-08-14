import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models.dart';
import '../utils/html_utils.dart';
import 'history_service.dart';
import 'library_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';

class DownloadTask {
  final String id;
  String status; // queued, downloading, done, error
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
  final List<String> _historyIds = []; // recent downloaded ids (persisted)

  bool _running = false;

  Future<void> addFromInput(String input) async {
    // extract all digit groups as IDs
    final ids = RegExp(r'\d+')
        .allMatches(input)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
    for (final id in ids) {
      if (_queue.indexWhere((t) => t.id == id) == -1)
        _queue.add(DownloadTask(id));
    }
    notifyListeners();
    _processQueue();
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

      // random 1-2 sec delay between tasks
      final delayMs = 1000 + rnd.nextInt(1001);
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    _running = false;
  }

  Future<void> _downloadWork(String workId) async {
    // AO3-like pattern per your JS reference
    final url = Uri.parse(
        'https://archiveofourown.org/downloads/$workId/a.html?updated_at=1738557260');

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

    // Inject simple metadata header (optional)
    final injected = '''
<div id="metadata" style="padding:12px;margin:8px 0;border-bottom:1px solid #888;font-family:system-ui, -apple-system, Roboto, Segoe UI;">
  <h1 style="margin:0;font-size:1.5em;">${meta.title}</h1>
  <h3 style="margin:4px 0 0 0; font-weight:500;">by ${meta.publisher}</h3>
  <p style="margin:4px 0 0 0;"><strong>Tags:</strong> ${meta.tags.join(', ')}</p>
</div>
''';
    htmlText = injected + htmlText;

    final fileName = '$workId.html';
    final path = storage.resolveFileUri(fileName);
    final file = File(path);
    await file.writeAsString(htmlText);

    // Update library
    await library.rescan();

    // Track history
    history.add(LogKind.downloaded,
        id: workId,
        title: meta.title,
        extra: "[DOWNLOADED] ${meta.title} - $workId");

    // Persist "download history" list as simple list of last 50 ids
    _historyIds.insert(0, workId);
    if (_historyIds.length > 50) _historyIds.removeLast();
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }
}
