import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService with ChangeNotifier {
  bool darkMode = true;
  bool autosaveEnabled = true;
  int autosaveSeconds = 10; // default
  double readerFontScale = 1.0; // 1.0 == 100%
  String? libraryFolder; // absolute path

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool('darkMode') ?? true;
    autosaveEnabled = prefs.getBool('autosaveEnabled') ?? true;
    autosaveSeconds = prefs.getInt('autosaveSeconds') ?? 10;
    readerFontScale = (prefs.getDouble('readerFontScale') ?? 1.0).clamp(0.6, 2.0);
    libraryFolder = prefs.getString('libraryFolder');
    notifyListeners();
  }

  Future<void> setDarkMode(bool v) async {
    darkMode = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', v);
    notifyListeners();
  }

  Future<void> setAutosaveEnabled(bool v) async {
    autosaveEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autosaveEnabled', v);
    notifyListeners();
  }

  Future<void> setAutosaveSeconds(int v) async {
    autosaveSeconds = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autosaveSeconds', v);
    notifyListeners();
  }

  Future<void> setReaderFontScale(double v) async {
    readerFontScale = v.clamp(0.6, 2.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('readerFontScale', readerFontScale);
    notifyListeners();
  }

  Future<void> setLibraryFolder(String path) async {
    libraryFolder = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('libraryFolder', path);
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'darkMode': darkMode,
    'autosaveEnabled': autosaveEnabled,
    'autosaveSeconds': autosaveSeconds,
    'readerFontScale': readerFontScale,
    'libraryFolder': libraryFolder,
  };

  String exportJson() => jsonEncode(toJson());
}
