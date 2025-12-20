import 'package:flutter/foundation.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import 'storage_service.dart';
import 'ao3_service.dart';
import 'library_export_service.dart';

/// Service for batch importing works from multiple AO3 URLs
class BatchImportService {
  final StorageService _storage;
  final Ao3Service _ao3;
  final LibraryExportService _exportService;
  
  BatchImportService(this._storage, this._ao3, this._exportService);
  
  /// Parse work IDs from a text input containing multiple URLs/IDs
  /// Supports various formats:
  /// - Full URLs: https://archiveofourown.org/works/123456
  /// - Short URLs: /works/123456
  /// - Work IDs: 123456
  /// - Separated by: newlines, commas, spaces, tabs
  List<String> parseWorkIds(String input) {
    final workIds = <String>[];
    
    // Split by common separators
    final parts = input.split(RegExp(r'[\n,\s\t]+'));
    
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      
      // Try to extract work ID from various formats
      final workId = _extractWorkId(trimmed);
      if (workId != null && !workIds.contains(workId)) {
        workIds.add(workId);
      }
    }
    
    return workIds;
  }
  
  /// Extract work ID from a URL or ID string
  String? _extractWorkId(String input) {
    // If it's already just numbers, it's a work ID
    if (RegExp(r'^\d+$').hasMatch(input)) {
      return input;
    }
    
    // Try to parse as URL
    final uri = Uri.tryParse(input);
    if (uri != null) {
      return _extractWorkIdFromUri(uri);
    }
    
    // Try to extract from path-like string
    final match = RegExp(r'/works/(\d+)').firstMatch(input);
    return match?.group(1);
  }
  
  /// Extract work ID from a parsed URI
  String? _extractWorkIdFromUri(Uri uri) {
    final pathSegments = uri.pathSegments;
    final worksIndex = pathSegments.indexOf('works');
    if (worksIndex >= 0 && worksIndex + 1 < pathSegments.length) {
      final idSegment = pathSegments[worksIndex + 1];
      // Handle chapter URLs: /works/123456/chapters/789
      final idMatch = RegExp(r'^(\d+)').firstMatch(idSegment);
      return idMatch?.group(1);
    }
    return null;
  }
  
  /// Batch import works from a list of URLs/IDs
  /// Returns a result with success/failure counts
  Future<BatchImportResult> importWorks(
    String input, {
    String? categoryId,
    Duration throttleDelay = const Duration(milliseconds: 1000),
    void Function(int current, int total, String? currentTitle)? onProgress,
  }) async {
    final workIds = parseWorkIds(input);
    if (workIds.isEmpty) {
      return BatchImportResult(
        totalParsed: 0,
        worksAdded: 0,
        worksFailed: 0,
        worksSkipped: 0,
        errors: [],
      );
    }
    
    // Get or create the target category
    final targetCategory = categoryId ?? await _exportService.getDefaultCategoryOrCreate();
    
    final results = BatchImportResult(
      totalParsed: workIds.length,
      worksAdded: 0,
      worksFailed: 0,
      worksSkipped: 0,
      errors: [],
    );
    
    for (int i = 0; i < workIds.length; i++) {
      final workId = workIds[i];
      
      try {
        onProgress?.call(i + 1, workIds.length, null);
        
        // Check if work already exists
        final existingWork = _storage.getWork(workId);
        if (existingWork != null) {
          // Work exists, just add to category if needed
          final existingCats = await _storage.getCategoriesForWork(workId);
          if (!existingCats.contains(targetCategory)) {
            existingCats.add(targetCategory);
            await _storage.setCategoriesForWork(workId, existingCats);
          }
          results.worksSkipped++;
          continue;
        }
        
        // Fetch work metadata from AO3
        final work = await _fetchWorkFromAo3(workId);
        if (work == null) {
          results.worksFailed++;
          results.errors.add('Failed to fetch work $workId');
          continue;
        }
        
        onProgress?.call(i + 1, workIds.length, work.title);
        
        // Save work and add to category
        await _storage.saveWork(work);
        await _storage.setCategoriesForWork(workId, {targetCategory});
        results.worksAdded++;
        
        // Throttle to avoid overwhelming AO3
        if (i < workIds.length - 1) {
          await Future.delayed(throttleDelay);
        }
      } catch (e) {
        debugPrint('[BatchImportService] Error importing work $workId: $e');
        results.worksFailed++;
        results.errors.add('Error importing $workId: $e');
      }
    }
    
    return results;
  }
  
  /// Fetch a work from AO3 by ID
  Future<Work?> _fetchWorkFromAo3(String workId) async {
    try {
      final meta = await _ao3.fetchWorkMetadata(workId);
      
      return Work(
        id: workId,
        title: meta['title'] as String? ?? 'Untitled',
        author: meta['author'] as String? ?? 'Unknown',
        tags: meta['tags'] is List ? List<String>.from(meta['tags']) : [],
        publishedAt: meta['publishedAt'] as DateTime?,
        updatedAt: meta['updatedAt'] as DateTime?,
        wordsCount: meta['wordsCount'] as int?,
        chaptersCount: meta['chaptersCount'] as int?,
        kudosCount: meta['kudosCount'] as int?,
        hitsCount: meta['hitsCount'] as int?,
        commentsCount: meta['commentsCount'] as int?,
        userAddedDate: DateTime.now(),
        lastSyncDate: DateTime.now(),
        readingProgress: ReadingProgress.empty(),
        summary: meta['summary'] as String?,
      );
    } catch (e) {
      debugPrint('[BatchImportService] Error fetching work $workId: $e');
      return null;
    }
  }
  
  /// Validate input and return count of valid work IDs
  int validateInput(String input) {
    return parseWorkIds(input).length;
  }
}

/// Result of a batch import operation
class BatchImportResult {
  int totalParsed;
  int worksAdded;
  int worksFailed;
  int worksSkipped;
  List<String> errors;
  
  BatchImportResult({
    required this.totalParsed,
    required this.worksAdded,
    required this.worksFailed,
    required this.worksSkipped,
    required this.errors,
  });
  
  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => worksFailed == 0;
  
  String toSummary() {
    final parts = <String>[];
    if (worksAdded > 0) parts.add('$worksAdded added');
    if (worksSkipped > 0) parts.add('$worksSkipped already in library');
    if (worksFailed > 0) parts.add('$worksFailed failed');
    return parts.isEmpty ? 'No works processed' : parts.join(', ');
  }
}
