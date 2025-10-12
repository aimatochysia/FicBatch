import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

import '../providers/theme_provider.dart';
import '../providers/storage_provider.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import '../services/storage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  String get _readerJs {
    final theme = ref.watch(themeProvider);
    if (theme == ThemeMode.dark) {
      return _darkModeJs;
    } else {
      return _lightModeJs;
    }
  }

  String get _lightModeJs => '''
    (function() {
      if (window.__fb_reader_applied) { try { window.__fb_apply && window.__fb_apply(); } catch(e){} return; }
      window.__fb_reader_applied = true;

      var STYLE_ID = '__fb_reader_style';
      var HIDE_ID = '__fb_reader_hide';

      function ensureHideHeaderCSS() {
        if (document.getElementById(HIDE_ID)) return;
        var s = document.createElement('style');
        s.id = HIDE_ID;
        s.textContent = [
          '#login, ul.primary.navigation.actions {',
          '  display: none !important;',
          '  visibility: hidden !important;',
          '  height: 0 !important;',
          '  overflow: hidden !important;',
          '}',
          '.actions { display: none !important; }',
          '.footer { display: none !important; }'
        ].join('\\n');
        document.documentElement.appendChild(s);
      }

      function nukeHeader() {
        var sels = ['#login','ul.primary.navigation.actions'];
        for (var i = 0; i < sels.length; i++) {
          var nodes = document.querySelectorAll ? document.querySelectorAll(sels[i]) : [];
          for (var j = 0; j < nodes.length; j++) {
            try { nodes[j].parentNode && nodes[j].parentNode.removeChild(nodes[j]); } catch(e) {}
          }
        }
      }

      function ensureReaderStyles() {
        if (document.getElementById(STYLE_ID)) return;
        var s = document.createElement('style');
        s.id = STYLE_ID;
        s.textContent = [
          'html, body { background: #fff !important; color: #000 !important; }',
          'a, a:visited { color: #0066cc !important; text-decoration: none !important; }',
          'h1, h2, h3, h4, h5, h6 { color: #000 !important; }',
          '* { background-color: transparent !important; }',
          '* { background: rgba(255, 255, 255, 0.8) !important; }',
          '* { color: #000 !important; }'
        ].join('\\n');
        document.documentElement.appendChild(s);
      }

      function apply() {
        ensureHideHeaderCSS();
        nukeHeader();
        ensureReaderStyles();
      }

      window.__fb_apply = apply;

      if (document.readyState === 'loading') {
        try { document.addEventListener('DOMContentLoaded', apply); } catch(e){ setTimeout(apply, 0); }
      } else {
        apply();
      }

      try {
        var mo = new MutationObserver(function() { apply(); });
        mo.observe(document.documentElement, { childList: true, subtree: true });
      } catch(e) {}
    })();
  ''';

  String get _darkModeJs => '''
    (function() {
      if (window.__fb_reader_applied) { try { window.__fb_apply && window.__fb_apply(); } catch(e){} return; }
      window.__fb_reader_applied = true;

      var STYLE_ID = '__fb_reader_style';
      var HIDE_ID = '__fb_reader_hide';

      function ensureHideHeaderCSS() {
        if (document.getElementById(HIDE_ID)) return;
        var s = document.createElement('style');
        s.id = HIDE_ID;
        s.textContent = [
          '#login, ul.primary.navigation.actions {',
          '  display: none !important;',
          '  visibility: hidden !important;',
          '  height: 0 !important;',
          '  overflow: hidden !important;',
          '}',
          '.actions { display: none !important; }',
          '.footer { display: none !important; }'
        ].join('\\n');
        document.documentElement.appendChild(s);
      }

      function nukeHeader() {
        var sels = ['#login','ul.primary.navigation.actions'];
        for (var i = 0; i < sels.length; i++) {
          var nodes = document.querySelectorAll ? document.querySelectorAll(sels[i]) : [];
          for (var j = 0; j < nodes.length; j++) {
            try { nodes[j].parentNode && nodes[j].parentNode.removeChild(nodes[j]); } catch(e) {}
          }
        }
      }

      function ensureReaderStyles() {
        if (document.getElementById(STYLE_ID)) return;
        var s = document.createElement('style');
        s.id = STYLE_ID;
        s.textContent = [
          'html, body { background: #111 !important; color: #eee !important; }',
          'a, a:visited { color: #66d9ef !important; text-decoration: none !important; }',
          'h1, h2, h3, h4, h5, h6 { color: #eee !important; }',
          '* { background-color: transparent !important; }',
          '* { background: rgba(0, 0, 0, 0.5) !important; }',
          '* { color: #eee !important; }'
        ].join('\\n');
        document.documentElement.appendChild(s);
      }

      function apply() {
        ensureHideHeaderCSS();
        nukeHeader();
        ensureReaderStyles();
      }

      window.__fb_apply = apply;

      if (document.readyState === 'loading') {
        try { document.addEventListener('DOMContentLoaded', apply); } catch(e){ setTimeout(apply, 0); }
      } else {
        apply();
      }

      try {
        var mo = new MutationObserver(function() { apply(); });
        mo.observe(document.documentElement, { childList: true, subtree: true });
      } catch(e) {}
    })();
  ''';

  Future<void> _injectReaderMode() async {
    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(_readerJs);
      } else if (_controller != null) {
        await _controller!.runJavaScript(_readerJs);
      }
      debugPrint('✅ Reader mode script injected.');
    } catch (e) {
      debugPrint('⚠️ Reader mode injection failed: $e');
    }
  }

  Future<void> _saveToLibrary() async {
    try {
      final url = _isWindows
          ? await _getWindowsCurrentUrl()
          : await _controller!.currentUrl();

      if (url == null || !url.contains('/works/')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not a valid AO3 work page.')),
        );
        return;
      }

      final workId = RegExp(r'/works/(\d+)').firstMatch(url)?.group(1);
      if (workId == null) return;

      final title = await _getInnerText('.title.heading');
      final author = await _getInnerText('.byline a');
      final tags = await _getTags();
      final statsJson = await _getStats();

      final newWork = Work(
        id: workId,
        title: title.isNotEmpty ? title : 'Untitled Work',
        author: author.isNotEmpty ? author : 'Unknown Author',
        tags: tags,
        userAddedDate: DateTime.now(),
        publishedAt: statsJson['published'],
        updatedAt: statsJson['updated'],
        wordsCount: statsJson['words'],
        chaptersCount: statsJson['chapters'],
        kudosCount: statsJson['kudos'],
        hitsCount: statsJson['hits'],
        commentsCount: statsJson['comments'],
        readingProgress: ReadingProgress.empty(),
      );

      final storage = ref.read(storageProvider);
      await storage.saveWork(newWork);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved “${newWork.title}” to library!')),
        );
      }
    } catch (e) {
      debugPrint('❌ Save to Library failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to extract AO3 metadata.')),
      );
    }
  }

  Future<void> _initWebView() async {
    setState(() => _isLoading = true);
    try {
      if (_isWindows) {
        _winController = win.WebviewController();
        await _winController!.initialize();
        await _winController!.setBackgroundColor(Colors.transparent);
        await _winController!.setPopupWindowPolicy(
          win.WebviewPopupWindowPolicy.deny,
        );

        _winController!.loadingState.listen((state) {
          final loading = state == win.LoadingState.loading;
          if (mounted) setState(() => _isLoading = loading);
          if (!loading) {
            _injectReaderMode();
          }
        });

        await _winController!.loadUrl('https://archiveofourown.org/');
      } else {
        final c = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                if (mounted) setState(() => _isLoading = true);
              },
              onPageFinished: (url) {
                if (mounted) setState(() => _isLoading = false);
                _injectReaderMode();
              },
              onNavigationRequest: (request) => NavigationDecision.navigate,
            ),
          )
          ..loadRequest(Uri.parse('https://archiveofourown.org/'));
        setState(() => _controller = c);
      }
    } catch (e) {
      debugPrint('❌ WebView init failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _getWindowsCurrentUrl() async {
    try {
      final url = await _getJson<String>('window.location.href');
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<T?> _getJson<T>(String jsValueExpr) async {
    final wrapped = 'JSON.stringify(($jsValueExpr))';
    try {
      if (_isWindows && _winController != null) {
        final raw = await _winController!.executeScript(wrapped);
        final decoded = _tryJsonDecode<T>(raw);
        return decoded;
      } else if (_controller != null) {
        final result = await _controller!.runJavaScriptReturningResult(wrapped);
        final str = _asDartString(result);
        final decoded = _tryJsonDecode<T>(str);
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

  Future<List<String>> _getTags() async {
    final js = '''
      (function(){
        var nodes = Array.from(document.querySelectorAll('.tags a.tag, li.tag a, .tags li a'));
        var texts = nodes.map(function(n){ return (n.textContent || "").trim(); })
                         .filter(function(x){ return x.length > 0; });
        var seen = {};
        var out = [];
        for (var i=0;i<texts.length;i++){
          var t = texts[i];
          if (!seen[t]) { seen[t] = true; out.push(t); }
        }
        return out;
      })()
    ''';
    final list = await _getJson<List<dynamic>>(js);
    return (list ?? []).map((e) => e.toString()).toList();
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Search AO3 works...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          final query = _urlController.text.trim();
                          if (query.isEmpty) return;
                          final uri = Uri.https(
                            'archiveofourown.org',
                            '/works/search',
                            {'work_search[query]': query},
                          );
                          if (_isWindows) {
                            _winController!.loadUrl(uri.toString());
                          } else {
                            _controller!.loadRequest(uri);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      final query = value.trim();
                      if (query.isEmpty) return;
                      final uri = Uri.https(
                        'archiveofourown.org',
                        '/works/search',
                        {'work_search[query]': query},
                      );
                      if (_isWindows) {
                        _winController!.loadUrl(uri.toString());
                      } else {
                        _controller!.loadRequest(uri);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chrome_reader_mode),
                  tooltip: 'Apply Reader Mode',
                  onPressed: _injectReaderMode,
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Save to Library',
                  onPressed: _saveToLibrary,
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _isWindows
                ? _winController == null
                      ? const Center(child: CircularProgressIndicator())
                      : win.Webview(_winController!)
                : _controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: _controller!),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    if (_isWindows) {
      _winController?.dispose();
    }
    super.dispose();
  }
}
