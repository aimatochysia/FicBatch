import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../models.dart';
import '../services/library_service.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';

class ReaderScreenArgs {
  final WorkItem work;
  ReaderScreenArgs({required this.work});
}

class ReaderScreen extends StatefulWidget {
  static const routeBase = '/reader';
  final ReaderScreenArgs args;
  const ReaderScreen({super.key, required this.args});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  InAppWebViewController? _web;
  Timer? _autoTimer;
  double _progress = 0.0;
  List<Map<String, String>> _chapters = [];
  bool _chaptersOpen = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    if (settings.autosaveEnabled) _startAutosaveTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _startAutosaveTimer() {
    final settings = context.read<SettingsService>();
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(Duration(seconds: settings.autosaveSeconds), (_) => _saveProgress());
  }

  Future<void> _saveProgress() async {
    final lib = context.read<LibraryService>();
    final hist = context.read<HistoryService>();
    if (_web == null) return;
    try {
      // calculate normalized progress
      final res = await _web!.evaluateJavascript(source: """
(() => {
  const y = window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0;
  const h = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
  const inner = window.innerHeight || document.documentElement.clientHeight;
  const max = Math.max(1, h - inner);
  return JSON.stringify({y, max});
})()
""");
      if (res == null) return;
      final map = Map<String, dynamic>.from(res);
      final y = (map['y'] as num).toInt();
      final max = (map['max'] as num).toInt();
      final pct = max <= 0 ? 0.0 : (y / max).clamp(0.0, 1.0);
      setState(() => _progress = pct);

      final w = widget.args.work.copyWith(
        progress: pct,
        lastScrollY: y,
        lastContentHeight: max,
      );
      await lib.updateWork(w);

      // emit debug-ish progress logs at 25% and 50% thresholds
      final p25 = (pct >= 0.25 && pct < 0.26);
      final p50 = (pct >= 0.50 && pct < 0.51);
      if (p25 || p50) {
        hist.add(LogKind.progress, id: w.id, title: w.title,
            extra: "[PROGRESSES] ${(pct * 100).toStringAsFixed(0)}% in ${w.title} - ${w.id}");
      }

      if (pct >= 0.99) {
        hist.add(LogKind.finished, id: w.id, title: w.title,
            extra: "[FINISHED] ${w.title} - ${w.id}");
      }
    } catch (_) {}
  }

  Future<void> _restoreScroll(WorkItem w) async {
    if (_web == null) return;
    if (w.lastScrollY > 0) {
      await _web!.evaluateJavascript(source: "window.scrollTo(0, ${w.lastScrollY});");
    }
  }

  Future<void> _applyReaderFont() async {
    final scale = context.read<SettingsService>().readerFontScale;
    await _web?.evaluateJavascript(source: """
(() => {
  const s = document.getElementById('ficbatch_font') || (function(){
    const style = document.createElement('style');
    style.id='ficbatch_font';
    document.head.appendChild(style);
    return style;
  })();
  s.textContent = `html, body { font-size: ${ (scale * 100).toStringAsFixed(0) }% !important; line-height: 1.6; }`;
})();
""");
  }

  Future<void> _loadChapters() async {
    if (_web == null) return;
    final res = await _web!.evaluateJavascript(source: """
(() => {
  const arr = [];
  const sels = ['#chapters h2', '#chapters h3', 'h2.heading', 'h3.heading', 'h2.title', 'h3.title'];
  const nodes = sels.map(s => Array.from(document.querySelectorAll(s))).flat();
  let idx=1;
  for (const el of nodes) {
    if (!el.id) { el.id = 'ficbatch_ch_'+(idx++); }
    const t = (el.textContent||'').trim();
    if (t) arr.push({title:t, id:el.id});
  }
  return arr;
})()
""");
    if (res is List) {
      setState(() {
        _chapters = res.map((e) => {'title': e['title'], 'id': e['id']}).cast<Map<String,String>>().toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.args.work;
    final settings = context.watch<SettingsService>();

    return NeumorphicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(work.title, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            icon: const Icon(Icons.menu_book),
            onPressed: () async {
              await _loadChapters();
              setState(() => _chaptersOpen = !_chaptersOpen);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  builder: (_) => _ReaderSettings(),
                );
                await _applyReaderFont();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialFile: work.filePath,
              initialSettings: InAppWebViewSettings(
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                javaScriptEnabled: true,
                transparentBackground: true,
                supportZoom: true,
              ),
              onWebViewCreated: (c) => _web = c,
              onLoadStop: (c, url) async {
                await _applyReaderFont();
                await _restoreScroll(work);
              },
              onScrollChanged: (c, x, y) {
                // update in-memory meter quickly; persisted by autosave timer
                _progressUpdateQuick();
              },
            ),
            if (_chaptersOpen) Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _chaptersOpen = false),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
            if (_chaptersOpen) Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 300,
                height: double.infinity,
                color: Theme.of(context).cardColor,
                child: ListView.builder(
                  itemCount: _chapters.length,
                  itemBuilder: (_, i) {
                    final ch = _chapters[i];
                    return ListTile(
                      title: Text(ch['title']!),
                      onTap: () async {
                        await _web?.evaluateJavascript(source: "document.getElementById('${ch['id']}')?.scrollIntoView();");
                        setState(() => _chaptersOpen = false);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _progressUpdateQuick() async {
    if (_web == null) return;
    try {
      final res = await _web!.evaluateJavascript(source: """
(() => {
  const y = window.scrollY || document.documentElement.scrollTop || document.body.scrollTop || 0;
  const h = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
  const inner = window.innerHeight || document.documentElement.clientHeight;
  const max = Math.max(1, h - inner);
  return y/max;
})()
""");
      if (res is num) setState(() => _progress = res.toDouble().clamp(0.0, 1.0));
    } catch (_) {}
  }
}

class _ReaderSettings extends StatefulWidget {
  @override
  State<_ReaderSettings> createState() => _ReaderSettingsState();
}

class _ReaderSettingsState extends State<_ReaderSettings> {
  late double _scale;
  late bool _auto;
  late int _secs;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _scale = s.readerFontScale;
    _auto = s.autosaveEnabled;
    _secs = s.autosaveSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Reader Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              const Text('Font size'),
              Expanded(
                child: Slider(
                  min: 0.6, max: 2.0, divisions: 14,
                  value: _scale,
                  label: '${(_scale*100).toStringAsFixed(0)}%',
                  onChanged: (v) => setState(() => _scale = v),
                ),
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Autosave reading position'),
            value: _auto,
            onChanged: (v) => setState(() => _auto = v),
          ),
          Row(
            children: [
              const Text('Autosave every'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _secs,
                items: const [5,10,15,20,30].map((e)=>DropdownMenuItem(value:e, child: Text('$e s'))).toList(),
                onChanged: (v) => setState(() => _secs = v ?? _secs),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final s = context.read<SettingsService>();
              await s.setReaderFontScale(_scale);
              await s.setAutosaveEnabled(_auto);
              await s.setAutosaveSeconds(_secs);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
