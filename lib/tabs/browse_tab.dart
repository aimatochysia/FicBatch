import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

import '../providers/theme_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/navigation_provider.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import '../services/storage_service.dart';
import '../widgets/advanced_search.dart';
import 'browse/browse_navigation.dart';
import 'browse/browse_search.dart';
import 'browse/ao3_extractors.dart';
import 'browse/browse_toolbar.dart';
import 'browse/inject_listing_buttons.dart';
import 'reader_screen.dart';

class BrowseTab extends ConsumerStatefulWidget {
  const BrowseTab({super.key});
  @override
  ConsumerState<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends ConsumerState<BrowseTab> {
  WebViewController? _controller;
  win.WebviewController? _winController;
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = true;
  bool _isWindows = Platform.isWindows;
  bool _readyToShow = false;
  String _searchType = 'query';
  String _currentUrl = '';
  Brightness? _lastBrightness;
  String? _pendingThemeMode;
  bool _pageReady = false;
  bool _coverVisible = false;
  bool _winInitialLoadComplete = false; // Track if initial page load is complete
  bool get _winInited => _winController != null && _winController!.value.isInitialized;
  static const int _browseTabIndex = 3;
  DateTime? _lastInjectorPing;
  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  List<String> _getSavedWorkIds() {
    final storage = ref.read(storageProvider);
    return storage.getAllWorks().map((w) => w.id).toList();
  }

  void _clearQueryInput() {
    if (!mounted) return;
    setState(() => _urlController.clear());
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final b = Theme.of(context).brightness;
    if (_lastBrightness != b) {
      _lastBrightness = b;
      final mode = b == Brightness.dark ? 'dark' : 'light';
      if (_isWindows) {
        final ready = _winController != null && _winController!.value.isInitialized && _pageReady;
        if (ready) {
          _injectThemeStyle();
        } else {
          _pendingThemeMode = mode;
        }
      } else {
        final ready = _controller != null && _pageReady;
        if (ready) {
          _injectThemeStyle();
        } else {
          _pendingThemeMode = mode;
        }
      }
      final ready = _isWindows
          ? (_winController != null && _winController!.value.isInitialized && _pageReady)
          : (_controller != null && _pageReady);
      if (ready) {
        _injectEarlyStyle();
      }
      _pulseCover();
    }
  }

  Future<void> _initWebView() async {
    setState(() => _isLoading = true);
    try {
      if (_isWindows) {
        _winController = win.WebviewController();
        await _winController!.initialize();
        await _winController!.setBackgroundColor(Colors.transparent);
        await _winController!.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
        _winController!.webMessage.listen((event) {
          try {
            final s = event?.toString() ?? '';
            if (s.isNotEmpty) _handleInjectedMessage(s);
          } catch (_) {}
        });
        // Listen for URL changes to intercept work page navigation
        _winController!.historyChanged.listen((event) async {
          await _handleWindowsUrlChange();
        });
        _winController!.loadingState.listen((state) async {
          final loading = state == win.LoadingState.loading;
          if (mounted) {
            setState(() {
              _isLoading = loading;
              _readyToShow = !loading ? _readyToShow : false;
              _pageReady = !loading;
              if (loading) _coverVisible = true;
            });
          }
          if (!loading) {
            try {
              final probe = await _winController!.executeScript('1+1');
              debugPrint('[BrowseTab] Windows JS probe ok: $probe');
            } catch (e) {
              debugPrint('⚠️ Windows JS probe failed: $e');
            }
            await _injectEarlyStyle();
            await _injectThemeStyle();
            await _applyScrollSpeed();
            await _diagnoseListingDom('pre-inject (Windows)');
            await injectListingButtons(
              isWindows: _isWindows,
              winController: _winController,
              controller: _controller,
              dartDebugPrint: debugPrint,
              savedWorkIds: _getSavedWorkIds(),
            );
            Future.delayed(const Duration(milliseconds: 800), () async {
              if (!mounted) return;
              await injectListingButtons(
                isWindows: _isWindows,
                winController: _winController,
                controller: _controller,
                dartDebugPrint: debugPrint,
                savedWorkIds: _getSavedWorkIds(),
              );
            });
            if (_pendingThemeMode != null) {
              _pendingThemeMode = null;
              await _injectThemeStyle();
            }
            await _updateCurrentUrl();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _readyToShow = true;
                _winInitialLoadComplete = true;
              });
            }
            _pulseCover();
          }
        });
        await _winController!.loadUrl('https://archiveofourown.org/');
      } else {
        final c = WebViewController();
        setState(() => _controller = c);
        c
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel('FB', onMessageReceived: (m) {
            final s = m.message;
            if (s.isNotEmpty) _handleInjectedMessage(s);
          })
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (request) async {
                // Intercept work page navigation to open reader
                final url = request.url;
                final workIdMatch = RegExp(r'/works/(\d+)(?:/chapters/\d+)?(?:[/?#]|$)').firstMatch(url);
                if (workIdMatch != null && !url.contains('view_full_work')) {
                  final workId = workIdMatch.group(1)!;
                  final storage = ref.read(storageProvider);
                  
                  // Check if work is in library, otherwise create a temporary Work
                  // The reader will load the actual work data from AO3
                  final Work workToOpen = storage.getWork(workId) ?? Work(
                    id: workId,
                    title: 'Work #$workId',
                    author: 'Unknown',
                    tags: [],
                    userAddedDate: DateTime.now(),
                    readingProgress: ReadingProgress.empty(),
                  );
                  
                  // Add to history
                  await storage.addToHistory(
                    workId: workToOpen.id,
                    title: workToOpen.title,
                    author: workToOpen.author,
                  );
                  
                  // Open reader for all works
                  final returnUrl = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReaderScreen(work: workToOpen),
                    ),
                  );
                  
                  // If reader returned a URL, navigate to it
                  if (returnUrl != null && returnUrl.isNotEmpty) {
                    if (_isWindows) {
                      await _winController?.loadUrl(returnUrl);
                    } else {
                      await _controller?.loadRequest(Uri.parse(returnUrl));
                    }
                  }
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onPageStarted: (_) async {
                setState(() {
                  _isLoading = true;
                  _readyToShow = false;
                  _pageReady = false;
                });
                _pulseCover();
                await _injectEarlyStyle();
                await _injectThemeStyle();
              },
              onPageFinished: (url) async {
                try {
                  final res = await c.runJavaScriptReturningResult('1+1');
                  debugPrint('[BrowseTab] Mobile JS probe ok: $res');
                } catch (e) {
                  debugPrint('⚠️ Mobile JS probe failed: $e');
                }
                _pageReady = true;
                await _injectThemeStyle();
                await _applyScrollSpeed();
                await _diagnoseListingDom('pre-inject (Mobile)');
                await injectListingButtons(
                  isWindows: _isWindows,
                  winController: _winController,
                  controller: _controller,
                  dartDebugPrint: debugPrint,
                  savedWorkIds: _getSavedWorkIds(),
                );
                Future.delayed(const Duration(milliseconds: 800), () async {
                  if (!mounted) return;
                  await injectListingButtons(
                    isWindows: _isWindows,
                    winController: _winController,
                    controller: _controller,
                    dartDebugPrint: debugPrint,
                    savedWorkIds: _getSavedWorkIds(),
                  );
                });
                if (_pendingThemeMode != null) {
                  _pendingThemeMode = null;
                  await _injectThemeStyle();
                }
                if (mounted) {
                  setState(() {
                    _currentUrl = url;
                    _isLoading = false;
                    _readyToShow = true;
                  });
                }
                _pulseCover();
              },
            ),
          )
          ..loadRequest(Uri.parse('https://archiveofourown.org/'));
      }
    } catch (e) {
      debugPrint('WebView init failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _injectThemeStyle() async {
    if (!mounted) return;
    
    // Use cached brightness if available, otherwise try to get it safely
    Brightness? brightness = _lastBrightness;
    if (brightness == null) {
      try {
        brightness = Theme.of(context).brightness;
      } catch (e) {
        // If Theme.of(context) fails, use light as default
        debugPrint('⚠️ Could not get theme brightness, using light mode: $e');
        brightness = Brightness.light;
      }
    }
    
    final isDark = brightness == Brightness.dark;
    final mode = isDark ? 'dark' : 'light';
    final js = _buildDarkReaderBootstrapJs(mode);
    debugPrint(
      '[BrowseTab] Injecting dark mode "$mode" on ${_isWindows ? 'Windows' : 'Mobile'}',
    );
    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(js);
      } else if (_controller != null) {
        await _controller!.runJavaScript(js);
      }
      debugPrint('[BrowseTab] Injection script executed for mode "$mode".');
    } catch (e) {
      debugPrint('⚠️ Theme injection failed: $e');
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
            css: `
.pagination a, .pagination .current, .actions a, .navigation.actions a,
.listbox .actions a, .listbox .heading .actions a, .listbox.group ul li a,
ul.actions li a, ol.actions li a, .secondary .actions a, .filters .group .actions a {
  background-color: #2a2f32 !important; color: #e8e6e3 !important; border: 1px solid #3a3e41 !important;
}
input, select, textarea, button {
  background-color: #262a2b !important; color: #e8e6e3 !important; border: 1px solid #3a3e41 !important;
}
a.tag, .tag { background-color: #2b3134 !important; color: #e8e6e3 !important; }
`
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

  Future<void> _injectEarlyStyle() async {
    if (!mounted) return;
    
    // Use cached brightness if available, otherwise try to get it safely
    Brightness? brightness = _lastBrightness;
    if (brightness == null) {
      try {
        brightness = Theme.of(context).brightness;
      } catch (e) {
        // If Theme.of(context) fails, use light as default
        debugPrint('⚠️ Could not get theme brightness for early style, using light mode: $e');
        brightness = Brightness.light;
      }
    }
    
    final isDark = brightness == Brightness.dark;
    const jsRemove = r"""
      (function(){
        try { document.getElementById('fb-early-dark-style')?.remove(); } catch(_) {}
      })();
    """;
    const jsDark = r"""
      (function(){
        try {
          const prev = document.getElementById('fb-early-dark-style');
          if (prev) prev.remove();
          const s = document.createElement('style');
          s.id = 'fb-early-dark-style';
          s.textContent = `
            html, body { background-color: #121212 !important; color: #e0e0e0 !important; }
            * { background-color: transparent !important; color: inherit !important; }
          `;
          (document.documentElement || document.body).prepend(s);
          console.log('[FB-Dark] early style injected');
        } catch(e) { console.log('[FB-Dark] early style error', e); }
      })();
    """;
    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(isDark ? jsDark : jsRemove);
      } else if (_controller != null) {
        await _controller!.runJavaScript(isDark ? jsDark : jsRemove);
      }
    } catch (e) {
      debugPrint('⚠️ Early style injection failed: $e');
    }
  }

  Future<void> _applyScrollSpeed() async {
    if (!_isDesktop) return;
    
    // Load scroll speed from reader settings
    final storage = ref.read(storageProvider);
    final prefs = await storage.settingsBox.get('reader_settings');
    
    double scrollSpeed = 1.0;
    if (prefs != null) {
      try {
        final prefsMap = prefs is Map<String, dynamic> 
            ? prefs 
            : Map<String, dynamic>.from(prefs as Map);
        scrollSpeed = (prefsMap['scrollSpeed'] ?? 1.0).toDouble();
      } catch (e) {
        debugPrint('⚠️ Failed to load scroll speed setting: $e');
        scrollSpeed = 1.0;
      }
    }

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
          const speed = $scrollSpeed;
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
      debugPrint('⚠️ Scroll speed injection failed: $e');
    }
  }

  void _pulseCover({Duration duration = const Duration(milliseconds: 200)}) {
    if (!mounted) return;
    setState(() => _coverVisible = true);
    Future.delayed(duration, () {
      if (!mounted) return;
      setState(() => _coverVisible = false);
    });
  }

  Future<void> _setThemeInWebView(String mode) async {
    debugPrint(
      '[BrowseTab] _setThemeInWebView skipped; using reinjection path for "$mode"',
    );
  }

  void _performSearch() {
    performQuickSearch(
      searchType: _searchType,
      urlController: _urlController,
      isWindows: _isWindows,
      winController: _winController,
      controller: _controller,
      onUrlChange: (u) => setState(() => _currentUrl = u),
    );
  }

  Future<T?> _getJson<T>(String jsValueExpr) async {
    final wrapped = 'JSON.stringify(($jsValueExpr))';
    try {
      if (_isWindows && _winController != null) {
        final raw = await _winController!.executeScript(wrapped);
        final s = raw is List
            ? (raw.isNotEmpty ? raw.first?.toString() ?? '' : '')
            : (raw?.toString() ?? '');
        final decoded =
            _tryJsonDecode<T>(s) ?? _tryJsonDecode<T>(_stripQuotes(s));
        return decoded;
      } else if (_controller != null) {
        final result = await _controller!.runJavaScriptReturningResult(wrapped);
        final str = _asDartString(result);
        final decoded =
            _tryJsonDecode<T>(str) ?? _tryJsonDecode<T>(_stripQuotes(str));
        return decoded;
      }
    } catch (e) {
      debugPrint('⚠️ _getJson failed: $e');
    }
    return null;
  }

  String _asDartString(Object? val) {
    if (val == null) return '';
    if (val is String) return val;
    return val.toString();
  }

  T? _tryJsonDecode<T>(String s) {
    try {
      return jsonDecode(s) as T;
    } catch (_) {
      try {
        final stripped = _stripQuotes(s);
        return jsonDecode(stripped) as T;
      } catch (_) {
        return null;
      }
    }
  }

  String _stripQuotes(String s) {
    final t = s.trim();
    if (t.length >= 2 &&
        ((t.startsWith('"') && t.endsWith('"')) ||
            (t.startsWith("'") && t.endsWith("'")))) {
      return t.substring(1, t.length - 1).replaceAll(r'\"', '"');
    }
    return t;
  }

  Future<String> _getInnerText(String selector) async {
    final sel = jsonEncode(selector);
    final js =
        '''
      (function(){
        var el = document.querySelector($sel);
        return el ? el.textContent.trim() : "";
      })()
    ''';
    final value = await _getJson<String>(js);
    return value ?? '';
  }

  Future<Map<String, List<String>>> _getTags() async {
    const js = r'''
    (function() {
      const result = {};
      const groups = document.querySelectorAll("dl.work.meta.group dt");
      groups.forEach(dt => {
        const key = dt.classList[0];
        const next = dt.nextElementSibling;
        if (!key || !next) return;
        const tags = Array.from(next.querySelectorAll("a.tag")).map(a => a.textContent.trim());
        if (tags.length > 0) result[key] = tags;
      });
      return JSON.stringify(result);
    })();
  ''';

    try {
      dynamic raw;
      if (_isWindows && _winController != null) {
        raw = await _winController!.executeScript(js);
        if (raw is List && raw.isNotEmpty) raw = raw.first;
      } else if (_controller != null) {
        raw = await _controller!.runJavaScriptReturningResult(js);
      }
      final s = raw?.toString() ?? '{}';
      final jsonStr = s.startsWith('"') && s.endsWith('"')
          ? _stripQuotes(s)
          : s;
      final decoded = jsonDecode(jsonStr) as Map;
      return Map<String, List<String>>.from(
        decoded.map((k, v) => MapEntry(k.toString(), List<String>.from(v))),
      );
    } catch (e) {
      debugPrint('Failed to get tags: $e');
      return <String, List<String>>{};
    }
  }

  Future<String> _getSummary() async {
    const js = r"""
    (function() {
      const el = document.querySelector('div.summary.module blockquote.userstuff');
      return el ? el.innerText.trim() : '';
    })();
  """;

    try {
      dynamic result;
      if (_isWindows && _winController != null) {
        final execResult = await _winController!.executeScript(js);
        if (execResult is List && execResult.isNotEmpty) {
          result = execResult.first;
        } else {
          result = execResult;
        }
      } else if (_controller != null) {
        result = await _controller!.runJavaScriptReturningResult(js);
      }

      if (result == null) return '';

      final text = result.toString().trim();

      return text.replaceAll(RegExp(r'^"|"$'), '');
    } catch (e) {
      debugPrint('Failed to get summary: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>> _getStats() async {
    final js = '''
      (function(){
        function text(sel){
          var el = document.querySelector(sel);
          return el ? el.textContent.trim() : "";
        }
        function intFrom(sel){
          var t = text(sel).replace(/[\\s,]/g, "");
          var m = t.match(/\\d+/);
          return m ? parseInt(m[0], 10) : 0;
        }
        function isoFrom(sel){
          var t = text(sel);
          if (!t) return null;
          var d = new Date(t);
          if (isNaN(d.getTime())) return null;
          return d.toISOString();
        }
        function chapterCount(){
          var t = text('dd.chapters');
          var m = t.match(/(\\d+)(?:\\s*\\/\\s*(\\d+|\\?))?/);
          if (!m) return 0;
          return parseInt(m[1], 10);
        }
        return {
          published: isoFrom('dd.published'),
          updated: (isoFrom('dd.updated') || isoFrom('dd.status') || null),
          words: intFrom('dd.words'),
          chapters: chapterCount(),
          kudos: intFrom('dd.kudos'),
          hits: intFrom('dd.hits'),
          comments: intFrom('dd.comments')
        };
      })()
    ''';
    final map = await _getJson<Map<String, dynamic>>(js);
    return map ??
        <String, dynamic>{
          'published': null,
          'updated': null,
          'words': 0,
          'chapters': 0,
          'kudos': 0,
          'hits': 0,
          'comments': 0,
        };
  }

  Future<Work?> _extractWorkFromPage() async {
    final url = _isWindows
        ? await _getWindowsCurrentUrl()
        : await _controller?.currentUrl();
    if (url == null) return null;
    final workId = _extractWorkId(url);
    if (workId == null) return null;

    final meta = await fetchAo3MetaCombined(_getJson);
    if (meta == null) return null;

    return buildWorkFromMeta(workId, meta);
  }

  Future<void> _confirmAndSaveToLibrary() async {
    try {
      final work = await _extractWorkFromPage();
      if (work == null) {
        _showSnackBar('Not a valid AO3 work page.');
        return;
      }

      final storage = ref.read(storageProvider);
      final cats = await storage.getCategories();

      if (cats.isEmpty) {
        await storage.saveWork(work);
        if (context.mounted)
          _showSnackBar('Saved “${work.title}” to library (default).');
        return;
      }

      // Get existing categories for this work (if already saved)
      final existingCategories = await storage.getCategoriesForWork(work.id);
      final selected = Set<String>.from(existingCategories);
      final newCats = await showDialog<Set<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(existingCategories.isEmpty ? 'Select categories' : 'Update categories'),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: cats.map((c) {
                  final checked = selected.contains(c);
                  return CheckboxListTile(
                    dense: true,
                    title: Text(c),
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          selected.add(c);
                        } else {
                          selected.remove(c);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, Set<String>.from(selected)),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (newCats == null || newCats.isEmpty) return;

      await storage.saveWork(work);
      await storage.setCategoriesForWork(work.id, newCats);
      if (context.mounted)
        _showSnackBar('Saved “${work.title}” to ${newCats.join(', ')}.');
    } catch (e, st) {
      debugPrint('Save confirm failed: $e\n$st');
      _showSnackBar('Failed to extract AO3 metadata.');
    }
  }

  Future<void> _openAdvancedSearch() async {
    final storage = ref.read(storageProvider);
    final lastFilters = await storage.getAdvancedFilters();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedSearchScreen(initialFilters: lastFilters),
      ),
    );
    if (result == null) return;

    final url = result['url'] as String?;
    final filters = result['filters'] as Map<String, dynamic>?;
    if (filters != null) {
      await storage.saveAdvancedFilters(filters);
    }
    if (url != null && url.isNotEmpty) {
      if (!mounted) return;
      setState(() => _currentUrl = url);
      if (_isWindows) {
        await _winController?.loadUrl(url);
      } else {
        await _controller?.loadRequest(Uri.parse(url));
      }
    }
  }

  Future<void> _saveCurrentSearch() async {
    final storage = ref.read(storageProvider);
    final live = await _getCurrentUrl();
    final current = (live ?? _currentUrl).trim();
    if (mounted) setState(() => _currentUrl = current);
    if (current.isEmpty) return;

    if (_isValidSearchUrl(current)) {
      final nameController = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save Current Search'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter a name for this search',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty) return;

      final filters = await storage.getAdvancedFilters();
      await storage.saveSearch(result, current, filters);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved search "$result"!')));
      }
    } else {
      _showSnackBar('Cannot save a specific work or chapter page.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to navigation changes - must be in build method for Riverpod
    ref.listen<int>(navigationProvider, (prev, next) {
      final wasBrowse = (prev ?? _browseTabIndex) == _browseTabIndex;
      final isBrowse = next == _browseTabIndex;
      if (wasBrowse != isBrowse) {
        _clearQueryInput();
      }
    });
    
    final storage = ref.read(storageProvider);

    final onHome = () => goHome(
      isWindows: _isWindows,
      winController: _winController,
      controller: _controller,
      onUrlChange: (u) => setState(() => _currentUrl = u),
      clearInput: _clearQueryInput,
    );
    final onBack = () => goBack(
      isWindows: _isWindows,
      winController: _winController,
      controller: _controller,
      clearInput: _clearQueryInput,
    );
    final onForward = () => goForward(
      isWindows: _isWindows,
      winController: _winController,
      controller: _controller,
      clearInput: _clearQueryInput,
    );
    final onRefresh = () => refreshPage(
      isWindows: _isWindows,
      winController: _winController,
      controller: _controller,
    );

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: BrowseToolbar(
              urlController: _urlController,
              onHome: onHome,
              onBack: onBack,
              onForward: onForward,
              onRefresh: onRefresh,
              onQuickSearch: _performSearch,
              onAdvancedSearch: () => openAdvancedSearch(
                context: context,
                storage: storage,
                isWindows: _isWindows,
                winController: _winController,
                controller: _controller,
                onUrlChange: (u) => setState(() => _currentUrl = u),
              ),
              onSaveCurrentSearch: () => saveCurrentSearch(
                context: context,
                storage: storage,
                getCurrentUrl: _getCurrentUrl,
                currentUrl: _currentUrl,
                setCurrentUrl: (u) => setState(() => _currentUrl = u),
              ),
              onLoadSavedSearch: () async {
                final saved = await storage.getSavedSearches();
                if (!mounted) return;
                await showSavedSearchDialog(
                  context: context,
                  saved: saved,
                  storage: storage,
                  isWindows: _isWindows,
                  winController: _winController,
                  controller: _controller,
                  setCurrentUrl: (u) => setState(() => _currentUrl = u),
                );
              },
              onSaveToLibrary: _confirmAndSaveToLibrary,
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Stack(
              children: [
                AnimatedOpacity(
                  opacity: _readyToShow ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: SizedBox.expand(
                    child: _isWindows
                        ? (_winInited
                              ? win.Webview(_winController!)
                              : const SizedBox.shrink())
                        : (_controller != null
                              ? WebViewWidget(controller: _controller!)
                              : const SizedBox.shrink()),
                  ),
                ),
                if (!_readyToShow)
                  Container(
                    color: Theme.of(context).colorScheme.background,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                IgnorePointer(
                  ignoring: !_coverVisible,
                  child: AnimatedOpacity(
                    opacity: _coverVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      color: Theme.of(context).colorScheme.background,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidSearchUrl(String url) {
    debugPrint('Checking URL for validity: $url');
    try {
      final u = Uri.parse(url);
      if (u.host != 'archiveofourown.org') return false;
      final segs = u.pathSegments;
      final hasQuery = u.query.isNotEmpty;

      if (segs.length >= 2 && segs.first == 'tags' && segs.last == 'works') {
        return true;
      }

      if (segs.length == 1 && segs.first == 'works' && hasQuery) {
        return true;
      }

      if (segs.length >= 2 &&
          segs[0] == 'works' &&
          segs[1] == 'search' &&
          hasQuery) {
        return true;
      }

      if (segs.isNotEmpty && segs[0] == 'works') {
        if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs[1]))
          return false;
        if (segs.length >= 3 && segs[2] == 'chapters') return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSavedSearchDialog(
    BuildContext context,
    List<Map<String, dynamic>> saved,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saved Searches'),
        content: saved.isEmpty
            ? const Text('No saved searches yet.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: saved.length,
                  itemBuilder: (_, i) {
                    final item = saved[i];
                    return ListTile(
                      title: Text(item['name'] ?? 'default'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final storage = ref.read(storageProvider);
                          await storage.deleteSavedSearch(item['name']);
                          Navigator.pop(ctx);
                          _showSavedSearchDialog(
                            context,
                            await storage.getSavedSearches(),
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        final url = (item['url'] ?? '') as String;
                        if (mounted) {
                          setState(() {
                            _currentUrl = url;
                          });
                        }
                        if (_isWindows) {
                          _winController?.loadUrl(url);
                        } else {
                          _controller?.loadRequest(Uri.parse(url));
                        }
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToLibrary() async {
    try {
      final url = _isWindows
          ? await _getWindowsCurrentUrl()
          : await _controller!.currentUrl();

      if (url == null) {
        _showSnackBar('Unable to get current page.');
        return;
      }

      final workId = _extractWorkId(url);
      if (workId == null) {
        _showSnackBar('Not a valid AO3 work page.');
        return;
      }

      final title = await _getInnerText('h2.title.heading');
      final author = await _getInnerText('h3.byline.heading a[rel="author"]');
      final tagsMap = await _getTags();
      final tags = tagsMap.values.expand((list) => list).toList();
      final stats = await _getStats();
      final summary = await _getSummary();

      DateTime? parseDate(dynamic v) {
        if (v == null) return null;
        try {
          return DateTime.parse(v.toString());
        } catch (_) {
          return null;
        }
      }

      int? parseInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        return int.tryParse(
          v.toString().replaceAll(',', '').replaceAll('.', '').trim(),
        );
      }

      int? parseChapters(dynamic v) {
        if (v == null) return null;
        final text = v.toString();
        final match = RegExp(r'(\d+)').firstMatch(text);
        return match != null ? int.tryParse(match.group(1)!) : null;
      }

      final publishedAt = parseDate(stats['published']);
      final updatedAt = parseDate(stats['status'] ?? stats['updated']);
      final wordsCount = parseInt(stats['words']);
      final kudosCount = parseInt(stats['kudos']);
      final hitsCount = parseInt(stats['hits']);
      final commentsCount = parseInt(stats['comments']);
      final chaptersCount = parseChapters(stats['chapters']);

      final newWork = Work(
        id: workId,
        title: title.isNotEmpty ? title : 'Untitled Work',
        author: author.isNotEmpty ? author : 'Unknown Author',
        tags: tags,
        userAddedDate: DateTime.now(),
        publishedAt: publishedAt,
        updatedAt: updatedAt,
        wordsCount: wordsCount,
        chaptersCount: chaptersCount,
        kudosCount: kudosCount,
        hitsCount: hitsCount,
        commentsCount: commentsCount,
        readingProgress: ReadingProgress.empty(),
        summary: summary.isNotEmpty ? summary : null,
      );

      final storage = ref.read(storageProvider);
      await storage.saveWork(newWork);

      if (context.mounted) {
        _showSnackBar('Saved “${newWork.title}” to library!');
      }
    } catch (e, st) {
      debugPrint('Save to Library failed: $e\n$st');
      _showSnackBar('Failed to extract AO3 metadata.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _extractWorkId(String url) {
    final match = RegExp(r'/works/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  Future<String?> _getWindowsCurrentUrl() async {
    if (_winController == null) return null;
    try {
      final direct = await _winController!.executeScript(
        'window.location.href',
      );
      if (direct is List && direct.isNotEmpty) {
        return direct.first.toString().trim();
      }
      if (direct is String && direct.isNotEmpty) {
        return _stripQuotes(direct).trim();
      }
    } catch (_) {}

    try {
      final json = await _winController!.executeScript(
        'JSON.stringify(window.location.href)',
      );
      if (json is List && json.isNotEmpty) {
        final s = json.first.toString();
        final decoded = _tryJsonDecode<String>(s) ?? _stripQuotes(s);
        return decoded.trim();
      }
      if (json is String && json.isNotEmpty) {
        final decoded = _tryJsonDecode<String>(json) ?? _stripQuotes(json);
        return decoded.trim();
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _getCurrentUrl() async {
    return _isWindows
        ? await _getWindowsCurrentUrl()
        : await _controller?.currentUrl();
  }

  Future<void> _updateCurrentUrl() async {
    final url = await _getCurrentUrl();
    if (!mounted) return;
    setState(() {
      _currentUrl = (url ?? '').trim();
    });
  }

  /// Handle URL changes in Windows webview to intercept work page navigation
  Future<void> _handleWindowsUrlChange() async {
    if (!mounted || _winController == null) return;
    
    // Don't intercept until initial page load is complete
    if (!_winInitialLoadComplete) return;
    
    final url = await _getWindowsCurrentUrl();
    if (url == null) return;
    
    // Check if this is a work page (but not already viewing full work)
    final workIdMatch = RegExp(r'/works/(\d+)(?:/chapters/\d+)?(?:[/?#]|$)').firstMatch(url);
    if (workIdMatch != null && !url.contains('view_full_work')) {
      final workId = workIdMatch.group(1)!;
      final storage = ref.read(storageProvider);
      
      // Check if work is in library, otherwise create a temporary Work
      // The reader will load the actual work data from AO3
      final Work workToOpen = storage.getWork(workId) ?? Work(
        id: workId,
        title: 'Work #$workId',
        author: 'Unknown',
        tags: [],
        userAddedDate: DateTime.now(),
        readingProgress: ReadingProgress.empty(),
      );
      
      // Add to history
      await storage.addToHistory(
        workId: workToOpen.id,
        title: workToOpen.title,
        author: workToOpen.author,
      );
      
      // Go back to prevent staying on the work page
      try {
        await _winController!.goBack();
      } catch (_) {
        // If goBack fails, navigate to home
        await _winController!.loadUrl('https://archiveofourown.org/');
      }
      
      // Open reader for the work
      final returnUrl = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(work: workToOpen),
        ),
      );
      
      // If reader returned a URL, navigate to it
      if (returnUrl != null && returnUrl.isNotEmpty) {
        await _winController?.loadUrl(returnUrl);
      }
    }
  }

  Future<void> _diagnoseListingDom(String stage) async {
    try {
      final diag = await _getJson<Map<String, dynamic>>(r'''
        (function(){
          function q(sel){ try { return document.querySelectorAll(sel).length; } catch(_) { return -1; } }
          return {
            ready: document.readyState,
            lists: q('ol.work.index.group, ol.index.group'),
            items: q('li.blurb[role="article"], li.work.blurb.group'),
            hasFB: !!(window.FB && window.FB.postMessage),
            hasWV: !!(window.chrome && chrome.webview && chrome.webview.postMessage),
            path: location.pathname
          };
        })()
      ''');
      debugPrint('[BrowseTab][injector][diag][$stage] ${jsonEncode(diag ?? {})}');
    } catch (e) {
      debugPrint('[BrowseTab][injector][diag][$stage] failed: $e');
    }
  }

  void _handleInjectedMessage(String s) async {
    try {
      final obj = jsonDecode(s) as Map<String, dynamic>;
      final type = obj['type'] as String? ?? '';
      if (type == 'saveWorkFromListing') {
        final workId = obj['workId']?.toString() ?? '';
        final meta = Map<String, dynamic>.from(obj['meta'] ?? {});
        if (workId.isEmpty || meta.isEmpty) return;
        await _handleSaveFromListing(workId, meta);
      } else if (type == 'saveWorkError') {
        final id = obj['workId']?.toString() ?? '';
        final err = obj['error']?.toString() ?? 'Unknown error';
        if (mounted) _showSnackBar('Failed to save $id: $err');
      } else if (type == 'injectorLog') {
        _lastInjectorPing = DateTime.now();
        final level = obj['level']?.toString() ?? 'info';
        final msg = obj['msg']?.toString() ?? '';
        final ctx = obj['ctx']?.toString() ?? '';
        debugPrint('[BrowseTab][injector][$level] $msg${ctx.isNotEmpty ? ' | ' + ctx : ''}');
      }
    } catch (e) {
      debugPrint('Injected message parse error: $e');
    }
  }

  Future<void> _handleSaveFromListing(
    String workId,
    Map<String, dynamic> meta,
  ) async {
    try {
      final work = buildWorkFromMeta(workId, meta);
      final storage = ref.read(storageProvider);
      final cats = await storage.getCategories();

      if (cats.isEmpty) {
        await storage.saveWork(work);
        if (mounted) _showSnackBar('Saved “${work.title}” (default).');
        return;
      }

      // Get existing categories for this work (if already saved)
      final existingCategories = await storage.getCategoriesForWork(workId);
      final selected = Set<String>.from(existingCategories);
      final chosen = await showDialog<Set<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(existingCategories.isEmpty ? 'Select categories' : 'Update categories'),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: cats.map((c) {
                  final checked = selected.contains(c);
                  return CheckboxListTile(
                    dense: true,
                    title: Text(c),
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true)
                          selected.add(c);
                        else
                          selected.remove(c);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, Set<String>.from(selected)),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (chosen == null || chosen.isEmpty) return;

      await storage.saveWork(work);
      await storage.setCategoriesForWork(work.id, chosen);
      if (mounted)
        _showSnackBar('Saved “${work.title}” to ${chosen.join(', ')}.');
    } catch (e) {
      debugPrint('Save from listing failed: $e');
      if (mounted) _showSnackBar('Failed to save from listing.');
    }
  }
}
