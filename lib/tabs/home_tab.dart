import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/storage_provider.dart';
import '../services/ao3_service.dart';
import '../services/batch_import_service.dart';
import '../services/library_export_service.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _batchController = TextEditingController();
  bool _isBatchImporting = false;
  int _parsedCount = 0;
  String _importProgress = '';
  
  // Dashboard stats
  int _libraryCount = 0;
  int _readingStreak = 0;
  bool _checkedInToday = false;
  DateTime? _lastCheckIn;
  int _totalWordsRead = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardStats() async {
    final storage = ref.read(storageProvider);
    final works = storage.getAllWorks();
    final history = await storage.getHistory();
    
    // Calculate reading streak from history
    int streak = 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Check if checked in today
    final lastCheckInRaw = storage.settingsBox.get('last_check_in');
    DateTime? lastCheckIn;
    if (lastCheckInRaw != null) {
      lastCheckIn = DateTime.tryParse(lastCheckInRaw.toString());
    }
    
    bool checkedInToday = false;
    if (lastCheckIn != null) {
      final lastCheckInDate = DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day);
      checkedInToday = lastCheckInDate == todayDate;
    }
    
    // Calculate streak from check-in history
    final streakRaw = storage.settingsBox.get('check_in_streak') as int? ?? 0;
    streak = streakRaw;
    
    // Calculate total words read from works with reading progress
    int totalWords = 0;
    for (final work in works) {
      if (work.readingProgress.chapterIndex > 0 || work.readingProgress.scrollPosition > 0) {
        totalWords += work.wordsCount ?? 0;
      }
    }
    
    if (mounted) {
      setState(() {
        _libraryCount = works.length;
        _readingStreak = streak;
        _checkedInToday = checkedInToday;
        _lastCheckIn = lastCheckIn;
        _totalWordsRead = totalWords;
      });
    }
  }

  Future<void> _performCheckIn() async {
    final storage = ref.read(storageProvider);
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    
    // Get last check-in date
    final lastCheckInRaw = storage.settingsBox.get('last_check_in');
    DateTime? lastCheckIn;
    if (lastCheckInRaw != null) {
      lastCheckIn = DateTime.tryParse(lastCheckInRaw.toString());
    }
    
    int currentStreak = storage.settingsBox.get('check_in_streak') as int? ?? 0;
    
    if (lastCheckIn != null) {
      final lastCheckInDate = DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day);
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));
      
      if (lastCheckInDate == todayDate) {
        // Already checked in today
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already checked in today! 🎉')),
          );
        }
        return;
      } else if (lastCheckInDate == yesterdayDate) {
        // Consecutive day - increase streak
        currentStreak += 1;
      } else {
        // Streak broken - reset to 1
        currentStreak = 1;
      }
    } else {
      // First check-in ever
      currentStreak = 1;
    }
    
    // Save check-in
    await storage.settingsBox.put('last_check_in', now.toIso8601String());
    await storage.settingsBox.put('check_in_streak', currentStreak);
    
    if (mounted) {
      setState(() {
        _checkedInToday = true;
        _readingStreak = currentStreak;
        _lastCheckIn = now;
      });
      
      String message = 'Check-in complete! ';
      if (currentStreak == 1) {
        message += 'Welcome to your reading journey! 📚';
      } else if (currentStreak < 7) {
        message += '$currentStreak day streak! Keep it up! 🔥';
      } else if (currentStreak < 30) {
        message += '$currentStreak day streak! Amazing! 🌟';
      } else {
        message += '$currentStreak day streak! You\'re a legend! 👑';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _updateParsedCount() {
    final storage = ref.read(storageProvider);
    final exportService = LibraryExportService(storage);
    final batchService = BatchImportService(storage, Ao3Service(), exportService);
    setState(() {
      _parsedCount = batchService.validateInput(_batchController.text);
    });
  }

  Future<void> _batchImport() async {
    if (_batchController.text.trim().isEmpty) return;
    
    final storage = ref.read(storageProvider);
    final exportService = LibraryExportService(storage);
    final batchService = BatchImportService(storage, Ao3Service(), exportService);
    
    setState(() {
      _isBatchImporting = true;
      _importProgress = 'Starting import...';
    });
    
    try {
      final result = await batchService.importWorks(
        _batchController.text,
        onProgress: (current, total, title) {
          if (mounted) {
            setState(() {
              _importProgress = 'Importing $current of $total${title != null ? ': $title' : ''}';
            });
          }
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import complete: ${result.toSummary()}'),
            duration: const Duration(seconds: 4),
          ),
        );
        _batchController.clear();
        setState(() {
          _parsedCount = 0;
          _importProgress = '';
        });
        // Refresh dashboard stats
        _loadDashboardStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBatchImporting = false;
          _importProgress = '';
        });
      }
    }
  }

  String _formatWordsRead(int words) {
    if (words >= 1000000) {
      return '${(words / 1000000).toStringAsFixed(1)}M';
    } else if (words >= 1000) {
      return '${(words / 1000).toStringAsFixed(1)}K';
    }
    return words.toString();
  }

  String _getMotivationalMessage() {
    if (_libraryCount == 0) {
      return 'Start building your library! Import some works below.';
    } else if (_readingStreak == 0 && !_checkedInToday) {
      return 'Check in today to start your reading streak!';
    } else if (_readingStreak >= 30) {
      return 'Incredible dedication! You\'re a reading champion! 👑';
    } else if (_readingStreak >= 7) {
      return 'A whole week of reading! Keep the momentum going! 🌟';
    } else if (_readingStreak >= 3) {
      return 'Great progress! You\'re building a habit! 💪';
    } else if (_checkedInToday) {
      return 'You\'re doing great! Enjoy your reading today! 📖';
    }
    return 'Ready for your next reading adventure?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome/Greeting Section
              Text(
                _getGreeting(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getMotivationalMessage(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              
              // Dashboard Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.library_books,
                      label: 'Library',
                      value: _libraryCount.toString(),
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.local_fire_department,
                      label: 'Streak',
                      value: '$_readingStreak days',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.menu_book,
                      label: 'Words Read',
                      value: _formatWordsRead(_totalWordsRead),
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Daily Check-in Card
              Card(
                elevation: _checkedInToday ? 0 : 2,
                color: _checkedInToday 
                    ? colorScheme.primaryContainer 
                    : colorScheme.surface,
                child: InkWell(
                  onTap: _checkedInToday ? null : _performCheckIn,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _checkedInToday 
                                ? colorScheme.primary.withOpacity(0.2)
                                : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _checkedInToday ? Icons.check_circle : Icons.wb_sunny,
                            color: _checkedInToday 
                                ? colorScheme.primary 
                                : colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _checkedInToday 
                                    ? 'Checked in today!' 
                                    : 'Daily Check-in',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _checkedInToday 
                                    ? 'Come back tomorrow to keep your streak!'
                                    : 'Tap to check in and build your streak',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_checkedInToday)
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Batch import section
              Row(
                children: [
                  const Icon(Icons.file_download, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Batch Import Works',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Paste multiple AO3 links or work IDs (one per line, or separated by commas/spaces).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _batchController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'https://archiveofourown.org/works/123456\n'
                      '789012, 345678\n'
                      '/works/901234',
                  border: const OutlineInputBorder(),
                  counterText: _parsedCount > 0 ? '$_parsedCount work(s) detected' : null,
                ),
                onChanged: (_) => _updateParsedCount(),
              ),
              const SizedBox(height: 12),
              if (_importProgress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_importProgress)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isBatchImporting || _parsedCount == 0
                          ? null
                          : _batchImport,
                      icon: _isBatchImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isBatchImporting 
                          ? 'Importing...' 
                          : 'Import ${_parsedCount > 0 ? '$_parsedCount Works' : 'Works'}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _batchController.text.isEmpty
                        ? null
                        : () {
                            _batchController.clear();
                            setState(() => _parsedCount = 0);
                          },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Info section (collapsed into an expandable)
              ExpansionTile(
                leading: const Icon(Icons.info_outline, size: 20),
                title: const Text('Supported URL formats'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  Text(
                    '• Full URL: https://archiveofourown.org/works/123456\n'
                    '• Chapter URL: https://archiveofourown.org/works/123456/chapters/789\n'
                    '• Short path: /works/123456\n'
                    '• Work ID only: 123456',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning! ☀️';
    } else if (hour < 17) {
      return 'Good afternoon! 📚';
    } else {
      return 'Good evening! 🌙';
    }
  }
}
