import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import 'reader_screen.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageProvider);

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
                  'History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear history',
                  onPressed: () => _showClearDialog(context, ref),
                ),
              ],
            ),
          ),
          
          // History list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: storage.getHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final history = snapshot.data ?? [];

                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reading history yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Works you open will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group history by day
                final groupedHistory = _groupByDay(history);
                
                return ListView.builder(
                  itemCount: groupedHistory.length,
                  itemBuilder: (context, index) {
                    final group = groupedHistory[index];
                    return _buildDayGroup(context, ref, group);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Group history entries by day
  List<_DayGroup> _groupByDay(List<Map<String, dynamic>> history) {
    final groups = <_DayGroup>[];
    DateTime? currentDay;
    List<Map<String, dynamic>> currentEntries = [];
    
    for (final entry in history) {
      final accessedAt = DateTime.parse(entry['accessedAt']);
      final day = DateTime(accessedAt.year, accessedAt.month, accessedAt.day);
      
      if (currentDay == null || currentDay != day) {
        if (currentEntries.isNotEmpty) {
          groups.add(_DayGroup(date: currentDay!, entries: currentEntries));
        }
        currentDay = day;
        currentEntries = [entry];
      } else {
        currentEntries.add(entry);
      }
    }
    
    // Add the last group
    if (currentEntries.isNotEmpty && currentDay != null) {
      groups.add(_DayGroup(date: currentDay, entries: currentEntries));
    }
    
    return groups;
  }

  Widget _buildDayGroup(BuildContext context, WidgetRef ref, _DayGroup group) {
    final storage = ref.watch(storageProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day divider
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            _formatDayHeader(group.date),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const Divider(height: 1),
        
        // Entries for this day
        ...group.entries.map((entry) => _buildHistoryTile(context, storage, entry)),
      ],
    );
  }

  Widget _buildHistoryTile(BuildContext context, dynamic storage, Map<String, dynamic> entry) {
    final workId = entry['workId'] as String? ?? '';
    final title = entry['title'] as String? ?? 'Unknown Work';
    final author = entry['author'] as String? ?? 'Unknown Author';
    final accessedAtStr = entry['accessedAt'] as String?;
    
    // Skip entries with missing required fields
    if (workId.isEmpty || accessedAtStr == null) {
      return const SizedBox.shrink();
    }
    
    final accessedAt = DateTime.tryParse(accessedAtStr);
    if (accessedAt == null) {
      return const SizedBox.shrink();
    }
    
    return ListTile(
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'by $author',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(accessedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        // Try to get work from library, otherwise create temporary work
        final work = storage.getWork(workId);
        final workToOpen = work ?? Work(
          id: workId,
          title: title,
          author: author,
          tags: [],
          userAddedDate: DateTime.now(),
          readingProgress: ReadingProgress.empty(),
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(work: workToOpen),
          ),
        );
      },
    );
  }

  String _formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      // Show day name for last week
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } else {
      // Show full date
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showClearDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all reading history?'),
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
      final storage = ref.read(storageProvider);
      await storage.clearHistory();
      // Force rebuild
      (context as Element).markNeedsBuild();
    }
  }
}

/// Helper class for grouping history entries by day
class _DayGroup {
  final DateTime date;
  final List<Map<String, dynamic>> entries;
  
  _DayGroup({required this.date, required this.entries});
}
