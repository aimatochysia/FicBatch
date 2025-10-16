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
  String _currentUrl = '';

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
            await _updateCurrentUrl();
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
              onPageFinished: (url) async {
                await _injectReaderMode();
                await _injectHideFilterButton();
                if (mounted) {
                  setState(() {
                    _currentUrl = url;
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
      debugPrint('WebView init failed: $e');
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
        return false;
      }

      const origParent = origButton.parentElement;
      const nextSibling = origButton.nextSibling;

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

      if (origParent) {
        if (nextSibling) origParent.insertBefore(btn, nextSibling);
        else origParent.appendChild(btn);
      } else {
        document.body.appendChild(btn);
      }

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
        setTimeout(() => (form.style.display = 'none'), 10);
      };

      btn.addEventListener('click', e => {
        e.preventDefault();
        form.style.display === 'block' ? close() : open();
      });
      backdrop.addEventListener('click', close);
      document.addEventListener('keydown', e => {
        if (e.key === 'Escape' && form.style.display === 'block') close();
      });

      return true;
    } catch (err) {
      return false;
    }
  }

  const tryInject = () => {
    if (!injectAO3FilterMod()) setTimeout(tryInject, 10);
  };
  if (document.readyState === 'complete' || document.readyState === 'interactive')
    setTimeout(tryInject, 20);
  else
    document.addEventListener('DOMContentLoaded', () => setTimeout(tryInject, 20));
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

    setState(() {
      _currentUrl = uri.toString();
    });

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
                                setState(() {
                                  _currentUrl = url;
                                });
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
                              final live = await _getCurrentUrl();
                              final current = (live ?? _currentUrl).trim();
                              if (mounted) {
                                setState(() {
                                  _currentUrl = current;
                                });
                              }
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
                                        hintText:
                                            'Enter a name for this search',
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

                                await storage.saveSearch(
                                  result,
                                  current,
                                  filters,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Saved search "$result"!'),
                                    ),
                                  );
                                }
                              } else {
                                _showSnackBar(
                                  'Cannot save a specific work or chapter page.',
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

  bool _isValidSearchUrl(String url) {
    debugPrint('Checking URL for validity: $url');
    if (url.contains('archiveofourown.org/tags/') && url.contains('/works')) {
      return true;
    }

    if (url.contains('archiveofourown.org/works?')) {
      return true;
    }

    if (url.contains('archiveofourown.org/works/') && !url.contains('?')) {
      return false;
    }

    if (url.contains('archiveofourown.org/works/') &&
        url.contains('/chapters/')) {
      return false;
    }

    return false;
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
    try {
      final url = await _getJson<String>('window.location.href');
      return url;
    } catch (_) {
      return null;
    }
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

    final jsonStr = _isWindows
        ? await _winController!.executeScript(js)
        : await _controller!.runJavaScriptReturningResult(js);

    return Map<String, List<String>>.from(
      (jsonDecode(jsonStr) as Map).map(
        (k, v) => MapEntry(k, List<String>.from(v)),
      ),
    );
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
}
