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
    // 1️⃣ If already set, just use it
    if (settings.libraryFolder != null) {
      baseDir = Directory(settings.libraryFolder!);
      await baseDir.create(recursive: true);
      return;
    }

    // 2️⃣ Ask for permission first if Android
    if (Platform.isAndroid) {
      await _ensureAndroidPerms();
    }

    // 3️⃣ Ask user for folder selection (cross-platform)
    String? pickedDir = await getDirectoryPath(
      confirmButtonText: 'Select Library Folder',
    );

    // 4️⃣ If user canceled → fallback dir per platform
    if (pickedDir == null) {
      if (Platform.isAndroid) {
        final dir = await getExternalStorageDirectory();
        pickedDir = p.join(dir!.path, 'ficbatch');
      } else if (Platform.isIOS) {
        pickedDir =
            p.join((await getApplicationDocumentsDirectory()).path, 'ficbatch');
      } else if (Platform.isWindows) {
        final downloads = await getDownloadsDirectory();
        pickedDir = p.join(
            (downloads ?? await getApplicationDocumentsDirectory()).path,
            'ficbatch');
      } else {
        pickedDir =
            p.join((await getApplicationDocumentsDirectory()).path, 'ficbatch');
      }
    }

    // 5️⃣ Normalize absolute path (fixes <projDir>\C:\downloads bug)
    pickedDir = p.normalize(p.absolute(pickedDir));

    // 6️⃣ Create directory
    baseDir = Directory(pickedDir);
    await baseDir.create(recursive: true);

    // 7️⃣ Save to settings
    await settings.setLibraryFolder(baseDir.path);
  }

  Future<void> _ensureAndroidPerms() async {
    if (!Platform.isAndroid) return;

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return;

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return;

    debugPrint('Storage permission denied — some features may not work.');
  }

  /// Returns a **real absolute path** (use with File)
  String resolvePath(String fileName) => p.join(baseDir.path, fileName);

  /// Returns a **file:// URI** string (use with WebView)
  String resolveFileUri(String fileName) =>
      Uri.file(resolvePath(fileName)).toString();

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
