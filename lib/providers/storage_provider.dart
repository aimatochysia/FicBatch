import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../models/work.dart';

final storageProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService not initialized');
});

final workListProvider = StreamProvider<List<Work>>((ref) async* {
  final storage = ref.watch(storageProvider);
  final box = storage.worksBox;

  yield box.values.toList();

  await for (final _ in box.watch()) {
    yield box.values.toList();
  }
});

final workActionsProvider = Provider<WorkActions>((ref) {
  final storage = ref.watch(storageProvider);
  return WorkActions(storage);
});

class WorkActions {
  final StorageService storage;
  WorkActions(this.storage);

  Future<void> addOrUpdateWork(Work work) async => storage.saveWork(work);
  Future<void> deleteWork(String id) async => storage.deleteWork(id);
  Future<void> clearLibrary() async => storage.clearAll();
}
