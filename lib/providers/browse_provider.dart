import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

final readerJsProvider = Provider<String>((ref) {
  final theme = ref.watch(themeProvider);
  return theme == ThemeMode.dark ? _darkModeJs : _lightModeJs;
});

const _lightModeJs = '''
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
      'header .actions, ul.primary.navigation.actions { display: none !important; }',
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
  } else { apply(); }
  try { var mo = new MutationObserver(function() { apply(); });
    mo.observe(document.documentElement, { childList: true, subtree: true });
  } catch(e) {}
})();
''';

const _darkModeJs = '''
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
      'header .actions, ul.primary.navigation.actions { display: none !important; }',
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
  } else { apply(); }
  try { var mo = new MutationObserver(function() { apply(); });
    mo.observe(document.documentElement, { childList: true, subtree: true });
  } catch(e) {}
})();
''';
