import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

/// Service for downloading works from AO3
class DownloadService {
  static const String _ao3DownloadBaseUrl = 'https://archiveofourown.org/downloads';
  
  /// Get the downloads directory path
  static Future<Directory> getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/FicBatch/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }
  
  /// Get the path for a specific work's downloaded file
  static Future<String> getWorkDownloadPath(String workId) async {
    final downloadsDir = await getDownloadsDirectory();
    return '${downloadsDir.path}/$workId.html';
  }
  
  /// Check if a work is downloaded
  static Future<bool> isWorkDownloaded(String workId) async {
    final path = await getWorkDownloadPath(workId);
    return File(path).exists();
  }
  
  /// Download a single work from AO3
  /// Returns the file path on success, null on failure
  static Future<String?> downloadWork(String workId) async {
    try {
      // AO3 download URL format: /downloads/{workId}/{workId}.html
      final url = '$_ao3DownloadBaseUrl/$workId/$workId.html';
      debugPrint('[DownloadService] Downloading work $workId from $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; FicBatch/1.0)',
        },
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode != 200) {
        debugPrint('[DownloadService] Failed to download work $workId: HTTP ${response.statusCode}');
        return null;
      }
      
      final filePath = await getWorkDownloadPath(workId);
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      
      debugPrint('[DownloadService] Successfully downloaded work $workId to $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[DownloadService] Error downloading work $workId: $e');
      return null;
    }
  }
  
  /// Download multiple works with throttling
  /// Returns a map of workId -> success/failure
  static Future<Map<String, bool>> downloadWorks(
    List<String> workIds, {
    Duration throttleDelay = const Duration(milliseconds: 1000),
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <String, bool>{};
    
    for (int i = 0; i < workIds.length; i++) {
      final workId = workIds[i];
      final path = await downloadWork(workId);
      results[workId] = path != null;
      
      onProgress?.call(i + 1, workIds.length);
      
      // Throttle to avoid overwhelming AO3
      if (i < workIds.length - 1) {
        await Future.delayed(throttleDelay);
      }
    }
    
    return results;
  }
  
  /// Delete a downloaded work
  static Future<bool> deleteDownload(String workId) async {
    try {
      final path = await getWorkDownloadPath(workId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[DownloadService] Deleted download for work $workId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[DownloadService] Error deleting download for work $workId: $e');
      return false;
    }
  }
  
  /// Get the content of a downloaded work
  static Future<String?> getDownloadedContent(String workId) async {
    try {
      final path = await getWorkDownloadPath(workId);
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      debugPrint('[DownloadService] Error reading download for work $workId: $e');
      return null;
    }
  }
  
  /// Get download file info (size, date)
  static Future<Map<String, dynamic>?> getDownloadInfo(String workId) async {
    try {
      final path = await getWorkDownloadPath(workId);
      final file = File(path);
      if (await file.exists()) {
        final stat = await file.stat();
        return {
          'path': path,
          'size': stat.size,
          'modified': stat.modified,
        };
      }
      return null;
    } catch (e) {
      debugPrint('[DownloadService] Error getting download info for work $workId: $e');
      return null;
    }
  }
  
  /// Clear all downloads
  static Future<int> clearAllDownloads() async {
    try {
      final dir = await getDownloadsDirectory();
      if (!await dir.exists()) return 0;
      
      int count = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.html')) {
          await entity.delete();
          count++;
        }
      }
      
      debugPrint('[DownloadService] Cleared $count downloads');
      return count;
    } catch (e) {
      debugPrint('[DownloadService] Error clearing downloads: $e');
      return 0;
    }
  }
  
  /// Get total download storage usage
  static Future<int> getStorageUsage() async {
    try {
      final dir = await getDownloadsDirectory();
      if (!await dir.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('[DownloadService] Error calculating storage usage: $e');
      return 0;
    }
  }
  
  /// Update work's download status in storage
  static Future<void> updateWorkDownloadStatus(
    StorageService storage,
    String workId,
    bool isDownloaded,
  ) async {
    final work = storage.getWork(workId);
    if (work != null) {
      final updatedWork = work.copyWith(
        isDownloaded: isDownloaded,
      );
      await storage.saveWork(updatedWork);
    }
  }
}

/// Model for tracking download progress
class DownloadProgress {
  final String workId;
  final String workTitle;
  final DownloadStatus status;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;
  
  DownloadProgress({
    required this.workId,
    required this.workTitle,
    required this.status,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });
  
  DownloadProgress copyWith({
    DownloadStatus? status,
    String? errorMessage,
    DateTime? completedAt,
  }) => DownloadProgress(
    workId: workId,
    workTitle: workTitle,
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
  );
}

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
}
