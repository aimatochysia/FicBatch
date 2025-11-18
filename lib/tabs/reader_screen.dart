import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import '../models/history_entry.dart';
import '../providers/storage_provider.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final Work work;

  const ReaderScreen({super.key, required this.work});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  List<Chapter> _chapters = [];
  double _currentScrollPosition = 0.0;
  int _currentChapterIndex = 0;
  Timer? _autosaveTimer;
  bool _autosaveEnabled = true;
  double _fontSize = 16.0;
  DateTime? _lastSaveTime;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadReaderSettings();
    _initWebView();
    _startAutosaveTimer();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _saveProgress();
    super.dispose();
  }

  Future<void> _loadReaderSettings() async {
    final storage = ref.read(storageProvider);
    final prefs = await storage.settingsBox.get('reader_settings');
    if (prefs != null) {
      final settings = Map<String, dynamic>.from(prefs);
      setState(() {
        _fontSize = (settings['fontSize'] ?? 16.0).toDouble();
        _autosaveEnabled = settings['autosave'] ?? true;
      });
    }
  }

  Future<void> _saveReaderSettings() async {
    final storage = ref.read(storageProvider);
    await storage.settingsBox.put('reader_settings', {
      'fontSize': _fontSize,
      'autosave': _autosaveEnabled,
    });
  }

  void _startAutosaveTimer() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_autosaveEnabled && _hasUnsavedChanges) {
        _saveProgress();
      }
    });
  }

  Future<void> _initWebView() async {
    try {
      final controller = WebViewController();
      setState(() => _controller = controller);

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('ReaderChannel', onMessageReceived: (message) {
          _handleMessage(message.message);
        })
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) async {
              setState(() => _isLoading = false);
              await _extractChapters();
              await _applyFontSize();
              await _restoreReadingPosition();
            },
          ),
        );

      final url =
          'https://archiveofourown.org/works/${widget.work.id}?view_full_work=true&view_adult=true';
      await controller.loadRequest(Uri.parse(url));
    } catch (e, stackTrace) {
      debugPrint('WebView initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reader: $e')),
        );
      }
    }
  }

  Future<void> _extractChapters() async {
    if (_controller == null) return;

    const js = '''
      (function() {
        const chapters = [];
        const chapterHeadings = document.querySelectorAll('h3.title');
        chapterHeadings.forEach((heading, index) => {
          const link = heading.querySelector('a');
          if (link) {
            chapters.push({
              index: index,
              title: link.textContent.trim(),
              anchor: heading.id || `chapter-\${index}`
            });
          }
        });
        return JSON.stringify(chapters);
      })();
    ''';

    try {
      final result = await _controller!.runJavaScriptReturningResult(js);
      final chaptersJson = jsonDecode(result.toString());
      setState(() {
        _chapters = (chaptersJson as List)
            .map((ch) => Chapter.fromJson(ch))
            .toList();
      });
    } catch (e) {
      debugPrint('Error extracting chapters: $e');
    }
  }

  Future<void> _applyFontSize() async {
    if (_controller == null) return;

    final js = '''
      (function() {
        const style = document.createElement('style');
        style.textContent = \`
          #workskin {
            font-size: ${_fontSize}px !important;
          }
        \`;
        document.head.appendChild(style);
      })();
    ''';

    await _controller!.runJavaScript(js);
  }

  Future<void> _restoreReadingPosition() async {
    if (_controller == null) return;

    final progress = widget.work.readingProgress;
    if (progress.hasProgress) {
      setState(() {
        _currentChapterIndex = progress.chapterIndex;
        _currentScrollPosition = progress.scrollPosition;
      });

      // Jump to saved position
      if (progress.chapterAnchor != null && progress.chapterAnchor!.isNotEmpty) {
        await _jumpToChapter(progress.chapterIndex);
      }

      // Scroll to saved position
      final js = 'window.scrollTo(0, ${progress.scrollPosition});';
      await _controller!.runJavaScript(js);
    }

    // Start tracking scroll position
    _startScrollTracking();
  }

  void _startScrollTracking() {
    const js = '''
      (function() {
        let lastPosition = 0;
        setInterval(() => {
          const currentPosition = window.pageYOffset;
          if (currentPosition !== lastPosition) {
            lastPosition = currentPosition;
            ReaderChannel.postMessage(JSON.stringify({
              type: 'scroll',
              position: currentPosition,
              maxScroll: document.documentElement.scrollHeight - window.innerHeight
            }));
          }
        }, 500);
      })();
    ''';
    _controller?.runJavaScript(js);
  }

  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'scroll') {
        final position = (data['position'] ?? 0).toDouble();
        final maxScroll = (data['maxScroll'] ?? 1).toDouble();

        setState(() {
          _currentScrollPosition = position;
          _hasUnsavedChanges = true;
        });

        // Update chapter index based on position
        _updateCurrentChapterIndex();

        // Check if completed
        if (maxScroll > 0 && position >= maxScroll * 0.95) {
          _markAsCompleted();
        }
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  void _updateCurrentChapterIndex() {
    // TODO: Implement proper chapter index detection based on scroll position
    // For now, keep the current index
  }

  Future<void> _saveProgress() async {
    if (!_hasUnsavedChanges) return;

    final storage = ref.read(storageProvider);
    final chapterAnchor = _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex].anchor
        : null;

    final updatedProgress = widget.work.readingProgress.copyWith(
      chapterIndex: _currentChapterIndex,
      chapterAnchor: chapterAnchor,
      lastReadAt: DateTime.now(),
      scrollPosition: _currentScrollPosition,
    );

    final updatedWork = widget.work.copyWith(
      readingProgress: updatedProgress,
      lastUserOpened: DateTime.now(),
    );

    await storage.saveWork(updatedWork);

    // Add to history
    await _addToHistory();

    setState(() {
      _hasUnsavedChanges = false;
      _lastSaveTime = DateTime.now();
    });
  }

  Future<void> _addToHistory() async {
    final storage = ref.read(storageProvider);
    final historyBox = storage.settingsBox;
    
    final historyList = (historyBox.get('history') as List?)?.cast<Map>() ?? [];
    
    // Add new entry
    final entry = HistoryEntry(
      workId: widget.work.id,
      title: widget.work.title,
      author: widget.work.author,
      chapterIndex: _currentChapterIndex,
      scrollPosition: _currentScrollPosition,
      accessedAt: DateTime.now(),
    );

    historyList.insert(0, entry.toJson());
    
    // Keep only last 100 entries
    if (historyList.length > 100) {
      historyList.removeRange(100, historyList.length);
    }

    await historyBox.put('history', historyList);
  }

  Future<void> _markAsCompleted() async {
    final storage = ref.read(storageProvider);
    final updatedProgress = widget.work.readingProgress.copyWith(
      isCompleted: true,
    );
    final updatedWork = widget.work.copyWith(readingProgress: updatedProgress);
    await storage.saveWork(updatedWork);
  }

  Future<void> _jumpToChapter(int index) async {
    if (_controller == null || index >= _chapters.length) return;

    final chapter = _chapters[index];
    final js = '''
      (function() {
        const element = document.getElementById('${chapter.anchor}');
        if (element) {
          element.scrollIntoView({ behavior: 'smooth' });
        }
      })();
    ''';

    await _controller!.runJavaScript(js);
    setState(() => _currentChapterIndex = index);
  }

  void _showChapterDrawer() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _chapters.length,
        itemBuilder: (context, index) {
          final chapter = _chapters[index];
          final isCurrent = index == _currentChapterIndex;
          return ListTile(
            title: Text(chapter.title),
            selected: isCurrent,
            onTap: () {
              Navigator.pop(context);
              _jumpToChapter(index);
            },
          );
        },
      ),
    );
  }

  void _showReaderSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reader Settings'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Font Size'),
                subtitle: Slider(
                  value: _fontSize,
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setDialogState(() => _fontSize = value);
                    _applyFontSize();
                  },
                ),
                trailing: SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                      text: _fontSize.round().toString(),
                    ),
                    onSubmitted: (value) {
                      final size = double.tryParse(value);
                      if (size != null && size >= 12 && size <= 32) {
                        setDialogState(() => _fontSize = size);
                        _applyFontSize();
                      }
                    },
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Autosave'),
                value: _autosaveEnabled,
                onChanged: (value) {
                  setDialogState(() => _autosaveEnabled = value);
                },
              ),
              ListTile(
                title: const Text('Theme'),
                trailing: PopupMenuButton<ThemeMode>(
                  onSelected: (mode) {
                    ref.read(themeProvider.notifier).setMode(mode);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    const PopupMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              _saveReaderSettings();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_controller != null)
              WebViewWidget(controller: _controller!),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            // Back button
            Positioned(
              top: 8,
              left: 8,
              child: FloatingActionButton.small(
                heroTag: 'back',
                onPressed: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back),
              ),
            ),
            // Chapter drawer button
            Positioned(
              top: 64,
              left: 8,
              child: FloatingActionButton.small(
                heroTag: 'chapters',
                onPressed: _showChapterDrawer,
                child: const Icon(Icons.menu),
              ),
            ),
            // Settings button
            Positioned(
              top: 8,
              right: 8,
              child: FloatingActionButton.small(
                heroTag: 'settings',
                onPressed: _showReaderSettings,
                child: const Icon(Icons.settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Chapter {
  final int index;
  final String title;
  final String anchor;

  Chapter({
    required this.index,
    required this.title,
    required this.anchor,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        index: json['index'],
        title: json['title'],
        anchor: json['anchor'],
      );
}
