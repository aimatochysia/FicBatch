import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import '../services/storage_service.dart';
import '../services/ao3_service.dart';
import '../providers/storage_provider.dart';

final workRepositoryProvider = Provider<WorkRepository>((ref) {
  final storage = ref.watch(storageProvider);
  return WorkRepository(storage, Ao3Service());
});

class WorkRepository {
  final StorageService _storage;
  final Ao3Service _ao3;

  WorkRepository(this._storage, this._ao3);

  Future<Work> addFromUrl(String urlOrId, {String? categoryId}) async {
    final meta = await _ao3.fetchWorkMetadata(urlOrId);
    final id =
        _idFromUrl(urlOrId) ?? DateTime.now().millisecondsSinceEpoch.toString();

    final work = Work(
      id: id,
      title: meta['title'] as String,
      author: meta['author'] as String,
      tags: meta['tags'] is List ? List<String>.from(meta['tags']) : [],
      publishedAt: meta['publishedAt'] ?? DateTime.now(),
      updatedAt: meta['updatedAt'] ?? DateTime.now(),
      wordsCount: meta['wordsCount'] ?? 0,
      chaptersCount: meta['chaptersCount'] ?? 0,
      kudosCount: meta['kudosCount'] ?? 0,
      hitsCount: meta['hitsCount'] ?? 0,
      commentsCount: meta['commentsCount'] ?? 0,
      userAddedDate: DateTime.now(),
      lastSyncDate: DateTime.now(),
      downloadedAt: DateTime.now(),
      lastUserOpened: DateTime.now(),
      isFavorite: false,
      categoryId: categoryId,
      readingProgress: ReadingProgress(
        chapterIndex: 0,
        chapterAnchor: '',
        lastReadAt: DateTime.now(),
        scrollPosition: 0.0,
      ),
      isDownloaded: false,
      hasUpdate: false,
    );

    await _storage.saveWork(work);
    return work;
  }

  List<Work> allLocalWorks() => _storage.getAllWorks();

  Work? getWork(String id) => _storage.getWork(id);

  Future<void> deleteWork(String id) async => _storage.deleteWork(id);

  String? _idFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final worksIndex = segments.indexOf('works');
    if (worksIndex >= 0 && worksIndex + 1 < segments.length) {
      return segments[worksIndex + 1];
    }
    return null;
  }
}
