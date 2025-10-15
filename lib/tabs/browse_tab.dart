import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

import '../providers/theme_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/browse_provider.dart';
import '../models/work.dart';
import '../models/reading_progress.dart';
import '../services/storage_service.dart';
import '../widgets/advanced_search.dart';

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

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _injectReaderMode() async {
    final readerJs = ref.read(readerJsProvider);
    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(readerJs);
      } else if (_controller != null) {
        await _controller!.runJavaScript(readerJs);
      }
    } catch (e) {
      debugPrint('⚠️ Reader mode failed: $e');
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

        _winController!.loadingState.listen((state) async {
          final loading = state == win.LoadingState.loading;
          if (mounted) {
            setState(() {
              _isLoading = loading;
              if (loading) _readyToShow = false;
            });
          }

          if (!loading) {
            await _injectEarlyStyle();
            await _injectReaderMode();
            await _injectHideFilterButton();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _readyToShow = true;
              });
            }
          }
        });

        await _winController!.loadUrl('https://archiveofourown.org/');
      } else {
        final c = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) async {
                setState(() {
                  _isLoading = true;
                  _readyToShow = false;
                });
                await _injectEarlyStyle();
              },
              onPageFinished: (_) async {
                await _injectReaderMode();
                await _injectHideFilterButton();
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _readyToShow = true;
                  });
                }
              },
            ),
          )
          ..loadRequest(Uri.parse('https://archiveofourown.org/'));
        setState(() => _controller = c);
      }
    } catch (e) {
      debugPrint('❌ WebView init failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _injectEarlyStyle() async {
    const css = '''
    (function() {
      const s = document.createElement('style');
      s.id = 'early-dark-style';
      s.textContent = `
        html, body {
          background-color: #121212 !important;
          color: #e0e0e0 !important;
        }
        * {
          background-color: transparent !important;
          color: inherit !important;
        }
      `;
      document.documentElement.prepend(s);
    })();
  ''';
    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(css);
      } else if (_controller != null) {
        await _controller!.runJavaScript(css);
      }
    } catch (e) {
      debugPrint('⚠️ Early style injection failed: $e');
    }
  }

  Future<void> _injectHideFilterButton() async {
    const js = r"""
  (function() {
    function injectAO3FilterMod() {
      try {
        const origButton = document.querySelector('a#go_to_filters');
        const origForm = document.querySelector('form#work-filters.filters');
        if (!origButton || !origForm) {
          console.warn('AO3 filter mod: original elements not found yet.');
          return false;
        }

        document.querySelector('#work-filters-mod')?.remove();
        document.querySelector('#go_to_filters-mod')?.remove();
        document.querySelector('#ao3-filter-backdrop-mod')?.remove();

        const btn = origButton.cloneNode(true);
        const form = origForm.cloneNode(true);

        function modIds(el) {
          if (!el || el.nodeType !== 1) return;
          if (el.id) el.id += '-mod';
          if (el.classList && el.classList.length)
            el.className = Array.from(el.classList).map(c => c + '-mod').join(' ');
          for (const child of el.querySelectorAll('*[id], *[class]')) {
            if (child.id) child.id += '-mod';
            if (child.classList && child.classList.length)
              child.className = Array.from(child.classList).map(c => c + '-mod').join(' ');
          }
        }
        modIds(btn);
        modIds(form);

        let stash = document.getElementById('ao3-filters-stash');
        if (!stash) {
          stash = document.createElement('div');
          stash.id = 'ao3-filters-stash';
          stash.style.display = 'none';
          document.body.appendChild(stash);
        }
        stash.appendChild(origButton);
        stash.appendChild(origForm);

        const parent = stash.parentElement || document.querySelector('ul.navigation, header, body');
        (parent || document.body).insertBefore(btn, parent?.firstChild || null);

        Object.assign(form.style, {
          position: 'fixed',
          top: '15%',
          left: '50%',
          transform: 'translateX(-50%)',
          background: '#fff',
          border: '1px solid rgba(0,0,0,0.15)',
          borderRadius: '8px',
          boxShadow: '0 8px 30px rgba(0,0,0,0.4)',
          padding: '20px',
          width: 'min(95%, 800px)',
          maxHeight: '75vh',
          overflowY: 'auto',
          zIndex: '100000',
          display: 'none',
          opacity: '0',
          transition: 'opacity 0.25s ease'
        });

        const backdrop = document.createElement('div');
        backdrop.id = 'ao3-filter-backdrop-mod';
        Object.assign(backdrop.style, {
          position: 'fixed',
          inset: '0',
          background: 'rgba(0,0,0,0.35)',
          zIndex: '99999',
          display: 'none'
        });
        document.body.appendChild(backdrop);
        document.body.appendChild(form);

        const open = () => {
          form.style.display = 'block';
          backdrop.style.display = 'block';
          requestAnimationFrame(() => form.style.opacity = '1');
          document.body.style.overflow = 'hidden';
          document.body.className = document.body.className.replace(/\bfilters-\w+\b/g, '');
        };
        const close = () => {
          form.style.opacity = '0';
          backdrop.style.display = 'none';
          document.body.style.overflow = '';
          setTimeout(() => (form.style.display = 'none'), 250);
        };

        btn.addEventListener('click', e => {
          e.preventDefault();
          form.style.display === 'block' ? close() : open();
        });
        backdrop.addEventListener('click', close);
        document.addEventListener('keydown', e => {
          if (e.key === 'Escape' && form.style.display === 'block') close();
        });

        console.info('✅ AO3 filter mod: popup ready.');
        return true;
      } catch (err) {
        console.error('⚠️ AO3 filter mod error', err);
        return false;
      }
    }

    const tryInject = () => {
      if (!injectAO3FilterMod()) setTimeout(tryInject, 1000);
    };
    if (document.readyState === 'complete' || document.readyState === 'interactive')
      setTimeout(tryInject, 1200);
    else
      document.addEventListener('DOMContentLoaded', () => setTimeout(tryInject, 1200));
  })();
  """;

    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(js);
      } else if (_controller != null) {
        await _controller!.runJavaScript(js);
      }
    } catch (e) {
      debugPrint('⚠️ Filter form injection failed: $e');
    }
  }

  void _performSearch() {
    final query = _urlController.text.trim();
    if (query.isEmpty) return;

    final params = {'work_search[$_searchType]': query, 'commit': 'Search'};

    final uri = Uri.https('archiveofourown.org', '/works/search', params);

    if (_isWindows) {
      _winController?.loadUrl(uri.toString());
    } else {
      _controller?.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(storageProvider);

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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search),
                            tooltip: 'Quick Search',
                            onPressed: _performSearch,
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune),
                            tooltip: 'Advanced Search',
                            onPressed: () async {
                              final lastFilters = await storage
                                  .getAdvancedFilters();

                              final result =
                                  await Navigator.push<Map<String, dynamic>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdvancedSearchScreen(
                                        initialFilters: lastFilters,
                                      ),
                                    ),
                                  );

                              if (result == null) return;

                              final url = result['url'] as String?;
                              final filters =
                                  result['filters'] as Map<String, dynamic>?;

                              if (filters != null) {
                                await storage.saveAdvancedFilters(filters);
                              }

                              if (url != null && url.isNotEmpty) {
                                if (_isWindows) {
                                  await _winController?.loadUrl(url);
                                } else {
                                  await _controller?.loadRequest(
                                    Uri.parse(url),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.bookmarks),
                            tooltip: 'Saved Searches',
                            onPressed: () async {
                              final saved = await storage.getSavedSearches();
                              if (!context.mounted) return;
                              await _showSavedSearchDialog(context, saved);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.bookmark_add),
                            tooltip: 'Save Current Search',
                            onPressed: () async {
                              final query = _urlController.text.trim();
                              if (query.isEmpty) return;

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
                                      onPressed: () => Navigator.pop(
                                        ctx,
                                        nameController.text.trim(),
                                      ),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );

                              if (result == null || result.isEmpty) return;

                              final filters = await storage
                                  .getAdvancedFilters();
                              final params = {
                                'work_search[$_searchType]': query,
                                'commit': 'Search',
                              };
                              final uri = Uri.https(
                                'archiveofourown.org',
                                '/works/search',
                                params,
                              );

                              await storage.saveSearch(
                                result,
                                uri.toString(),
                                filters,
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved search "$result"!'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
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
            child: Stack(
              children: [
                if (_readyToShow)
                  AnimatedOpacity(
                    opacity: _readyToShow ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: _isWindows
                        ? win.Webview(_winController!)
                        : WebViewWidget(controller: _controller!),
                  ),

                if (!_readyToShow)
                  Container(
                    color: Theme.of(context).colorScheme.background,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
                        final url = item['url'] ?? '';
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
}
