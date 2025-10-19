class Ao3ListInjector {
  static String build() => r"""
(function(){
  try {
    function sendMessage(payload) {
      try {
        const s = typeof payload === 'string' ? payload : JSON.stringify(payload);
        if (window.FB_BRIDGE && window.FB_BRIDGE.postMessage) {
          window.FB_BRIDGE.postMessage(s);
        } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
          window.chrome.webview.postMessage(s);
        } else {
          console.log('[FB] No bridge to host');
        }
      } catch (e) { console.log('sendMessage error', e); }
    }

    window.__fb_requestSave = function(workId) {
      if (!workId) return;
      sendMessage({ type: 'saveWork', id: workId });
    };

    const styleId = '__fb_save_style';
    if (!document.getElementById(styleId)) {
      const st = document.createElement('style');
      st.id = styleId;
      st.textContent = `
        .fb-save-btn {
          display: inline-flex; align-items: center; gap: 6px;
          background: #2563eb; color: #fff; border-radius: 4px; padding: 2px 8px;
          font-size: 12px; border: none; cursor: pointer;
        }
        .fb-save-btn:hover { filter: brightness(0.95); }
        .work.blurb.group .heading { display: flex; justify-content: space-between; align-items: center; }
      `;
      (document.head || document.documentElement).appendChild(st);
    }

    window.__fb_attachSaveButtons = function(root){
      try {
        root = root || document;
        const ol = root.querySelector('ol.work.index.group');
        if (!ol) return;
        const items = ol.querySelectorAll('li.work.blurb.group');
        items.forEach(li => {
          if (li.querySelector('.fb-save-btn')) return;
          const header = li.querySelector('.heading') || li;
          const idAttr = li.getAttribute('id') || '';
          let workId = '';
          const idMatch = idAttr.match(/work_(\d+)/);
          if (idMatch) workId = idMatch[1];
          if (!workId) {
            const cls = li.getAttribute('class') || '';
            const m2 = cls.match(/work-(\d+)/);
            if (m2) workId = m2[1];
          }
          if (!workId) return;

          const btn = document.createElement('button');
          btn.type = 'button';
          btn.className = 'fb-save-btn';
          btn.title = 'Save to Library';
          btn.innerHTML = '<span>Save</span>';
          btn.addEventListener('click', (e) => {
            e.preventDefault(); e.stopPropagation();
            window.__fb_requestSave(workId);
          }, { passive: true });

          const rightWrap = document.createElement('div');
          rightWrap.style.display = 'flex';
          rightWrap.style.gap = '6px';
          rightWrap.appendChild(btn);

          const titleWrap = header.querySelector(':scope > h4') || header.firstElementChild;
          if (titleWrap && titleWrap.parentElement === header) {
            header.appendChild(rightWrap);
          } else {
            header.appendChild(rightWrap);
          }
        });
      } catch (e) { console.log('attachButtons error', e); }
    };

    window.__fb_attachSaveButtons(document);

    if (!window.__fb_save_obs) {
      window.__fb_save_obs = new MutationObserver((mut) => {
        let need = false;
        for (const m of mut) {
          if (m.addedNodes && m.addedNodes.length) { need = true; break; }
        }
        if (need) window.__fb_attachSaveButtons(document);
      });
      window.__fb_save_obs.observe(document.documentElement, { childList: true, subtree: true });
    }

    console.log('[FB] Save buttons attached');
  } catch (e) { console.log('injectSaveButtons error', e); }
})();
""";
}
