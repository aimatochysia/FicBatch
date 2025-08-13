import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_selector/file_selector.dart';

import 'settings_service.dart';

class StorageService {
  final SettingsService settings;
  StorageService({required this.settings});

  late Directory baseDir; // resolved library directory

  Future<void> ensureReady() async {
    // Resolve initial library folder per platform:
    if (settings.libraryFolder != null) {
      baseDir = Directory(settings.libraryFolder!);
      await baseDir.create(recursive: true);
      return;
    }
    if (Platform.isAndroid) {
      // App-specific external storage (user-visible; removed when app uninstalled)
      await _ensureAndroidPerms();
      final dir = await getExternalStorageDirectory();
      baseDir = Directory(p.join(dir!.path, 'ficbatch'));
    } else if (Platform.isIOS) {
      baseDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'ficbatch'));
    } else if (Platform.isWindows) {
      final downloads = await getDownloadsDirectory();
      baseDir = Directory(p.join((downloads ?? await getApplicationDocumentsDirectory()).path, 'ficbatch'));
    } else {
      baseDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'ficbatch'));
    }
    await baseDir.create(recursive: true);
    await settings.setLibraryFolder(baseDir.path);
  }

  Future<void> _ensureAndroidPerms() async {
    final statuses = await [Permission.storage].request();
    if (statuses[Permission.storage]?.isGranted != true) {
      // Best-effort; scoped storage will still allow app-specific external dir.
    }
  }

  String resolvePath(String fileName) => p.join(baseDir.path, fileName);

  Future<String?> pickDirectory() async {
    final loc = await getDirectoryPath();
    if (loc == null) return null;
    final dir = Directory(p.join(loc, 'ficbatch'));
    await dir.create(recursive: true);
    baseDir = dir;
    await settings.setLibraryFolder(dir.path);
    return dir.path;
  }

  Future<List<FileSystemEntity>> listHtmlFiles() async {
    if (!await baseDir.exists()) await baseDir.create(recursive: true);
    return baseDir
        .listSync()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.html'))
        .toList();
  }
}
