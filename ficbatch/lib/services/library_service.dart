import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watcher/watcher.dart';

import '../models.dart';
import '../utils/html_utils.dart';
import 'history_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';

class LibraryService with ChangeNotifier {
  final SettingsService settings;
  final HistoryService history;
  final StorageService storage;

  LibraryService({required this.settings, required this.history, required this.storage});

  List<WorkItem> _items = [];
  List<WorkItem> get items => _items;

  StreamSubscription? _poller;
  DirectoryWatcher? _desktopWatcher;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _items = WorkItem.listFromJsonString(prefs.getString('library'));
    await rescan(); // reconcile disk vs. state

    // Watch folder:
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _desktopWatcher = DirectoryWatcher(storage.baseDir.path);
      _desktopWatcher!.events.listen((_) => rescan());
    } else {
      // Mobile: poll every 5 seconds (lightweight)
      _poller?.cancel();
      _poller = Stream.periodic(const Duration(seconds: 5)).listen((_) => rescan());
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library', WorkItem.listToJsonString(_items));
  }

  Future<void> rescan() async {
    final files = await storage.listHtmlFiles();
    final byPath = { for (var w in _items) w.filePath : w };

    // Add new files
    for (final f in files) {
      final path = f.path;
      if (!byPath.containsKey(path)) {
        try {
          final text = await File(path).readAsString();
          final meta = extractMeta(text);
          // try to derive an id from file name digits
          final idMatch = RegExp(r'(\d+)').firstMatch(p.basenameWithoutExtension(path));
          final id = idMatch?.group(1) ?? DateTime.now().millisecondsSinceEpoch.toString();

          final w = WorkItem(
            id: id,
            title: meta.title,
            publisher: meta.publisher,
            tags: meta.tags,
            filePath: path,
            addedAt: DateTime.now(),
          );
          _items.add(w);
          history.add(LogKind.started, id: w.id, title: w.title, extra: "[ADDED] ${w.title} - ${w.id}");
        } catch (_) { /* ignore parse fails */ }
      }
    }

    // Remove deleted files
    _items.removeWhere((w) {
      final exists = File(w.filePath).existsSync();
      if (!exists) {
        history.add(LogKind.deleted, id: w.id, title: w.title, extra: "[DELETED] ${w.title} - ${w.id}");
      }
      return !exists;
    });

    // Persist & notify
    await _persist();
    notifyListeners();
  }

  Future<void> updateWork(WorkItem updated) async {
    final idx = _items.indexWhere((w) => w.filePath == updated.filePath);
    if (idx >= 0) {
      _items[idx] = updated;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteWork(WorkItem w) async {
    try { await File(w.filePath).delete(); } catch (_) {}
    await rescan();
  }

  List<String> allTags() {
    final s = <String>{};
    for (final w in _items) { s.addAll(w.tags); }
    return s.toList()..sort();
  }

  WorkItem? byId(String id) => _items.firstWhere((w) => w.id == id, orElse: () => _items.firstWhere((w) => false, orElse: () => null as dynamic));
}
