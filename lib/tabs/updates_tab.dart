import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../providers/storage_provider.dart';
import 'reader_screen.dart';

/// Provider for work updates list
final workUpdatesProvider = StreamProvider<List<WorkUpdate>>((ref) async* {
  final storage = ref.watch(storageProvider);
  
  // Initial load
  yield await SyncService.getUpdates();
  
  // Listen for changes
  await for (final _ in storage.settingsBox.watch(key: 'work_updates')) {
    yield await SyncService.getUpdates();
  }
});

/// Provider for unread count
final unreadCountProvider = FutureProvider<int>((ref) async {
  final updates = await ref.watch(workUpdatesProvider.future);
  return updates.where((u) => !u.isRead).length;
});

class UpdatesTab extends ConsumerWidget {
  const UpdatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(workUpdatesProvider);
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text(
                  'Updates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Clear all button
                updatesAsync.when(
                  data: (updates) => updates.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_all),
                          tooltip: 'Clear all updates',
                          onPressed: () => _showClearDialog(context, ref),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          // Updates list
          Expanded(
            child: updatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (updates) {
                if (updates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No updates',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Works in your library will appear here when updated',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: updates.length,
                  itemBuilder: (context, index) {
                    final update = updates[index];
                    return _UpdateTile(update: update);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Updates'),
        content: const Text('Are you sure you want to clear all updates?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await SyncService.clearAllUpdates();
      ref.invalidate(workUpdatesProvider);
    }
  }
}

class _UpdateTile extends ConsumerWidget {
  final WorkUpdate update;
  
  const _UpdateTile({required this.update});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageProvider);
    final work = storage.getWork(update.workId);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: update.isRead 
                ? Colors.transparent 
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          update.workTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: update.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.newUpdatedAt != null)
              Text(
                'Updated: ${_formatDate(update.newUpdatedAt!)}',
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              'Detected: ${_formatDateTime(update.detectedAt)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        trailing: work != null
            ? const Icon(Icons.chevron_right)
            : const Icon(Icons.warning, color: Colors.orange),
        onTap: () async {
          // Mark as read
          await SyncService.markUpdateAsRead(update.workId);
          ref.invalidate(workUpdatesProvider);
          
          // Navigate to reader if work exists
          if (work != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReaderScreen(work: work),
              ),
            );
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Work no longer in library'),
              ),
            );
          }
        },
      ),
    );
  }
  
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
  
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return _formatDate(dt);
  }
}
