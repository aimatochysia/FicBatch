import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../models/history_entry.dart';
import '../models/work.dart';
import 'reader_screen.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageProvider);

    return SafeArea(
      child: FutureBuilder<List<HistoryEntry>>(
        future: _loadHistory(storage),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return const Center(
              child: Text('No reading history yet'),
            );
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              final chapterDisplay = entry.chapterName != null && entry.chapterName!.isNotEmpty
                  ? entry.chapterName!
                  : 'Chapter ${entry.chapterIndex + 1}';
              return ListTile(
                title: Text(entry.title),
                subtitle: Text(
                  '${entry.author}\n'
                  '$chapterDisplay',
                ),
                isThreeLine: true,
                trailing: Text(
                  _formatDate(entry.accessedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () async {
                  final work = storage.getWork(entry.workId);
                  if (work != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReaderScreen(work: work),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<HistoryEntry>> _loadHistory(storage) async {
    final historyList = (storage.settingsBox.get('history') as List?)?.cast<Map>() ?? [];
    return historyList
        .map((json) => HistoryEntry.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
