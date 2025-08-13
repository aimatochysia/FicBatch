import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import 'package:intl/intl.dart';

class HistoryService with ChangeNotifier {
  final _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  List<LogEntry> _logs = [];
  List<LogEntry> get logs => _logs;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _logs = LogEntry.listFromJsonString(prefs.getString('logs'));
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logs', LogEntry.listToJsonString(_logs));
  }

  void add(LogKind kind, {String? id, String? title, String? extra}) {
    final label = logKindLabel(kind);
    final msg = extra ?? (title != null && id != null ? "[$label] $title - $id" :
      title != null ? "[$label] $title" : id != null ? "[$label] $id" : "[$label]");
    _logs.insert(0, LogEntry(at: DateTime.now(), kind: kind, message: msg, id: id, title: title));
    if (_logs.length > 1000) _logs = _logs.sublist(0, 1000);
    _persist();
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    _persist();
    notifyListeners();
  }
}
