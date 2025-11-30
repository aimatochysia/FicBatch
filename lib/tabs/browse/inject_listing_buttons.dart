import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

Future<void> injectListingButtons({
  required bool isWindows,
  required win.WebviewController? winController,
  required WebViewController? controller,
  void Function(String message)? dartDebugPrint,
}) async {
  const js = r"""
(function(){
  try {
    var DEBUG = true;

    function notifyApp(obj){
      try {
        var s = JSON.stringify(obj);
        if (window.FB && FB.postMessage) FB.postMessage(s);
        if (window.chrome && chrome.webview && chrome.webview.postMessage) chrome.webview.postMessage(s);
      } catch(e) {}
    }
    function log(level, msg, ctx){
      if (DEBUG) try { console.log('[FB]', level, msg, ctx||''); } catch(_){}
      notifyApp({ type:'injectorLog', level: level, msg: msg, ctx: ctx || '' });
    }

    log('info', 'injector start', location.pathname);

    if (!window.__fb_save_state) {
      window.__fb_save_state = { processed: new Set() };
      log('info', 'save_state created', '');
    } else {
      try {
        var size = window.__fb_save_state.processed ? window.__fb_save_state.processed.size : -1;
        log('info', 'save_state reused', 'processed=' + size);
      } catch(_){}
    }

    async function saveWorkById(id){
      log('debug', 'saveWorkById fetch', id);
      const resp = await fetch('/works/' + id + '?view_full_work=true&view_adult=true', { credentials: 'same-origin' });
      if (!resp.ok) { log('error', 'fetch failed', String(resp.status)); throw new Error('HTTP ' + resp.status); }
      const html = await resp.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');
      function text(sel){ const el = doc.querySelector(sel); return el ? (el.textContent||'').trim() : ''; }
      function inner(sel){ const el = doc.querySelector(sel); return el ? (el.innerText||'').trim() : ''; }
      function collectTags(){
        const out = {};
        const root = doc.querySelector('dl.work.meta.group');
        if (!root) return out;
        root.querySelectorAll('dt').forEach(dt=>{
          const key = (dt.className||'').split(' ')[0];
          const dd = dt.nextElementSibling;
          if (!dd) return;
          if (key === 'language') { out.language = (dd.textContent||'').trim(); return; }
          if (key === 'stats') return;
          const tags = Array.from(dd.querySelectorAll('a.tag')).map(a=>(a.textContent||'').trim()).filter(Boolean);
          if (tags.length) out[key] = tags;
        });
        return out;
      }
      function collectStats(){
        const o = {};
        const stats = doc.querySelector('dl.stats');
        if (!stats) return o;
        function grab(cls){ const dd = stats.querySelector('dd.' + cls); return dd ? (dd.textContent||'').trim() : ''; }
        o.published = grab('published');
        o.updated = grab('status') || grab('updated');
        o.words = grab('words');
        o.chapters = grab('chapters');
        o.kudos = grab('kudos');
        o.hits = grab('hits');
        o.comments = grab('comments');
        return o;
      }
      const meta = {
        title: text('h2.title.heading'),
        author: text('h3.byline.heading a[rel="author"]'),
        summary: inner('div.summary.module blockquote.userstuff'),
        tags: collectTags(),
        stats: collectStats()
      };
      log('info', 'fetched meta', 'id=' + id + ' title="' + meta.title + '"');
      return meta;
    }

    function findWorkId(li){
      var m = (li.id||'').match(/work_(\d+)/);
      if (m) return m[1];
      m = (li.className||'').match(/work-(\d+)/);
      if (m) return m[1];
      var a = li.querySelector('a[href^="/works/"]');
      if (a) {
        var mx = a.getAttribute('href').match(/\/works\/(\d+)/);
        if (mx) return mx[1];
      }
      return null;
    }

    function insertButton(li){
      var id = findWorkId(li);
      if (!id) { log('debug', 'skip li (no id)', ''); return; }
      if (window.__fb_save_state.processed.has(id)) { log('debug', 'skip (already processed)', id); return; }
      window.__fb_save_state.processed.add(id);

      var header = li.querySelector('.header.module') || li.querySelector('.header') || li;
      var heading = header.querySelector('h4.heading') || header.querySelector('.heading') || header;
      if (!heading) heading = header;

      var btn = document.createElement('a');
      btn.href = '#';
      btn.className='__fb_save_btn';
      btn.textContent='+ Save to Library';
      btn.style.cssText = [
        'display:inline-block',
        'margin-left:12px',
        'padding:6px 12px',
        'background:linear-gradient(135deg, #900 0%, #c00 100%)',
        'color:#fff',
        'border:none',
        'border-radius:6px',
        'font-size:13px',
        'font-weight:600',
        'line-height:1.2',
        'vertical-align:middle',
        'float:right',
        'text-decoration:none',
        'cursor:pointer',
        'box-shadow:0 2px 4px rgba(0,0,0,0.2)',
        'transition:all 0.2s ease'
      ].join(';');
      btn.onmouseover = function(){ btn.style.background='linear-gradient(135deg, #a00 0%, #d00 100%)'; btn.style.boxShadow='0 3px 6px rgba(0,0,0,0.3)'; btn.style.transform='translateY(-1px)'; };
      btn.onmouseout = function(){ btn.style.background='linear-gradient(135deg, #900 0%, #c00 100%)'; btn.style.boxShadow='0 2px 4px rgba(0,0,0,0.2)'; btn.style.transform='translateY(0)'; };

      heading.appendChild(btn);
      log('info', 'button inserted', id);

      btn.addEventListener('click', function(e){
        e.preventDefault();
        log('debug', 'click save', id);
        btn.textContent='Saving...';
        btn.style.opacity='0.7';
        btn.style.pointerEvents='none';
        saveWorkById(id).then(function(meta){
          notifyApp({ type:'saveWorkFromListing', workId:id, meta: meta });
          btn.textContent='✓ Saved!';
          btn.style.background='linear-gradient(135deg, #090 0%, #0a0 100%)';
        }).catch(function(err){
          log('error', 'save error', id + ' ' + String(err));
          notifyApp({ type:'saveWorkError', workId:id, error: String(err) });
          btn.textContent='✗ Error';
          btn.style.background='linear-gradient(135deg, #666 0%, #888 100%)';
        }).finally(function(){
          btn.style.opacity='1';
          btn.style.pointerEvents='auto';
          setTimeout(function(){ 
            btn.textContent='+ Save to Library'; 
            btn.style.background='linear-gradient(135deg, #900 0%, #c00 100%)'; 
          }, 2000);
        });
      });
    }

    function run(){
      var lists = document.querySelectorAll('ol.work.index.group, ol.index.group');
      log('info', 'run() lists', String(lists.length));
      if (!lists || lists.length === 0) return;
      lists.forEach(function(list, idx){
        var items = list.querySelectorAll('li.blurb[role="article"], li.work.blurb.group');
        log('info', 'list items', 'list[' + idx + ']=' + items.length);
        items.forEach(insertButton);
      });
      log('info', 'run complete', 'processed=' + (window.__fb_save_state.processed ? window.__fb_save_state.processed.size : -1));
    }

    var attempts = 5, interval = 200;
    log('info', 'scheduling burst', 'attempts=' + attempts + ' interval=' + interval + 'ms');
    for (var i = 0; i < attempts; i++) {
      (function(k){
        setTimeout(function(){
          log('debug', 'burst attempt', (k+1) + '/' + attempts);
          run();
        }, k * interval);
      })(i);
    }

    if (!window.__fb_save_mo) {
      log('info', 'create MutationObserver', '');
      window.__fb_save_mo = new MutationObserver(function(muts){
        var added = 0;
        for (var i=0;i<muts.length;i++){
          if (muts[i].addedNodes && muts[i].addedNodes.length) { added += muts[i].addedNodes.length; }
        }
        if (added > 0) log('debug', 'mutation observed -> rerun', 'added=' + added);
        run();
      });
      window.__fb_save_mo.observe(document.documentElement, { childList:true, subtree:true });
    } else {
      log('info', 'reuse existing MutationObserver', '');
    }

    window.__fb_save_forceRun = run;
  } catch (e) {
    try { notifyApp({ type:'injectorLog', level:'error', msg:'inject error', ctx:String(e) }); } catch(_) {}
    try { console.log('[FB] inject save buttons error', e); } catch(_){}
  }
})();
""";

  try {
    dartDebugPrint?.call('[BrowseTab] Executing injectListingButtons JS...');
    if (isWindows && winController != null) {
      await winController.executeScript(js);
    } else if (controller != null) {
      await controller.runJavaScript(js);
    }
    dartDebugPrint?.call('[BrowseTab] injectListingButtons executed (OK)');
  } catch (e) {
    dartDebugPrint?.call('⚠️ inject listing buttons failed: $e');
  }
}
