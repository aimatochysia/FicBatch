import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import '../models/work.dart';

/// Service for exporting and importing library data
class LibraryExportService {
  final StorageService _storage;
  
  LibraryExportService(this._storage);
  
  /// Export library data to a JSON string
  /// Includes works, categories, category mappings, and settings
  Future<String> exportToJson() async {
    try {
      // Get all works
      final works = _storage.getAllWorks();
      final worksJson = works.map((w) => w.toJson()).toList();
      
      // Get all categories
      final categories = await _storage.getCategories();
      
      // Get category mappings (which works are in which categories)
      final categoryMappings = <String, List<String>>{};
      for (final category in categories) {
        final workIds = await _storage.getWorkIdsForCategory(category);
        categoryMappings[category] = workIds.toList();
      }
      
      // Get auto-download settings per category
      final autoDownloadCategories = await _getAutoDownloadCategories();
      
      // Create export data structure
      final exportData = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'works': worksJson,
        'categories': categories,
        'categoryMappings': categoryMappings,
        'autoDownloadCategories': autoDownloadCategories,
        'defaultCategory': await _getDefaultCategory(),
      };
      
      return const JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      debugPrint('[LibraryExportService] Export error: $e');
      rethrow;
    }
  }
  
  /// Export library data to a file
  Future<String> exportToFile({String? customPath}) async {
    try {
      final jsonData = await exportToJson();
      
      String filePath;
      if (customPath != null) {
        filePath = customPath;
      } else {
        final dir = await _getExportDirectory();
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
        filePath = '${dir.path}/ficbatch_library_$timestamp.json';
      }
      
      final file = File(filePath);
      await file.writeAsString(jsonData);
      
      debugPrint('[LibraryExportService] Exported library to $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[LibraryExportService] Export to file error: $e');
      rethrow;
    }
  }
  
  /// Import library data from a JSON string
  /// Returns import summary with counts of added, skipped, and updated items
  Future<ImportResult> importFromJson(String jsonString, {
    ImportMode mode = ImportMode.merge,
  }) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate export format
      if (!data.containsKey('works')) {
        throw FormatException('Invalid library export format: missing "works" field');
      }
      
      final worksJson = data['works'] as List;
      final categories = data['categories'] as List? ?? [];
      final categoryMappings = data['categoryMappings'] as Map<String, dynamic>? ?? {};
      final autoDownloadCategories = data['autoDownloadCategories'] as List? ?? [];
      final defaultCategory = data['defaultCategory'] as String?;
      
      int worksAdded = 0;
      int worksUpdated = 0;
      int worksSkipped = 0;
      int categoriesAdded = 0;
      
      // If replace mode, clear existing data first
      if (mode == ImportMode.replace) {
        await _storage.clearAll();
        // Clear categories too
        final existingCats = await _storage.getCategories();
        for (final cat in existingCats) {
          await _storage.deleteCategory(cat);
        }
      }
      
      // Import categories first
      final existingCategories = await _storage.getCategories();
      for (final cat in categories) {
        final catName = cat.toString();
        if (!existingCategories.contains(catName)) {
          await _storage.addCategory(catName);
          categoriesAdded++;
        }
      }
      
      // Import works
      for (final workJson in worksJson) {
        try {
          final work = Work.fromJson(Map<String, dynamic>.from(workJson));
          final existingWork = _storage.getWork(work.id);
          
          if (existingWork == null) {
            // New work, add it
            await _storage.saveWork(work);
            worksAdded++;
          } else if (mode == ImportMode.merge || mode == ImportMode.replace) {
            // Existing work, update if merge mode
            // Preserve certain local data when merging
            final mergedWork = _mergeWorks(existingWork, work, mode);
            await _storage.saveWork(mergedWork);
            worksUpdated++;
          } else {
            worksSkipped++;
          }
        } catch (e) {
          debugPrint('[LibraryExportService] Error importing work: $e');
          worksSkipped++;
        }
      }
      
      // Import category mappings
      for (final entry in categoryMappings.entries) {
        final category = entry.key;
        final workIds = List<String>.from(entry.value);
        
        for (final workId in workIds) {
          final existingCats = Set<String>.from(await _storage.getCategoriesForWork(workId));
          if (!existingCats.contains(category)) {
            existingCats.add(category);
            await _storage.setCategoriesForWork(workId, existingCats);
          }
        }
      }
      
      // Import auto-download categories
      for (final cat in autoDownloadCategories) {
        await _setAutoDownloadCategory(cat.toString(), true);
      }
      
      // Import default category
      if (defaultCategory != null) {
        await _setDefaultCategory(defaultCategory);
      }
      
      return ImportResult(
        worksAdded: worksAdded,
        worksUpdated: worksUpdated,
        worksSkipped: worksSkipped,
        categoriesAdded: categoriesAdded,
        totalWorks: worksJson.length,
        totalCategories: categories.length,
      );
    } catch (e) {
      debugPrint('[LibraryExportService] Import error: $e');
      rethrow;
    }
  }
  
  /// Import library data from a file
  Future<ImportResult> importFromFile(String filePath, {
    ImportMode mode = ImportMode.merge,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File not found', filePath);
      }
      
      final jsonString = await file.readAsString();
      return await importFromJson(jsonString, mode: mode);
    } catch (e) {
      debugPrint('[LibraryExportService] Import from file error: $e');
      rethrow;
    }
  }
  
  /// Merge an existing work with imported work data
  Work _mergeWorks(Work existing, Work imported, ImportMode mode) {
    if (mode == ImportMode.replace) {
      return imported;
    }
    
    // In merge mode, preserve local reading progress and download status
    // but update metadata from import
    return Work(
      id: existing.id,
      title: imported.title,
      author: imported.author,
      tags: imported.tags,
      publishedAt: imported.publishedAt ?? existing.publishedAt,
      updatedAt: imported.updatedAt ?? existing.updatedAt,
      wordsCount: imported.wordsCount ?? existing.wordsCount,
      chaptersCount: imported.chaptersCount ?? existing.chaptersCount,
      kudosCount: imported.kudosCount ?? existing.kudosCount,
      hitsCount: imported.hitsCount ?? existing.hitsCount,
      commentsCount: imported.commentsCount ?? existing.commentsCount,
      userAddedDate: existing.userAddedDate, // Preserve original add date
      lastSyncDate: existing.lastSyncDate, // Preserve local sync date
      downloadedAt: existing.downloadedAt, // Preserve local download date
      lastUserOpened: existing.lastUserOpened, // Preserve local read date
      isFavorite: imported.isFavorite || existing.isFavorite, // Merge favorites
      categoryId: imported.categoryId ?? existing.categoryId,
      readingProgress: existing.readingProgress, // Preserve local reading progress
      isDownloaded: existing.isDownloaded, // Preserve local download status
      hasUpdate: existing.hasUpdate,
      summary: imported.summary ?? existing.summary,
    );
  }
  
  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      // For desktop, use Downloads folder if available
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
      return await getApplicationDocumentsDirectory();
    }
  }
  
  Future<List<String>> _getAutoDownloadCategories() async {
    final raw = _storage.settingsBox.get('auto_download_categories');
    if (raw == null) return <String>[];
    return List<String>.from(raw);
  }
  
  Future<void> _setAutoDownloadCategory(String category, bool enabled) async {
    final cats = await _getAutoDownloadCategories();
    if (enabled && !cats.contains(category)) {
      cats.add(category);
    } else if (!enabled) {
      cats.remove(category);
    }
    await _storage.settingsBox.put('auto_download_categories', cats);
  }
  
  Future<String?> _getDefaultCategory() async {
    return _storage.settingsBox.get('default_category') as String?;
  }
  
  Future<void> _setDefaultCategory(String category) async {
    await _storage.settingsBox.put('default_category', category);
  }
  
  /// Get the default category for batch imports
  Future<String> getDefaultCategoryOrCreate() async {
    final defaultCat = await _getDefaultCategory();
    if (defaultCat != null && defaultCat.isNotEmpty) {
      final cats = await _storage.getCategories();
      if (cats.contains(defaultCat)) {
        return defaultCat;
      }
    }
    
    // Check if 'default' category exists
    final cats = await _storage.getCategories();
    if (cats.isEmpty) {
      await _storage.addCategory('default');
      await _setDefaultCategory('default');
      return 'default';
    }
    
    // Use first category as default
    await _setDefaultCategory(cats.first);
    return cats.first;
  }
  
  /// Set the default category for batch imports
  Future<void> setDefaultCategory(String category) async {
    await _setDefaultCategory(category);
  }
  
  /// Check if a category has auto-download enabled
  Future<bool> isCategoryAutoDownload(String category) async {
    final cats = await _getAutoDownloadCategories();
    return cats.contains(category);
  }
  
  /// Set auto-download for a category
  Future<void> setCategoryAutoDownload(String category, bool enabled) async {
    await _setAutoDownloadCategory(category, enabled);
  }
}

/// Import mode determines how conflicts are handled
enum ImportMode {
  /// Add new works, update existing with merged data (preserve reading progress)
  merge,
  
  /// Add new works only, skip existing
  skipExisting,
  
  /// Replace all existing data with imported data
  replace,
}

/// Result of an import operation
class ImportResult {
  final int worksAdded;
  final int worksUpdated;
  final int worksSkipped;
  final int categoriesAdded;
  final int totalWorks;
  final int totalCategories;
  
  ImportResult({
    required this.worksAdded,
    required this.worksUpdated,
    required this.worksSkipped,
    required this.categoriesAdded,
    required this.totalWorks,
    required this.totalCategories,
  });
  
  @override
  String toString() {
    return 'ImportResult(added: $worksAdded, updated: $worksUpdated, skipped: $worksSkipped, categoriesAdded: $categoriesAdded)';
  }
  
  String toSummary() {
    final parts = <String>[];
    if (worksAdded > 0) parts.add('$worksAdded added');
    if (worksUpdated > 0) parts.add('$worksUpdated updated');
    if (worksSkipped > 0) parts.add('$worksSkipped skipped');
    if (categoriesAdded > 0) parts.add('$categoriesAdded categories added');
    return parts.isEmpty ? 'No changes' : parts.join(', ');
  }
}
