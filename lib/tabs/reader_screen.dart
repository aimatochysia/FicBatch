import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
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
  win.WebviewController? _winController;
  bool _isWindows = Platform.isWindows;
  bool _isLoading = true;
  bool _isContentReady = false; // Track if content is ready to display
  List<Chapter> _chapters = [];
  double _currentScrollPosition = 0.0;
  int _currentChapterIndex = 0;
  Timer? _autosaveTimer;
  bool _autosaveEnabled = true;
  double _fontSize = 16.0;
  double _scrollSpeed = 1.0; // 1.0 is default, 0.5 is slower, 2.0 is faster
  DateTime? _lastSaveTime;
  bool _hasUnsavedChanges = false;
  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
        _scrollSpeed = (settings['scrollSpeed'] ?? 1.0).toDouble();
      });
    }
  }

  Future<void> _saveReaderSettings() async {
    final storage = ref.read(storageProvider);
    await storage.settingsBox.put('reader_settings', {
      'fontSize': _fontSize,
      'autosave': _autosaveEnabled,
      'scrollSpeed': _scrollSpeed,
    });
  }

  void _startAutosaveTimer() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_autosaveEnabled && _hasUnsavedChanges) {
        _saveProgress();
      }
    });
  }

  /// Check if a URL is for another AO3 work
  bool _isAnotherWork(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    // Check if it's an AO3 work URL that's NOT the current work
    final workMatch = RegExp(r'/works/(\d+)').firstMatch(url);
    if (workMatch != null) {
      final urlWorkId = workMatch.group(1);
      return urlWorkId != widget.work.id;
    }
    return false;
  }

  /// Check if a URL is allowed for navigation within the current work
  bool _isAllowedNavigation(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    // Allow same-page anchor navigation
    if (url.startsWith('#')) return true;
    
    // Allow navigation within the current work (including chapters, comments, etc.)
    final workId = widget.work.id;
    final workPattern = RegExp('^https://archiveofourown\\.org/works/$workId(/|\$|\\?)');
    if (workPattern.hasMatch(url)) return true;
    
    // Allow about:blank and similar
    if (uri.scheme == 'about' || uri.scheme == 'javascript') return true;
    
    return false;
  }

  /// Get current URL from Windows webview (robust implementation)
  Future<String?> _getWindowsCurrentUrl() async {
    if (_winController == null) return null;
    try {
      final direct = await _winController!.executeScript('window.location.href');
      if (direct is List && direct.isNotEmpty) {
        return _stripQuotes(direct.first.toString()).trim();
      }
      if (direct is String && direct.isNotEmpty) {
        return _stripQuotes(direct).trim();
      }
    } catch (_) {}

    try {
      final json = await _winController!.executeScript('JSON.stringify(window.location.href)');
      if (json is List && json.isNotEmpty) {
        final s = json.first.toString();
        return _stripQuotes(s).trim();
      }
      if (json is String && json.isNotEmpty) {
        return _stripQuotes(json).trim();
      }
    } catch (e) {
      debugPrint('Error getting Windows URL: $e');
    }
    return null;
  }

  /// Strip surrounding quotes from a string
  String _stripQuotes(String s) {
    final t = s.trim();
    if (t.length >= 2 &&
        ((t.startsWith('"') && t.endsWith('"')) ||
            (t.startsWith("'") && t.endsWith("'")))) {
      return t.substring(1, t.length - 1).replaceAll(r'\"', '"');
    }
    return t;
  }

  /// Handle navigation changes in Windows webview
  void _handleWindowsNavigation(String url) {
    // If navigating to another work, close reader and pass URL back
    if (_isAnotherWork(url)) {
      debugPrint('Windows reader: navigating to another work: $url');
      Navigator.pop(context, url);
      return;
    }
    
    // If navigating to non-work AO3 URL that's not allowed, close and pass back
    if (!_isAllowedNavigation(url) && url.contains('archiveofourown.org')) {
      debugPrint('Windows reader: navigating to non-allowed AO3 URL: $url');
      Navigator.pop(context, url);
      return;
    }
    
    // Block external (non-AO3) URLs by navigating back
    if (!url.contains('archiveofourown.org') && !url.startsWith('about:')) {
      debugPrint('Windows reader: blocked navigation to external URL: $url');
      _winController?.goBack();
    }
  }

  /// Inject JavaScript to intercept link clicks in Windows webview
  Future<void> _injectNavigationInterceptor() async {
    if (_winController == null) return;

    final workId = widget.work.id;
    final js = '''
      (function() {
        // Remove any existing interceptor
        if (window.__fb_nav_interceptor) {
          document.removeEventListener('click', window.__fb_nav_interceptor, true);
        }
        
        window.__fb_nav_interceptor = function(e) {
          const link = e.target.closest('a');
          if (!link || !link.href) return;
          
          const url = link.href;
          // Pattern matches: /works/{workId}/ or /works/{workId}? or /works/{workId} at end
          const currentWorkPattern = new RegExp('/works/$workId(/|\\\\?|\$)');
          
          // Allow navigation within current work
          if (currentWorkPattern.test(url)) return;
          
          // Allow anchor links
          if (url.startsWith('#') || url.startsWith(window.location.href + '#')) return;
          
          // Block and report other navigation attempts
          if (url.includes('archiveofourown.org')) {
            e.preventDefault();
            e.stopPropagation();
            // Send message to Dart for another work or non-allowed URL
            if (window.chrome && chrome.webview && chrome.webview.postMessage) {
              chrome.webview.postMessage(JSON.stringify({
                type: 'navigation',
                url: url
              }));
            }
          } else {
            // Block external URLs entirely
            e.preventDefault();
            e.stopPropagation();
            console.log('[FicBatch] Blocked external URL:', url);
          }
        };
        
        document.addEventListener('click', window.__fb_nav_interceptor, true);
      })();
    ''';

    try {
      await _winController!.executeScript(js);
    } catch (e) {
      debugPrint('Error injecting navigation interceptor: $e');
    }
  }

  Future<void> _initWebView() async {
    try {
      if (_isWindows) {
        // Windows webview
        _winController = win.WebviewController();
        await _winController!.initialize();
        await _winController!.setBackgroundColor(Colors.transparent);
        await _winController!.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
        
        _winController!.webMessage.listen((event) {
          try {
            final s = event?.toString() ?? '';
            if (s.isNotEmpty) _handleMessage(s);
          } catch (e) {
            debugPrint('Error handling Windows webview message: $e');
          }
        });
        
        // Listen for URL changes to handle navigation control
        _winController!.historyChanged.listen((event) async {
          final currentUrl = await _getWindowsCurrentUrl();
          if (currentUrl != null) {
            _handleWindowsNavigation(currentUrl);
          }
        });
        
        await _winController!.loadUrl(
          'https://archiveofourown.org/works/${widget.work.id}?view_full_work=true&view_adult=true',
        );
        
        // Wait a bit for page to load then apply all modifications
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await _removeUnwantedElements();
          await _extractChapters();
          await _applyThemeStyles();
          await _applyFontSize();
          if (_isDesktop) await _applyScrollSpeed();
          await _injectNavigationInterceptor();
          await _restoreReadingPosition();
          // Now content is ready to display
          setState(() {
            _isLoading = false;
            _isContentReady = true;
          });
        }
      } else {
        // Android/iOS webview
        final controller = WebViewController();
        
        controller
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel('ReaderChannel', onMessageReceived: (message) {
            _handleMessage(message.message);
          })
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) {
                final url = request.url;
                
                // If navigating to another work or non-work AO3 URL, 
                // close reader and pass URL back to browse tab
                if (_isAnotherWork(url) || 
                    (!_isAllowedNavigation(url) && url.contains('archiveofourown.org'))) {
                  Navigator.pop(context, url);
                  return NavigationDecision.prevent;
                }
                
                // Allow navigation within current work
                if (_isAllowedNavigation(url)) {
                  return NavigationDecision.navigate;
                }
                
                // Block external (non-AO3) URLs
                debugPrint('Blocked navigation to external URL: $url');
                return NavigationDecision.prevent;
              },
              onPageFinished: (url) async {
                if (mounted) {
                  await _removeUnwantedElements();
                  await _extractChapters();
                  await _applyThemeStyles();
                  await _applyFontSize();
                  if (_isDesktop) await _applyScrollSpeed();
                  await _restoreReadingPosition();
                  // Now content is ready to display
                  setState(() {
                    _isLoading = false;
                    _isContentReady = true;
                  });
                }
              },
            ),
          );

        final url =
            'https://archiveofourown.org/works/${widget.work.id}?view_full_work=true&view_adult=true';
        await controller.loadRequest(Uri.parse(url));
        
        if (mounted) {
          setState(() => _controller = controller);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('WebView initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isContentReady = true;
        });
        
        // Schedule the snackbar to show after the frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading reader: $e'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    }
  }

  /// Remove unwanted elements from the page (div & nav inside header, footer div)
  Future<void> _removeUnwantedElements() async {
    if (_controller == null && _winController == null) return;

    const js = '''
      (function() {
        // Remove div and nav elements inside header
        const header = document.querySelector('header');
        if (header) {
          const divsInHeader = header.querySelectorAll('div');
          divsInHeader.forEach(div => div.remove());
          const navsInHeader = header.querySelectorAll('nav');
          navsInHeader.forEach(nav => nav.remove());
        }
        
        // Remove footer div
        const footer = document.getElementById('footer');
        if (footer) {
          footer.remove();
        }
      })();
    ''';

    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(js);
      } else if (_controller != null) {
        await _controller!.runJavaScript(js);
      }
    } catch (e) {
      debugPrint('Error removing unwanted elements: $e');
    }
  }

  Future<void> _extractChapters() async {
    if (_controller == null && _winController == null) return;

    const js = '''
      (function() {
        const chapters = [];
        const chapterHeadings = document.querySelectorAll('h3.title');
        let chapterIndex = 0;
        
        chapterHeadings.forEach((heading) => {
          const link = heading.querySelector('a');
          // Only include if the link points to a chapter (contains /chapters/)
          if (link && link.href && link.href.includes('/chapters/')) {
            // Get the full text content of the h3, which includes text after the link
            // e.g., "Chapter 1: It's Not Always Sunny in Quantico"
            const fullTitle = heading.textContent.trim().replace(/\\s+/g, ' ');
            
            // AO3 uses 1-indexed chapter IDs (chapter-1, chapter-2, etc.)
            // Use heading.id if available, otherwise use 1-indexed fallback
            const chapterNum = chapterIndex + 1;
            
            chapters.push({
              index: chapterIndex,
              title: fullTitle,
              anchor: heading.id || ('chapter-' + chapterNum)
            });
            chapterIndex++;
          }
        });
        return JSON.stringify(chapters);
      })();
    ''';

    try {
      String? result;
      if (_isWindows && _winController != null) {
        result = await _winController!.executeScript(js);
      } else if (_controller != null) {
        final rawResult = await _controller!.runJavaScriptReturningResult(js);
        result = rawResult.toString();
      }
      
      if (result != null && result.isNotEmpty) {
        // Handle different result formats from different platforms
        // Mobile webview often returns double-quoted strings
        String jsonStr = result;
        
        // Strip outer quotes if present (mobile webview issue)
        jsonStr = _stripQuotes(jsonStr);
        
        // Unescape escaped quotes if present
        if (jsonStr.contains(r'\"')) {
          jsonStr = jsonStr.replaceAll(r'\"', '"');
        }
        
        try {
          final chaptersJson = jsonDecode(jsonStr);
          if (chaptersJson is List) {
            setState(() {
              _chapters = chaptersJson
                  .map((ch) => Chapter.fromJson(Map<String, dynamic>.from(ch)))
                  .toList();
            });
            debugPrint('Extracted ${_chapters.length} chapters');
          }
        } catch (e) {
          debugPrint('Error parsing chapters JSON: $e');
          debugPrint('Raw result: $result');
          debugPrint('Processed jsonStr: $jsonStr');
        }
      }
    } catch (e) {
      debugPrint('Error extracting chapters: $e');
    }
  }

  Future<void> _applyThemeStyles() async {
    if (_controller == null && _winController == null) return;

    // Get the current theme mode
    final themeMode = ref.read(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final mode = isDark ? 'dark' : 'light';

    // Use the same DarkReader approach as browse tab
    final js = _buildDarkReaderBootstrapJs(mode);

    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(js);
      } else if (_controller != null) {
        await _controller!.runJavaScript(js);
      }
    } catch (e) {
      debugPrint('Error applying theme styles: $e');
    }
  }

  String _buildDarkReaderBootstrapJs(String mode) {
    return '''
(function () {
  try {
    var MODE = '${mode}' === 'dark' ? 'dark' : 'light';
    var CDN = 'https://cdn.jsdelivr.net/npm/darkreader@4.9.58/darkreader.min.js';
    var SCRIPT_ID = '__fb_darkreader_script';
    var pendingMode = MODE;

    function applyMode(mode) {
      try {
        if (mode === 'dark') {
          try { if (window.DarkReader && DarkReader.setFetchMethod) DarkReader.setFetchMethod(window.fetch.bind(window)); } catch(_) {}
          var theme = { brightness: 100, contrast: 100, sepia: 0 };
          var fixes = {
            invert: [],
            ignoreInlineStyle: [],
            ignoreImageAnalysis: [],
            css: ''
          };
          DarkReader.enable(theme, fixes);
          try { document.documentElement.style.colorScheme = 'dark'; } catch(_) {}
        } else {
          if (window.DarkReader && DarkReader.isEnabled && DarkReader.isEnabled()) {
            DarkReader.disable();
          }
          try { document.documentElement.style.colorScheme = 'light'; } catch(_) {}
        }
      } catch (e) {
        console.log('[FB-DarkReader] applyMode error', e);
      }
    }

    if (!window.__fb_setTheme) {
      window.__fb_setTheme = function(m) {
        pendingMode = (m === 'dark') ? 'dark' : 'light';
        if (window.DarkReader) applyMode(pendingMode);
      };
    } else {
      pendingMode = MODE;
    }

    if (window.DarkReader) {
      applyMode(pendingMode);
    } else {
      var s = document.getElementById(SCRIPT_ID);
      if (!s) {
        s = document.createElement('script');
        s.id = SCRIPT_ID;
        s.src = CDN;
        s.async = true;
        s.onload = function() {
          try { if (DarkReader && DarkReader.setFetchMethod) DarkReader.setFetchMethod(window.fetch.bind(window)); } catch(_) {}
          applyMode(pendingMode);
        };
        s.onerror = function(e) { console.log('[FB-DarkReader] script load error', e); };
        (document.head || document.documentElement).appendChild(s);
      } else {
        s.addEventListener('load', function(){ applyMode(pendingMode); }, { once: true });
      }
    }

    if (window.__fb_setTheme) window.__fb_setTheme(MODE);
  } catch (e) {
    console.log('[FB-DarkReader] bootstrap error', e);
  }
})();
''';
  }

  Future<void> _applyFontSize() async {
    if (_controller == null && _winController == null) return;

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

    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(js);
      } else if (_controller != null) {
        await _controller!.runJavaScript(js);
      }
    } catch (e) {
      debugPrint('Error applying font size: $e');
    }
  }

  Future<void> _applyScrollSpeed() async {
    if (_controller == null && _winController == null) return;

    final js = '''
      (function() {
        // Remove any existing scroll speed handler
        if (window.__fbScrollSpeedHandler) {
          document.removeEventListener('wheel', window.__fbScrollSpeedHandler);
        }
        
        // Create new handler with current speed
        window.__fbScrollSpeedHandler = function(e) {
          if (e.ctrlKey || e.metaKey) return; // Don't interfere with zoom
          
          e.preventDefault();
          const speed = $_scrollSpeed;
          const delta = e.deltaY * speed;
          
          window.scrollBy({
            top: delta,
            behavior: 'auto'
          });
        };
        
        // Add the handler
        document.addEventListener('wheel', window.__fbScrollSpeedHandler, { passive: false });
      })();
    ''';

    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(js);
      } else if (_controller != null) {
        await _controller!.runJavaScript(js);
      }
    } catch (e) {
      debugPrint('Error applying scroll speed: $e');
    }
  }

  Future<void> _restoreReadingPosition() async {
    if (_controller == null && _winController == null) return;

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
      try {
        if (_isWindows && _winController != null) {
          await _winController!.executeScript(js);
        } else if (_controller != null) {
          await _controller!.runJavaScript(js);
        }
      } catch (e) {
        debugPrint('Error restoring scroll position: $e');
      }
    }

    // Start tracking scroll position
    _startScrollTracking();
  }

  void _startScrollTracking() {
    if (_isWindows) {
      // For Windows, use polling since we can't use JavaScript channels
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _checkScrollPosition();
      });
    } else {
      // For Android/iOS, use JavaScript channel
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
  }

  Future<void> _checkScrollPosition() async {
    if (_winController == null) return;
    
    try {
      final js = '''
        (function() {
          return JSON.stringify({
            position: window.pageYOffset,
            maxScroll: document.documentElement.scrollHeight - window.innerHeight
          });
        })();
      ''';
      
      final result = await _winController!.executeScript(js);
      if (result != null) {
        final data = jsonDecode(result);
        final position = (data['position'] ?? 0).toDouble();
        final maxScroll = (data['maxScroll'] ?? 1).toDouble();
        
        setState(() {
          _currentScrollPosition = position;
          _hasUnsavedChanges = true;
        });

        // Check if completed
        if (maxScroll > 0 && position >= maxScroll * 0.95) {
          _markAsCompleted();
        }
      }
    } catch (e) {
      debugPrint('Error checking scroll position: $e');
    }
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
      } else if (data['type'] == 'navigation') {
        // Handle navigation message from Windows webview
        final url = data['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          debugPrint('Windows reader: navigation message for URL: $url');
          Navigator.pop(context, url);
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
    final chapterName = _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex].title
        : null;

    final updatedProgress = widget.work.readingProgress.copyWith(
      chapterIndex: _currentChapterIndex,
      chapterAnchor: chapterAnchor,
      chapterName: chapterName,
      lastReadAt: DateTime.now(),
      scrollPosition: _currentScrollPosition,
    );

    final updatedWork = widget.work.copyWith(
      readingProgress: updatedProgress,
      lastUserOpened: DateTime.now(),
    );

    await storage.saveWork(updatedWork);

    // Add to history
    await _addToHistory(chapterName);

    setState(() {
      _hasUnsavedChanges = false;
      _lastSaveTime = DateTime.now();
    });
  }

  Future<void> _addToHistory(String? chapterName) async {
    final storage = ref.read(storageProvider);
    final historyBox = storage.settingsBox;
    
    final historyList = (historyBox.get('history') as List?)?.cast<Map>() ?? [];
    
    // Add new entry
    final entry = HistoryEntry(
      workId: widget.work.id,
      title: widget.work.title,
      author: widget.work.author,
      chapterIndex: _currentChapterIndex,
      chapterName: chapterName,
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
    if ((_controller == null && _winController == null) || index >= _chapters.length) return;

    final chapter = _chapters[index];
    final js = '''
      (function() {
        const element = document.getElementById('${chapter.anchor}');
        if (element) {
          element.scrollIntoView({ behavior: 'smooth' });
        }
      })();
    ''';

    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(js);
      } else if (_controller != null) {
        await _controller!.runJavaScript(js);
      }
      setState(() => _currentChapterIndex = index);
    } catch (e) {
      debugPrint('Error jumping to chapter: $e');
    }
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
              if (_isDesktop)
                ListTile(
                  title: const Text('Scroll Speed'),
                  subtitle: Slider(
                    value: _scrollSpeed,
                    min: 0.25,
                    max: 3.0,
                    divisions: 11,
                    label: '${_scrollSpeed.toStringAsFixed(2)}x',
                    onChanged: (value) {
                      setDialogState(() => _scrollSpeed = value);
                      _applyScrollSpeed();
                    },
                  ),
                  trailing: Text('${_scrollSpeed.toStringAsFixed(2)}x'),
                ),
              ListTile(
                title: const Text('Theme'),
                trailing: PopupMenuButton<ThemeMode>(
                  onSelected: (mode) async {
                    await ref.read(themeProvider.notifier).setMode(mode);
                    // Reapply theme styles to webview
                    await _applyThemeStyles();
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
            // Only show webview when content is ready (after theme & element removal)
            if (_isContentReady)
              if (_isWindows && _winController != null)
                win.Webview(_winController!)
              else if (_controller != null)
                WebViewWidget(controller: _controller!),
            // Show loading indicator while preparing content
            if (!_isContentReady || _isLoading)
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
            // Chapter drawer button (only show if there are chapters)
            if (_chapters.isNotEmpty)
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
