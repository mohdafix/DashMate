/*
 * DashMate car keyboard hook. Injected by DashMatePresentation on every page load, in the deck
 * WebView and the browser WebView. Android Auto has no system keyboard on the car screen, so when
 * a text field is tapped or focused this asks the native DashMate keyboard to open
 * (AutoDeck.editText), then the native side writes back with __ddKbd.set / submit / close.
 * Idempotent: a second injection only re-scans iframes.
 */
(function () {
  var K = window.__ddKbd;
  if (K && K.v === 1) { K.scan(); return; }

  var TEXT_TYPES = /^(text|search|email|url|tel|number|password)$/i;
  var els = {};          // id -> element (works across same-origin iframes, unlike a selector)
  var seq = 0;
  var openId = null;     // field the keyboard is open for
  var openAt = 0;
  var closedId = null;   // field just closed, and when (stops close -> refocus -> open loops)
  var closedAt = 0;
  var lastTap = 0;       // last real pointerdown in any hooked document

  function editHost(el) {
    while (el && el.parentElement && el.parentElement.isContentEditable) el = el.parentElement;
    return el;
  }

  /** The editable field for an event target, or null. */
  function fieldOf(el) {
    if (!el || el.nodeType !== 1) return null;
    var t = el.tagName;
    if (t === 'INPUT') {
      var type = (el.getAttribute('type') || 'text').trim();
      if (!TEXT_TYPES.test(type)) return null;
    } else if (t === 'TEXTAREA') {
      // ok
    } else if (el.isContentEditable) {
      el = editHost(el);
    } else {
      return null;
    }
    if (el.disabled || el.readOnly) return null;
    if ((el.getAttribute('inputmode') || '') === 'none') return null;
    if (el.getAttribute('aria-readonly') === 'true') return null;
    return el;
  }

  function targetOf(e) {
    var p = e.composedPath ? e.composedPath() : null;
    var el = p && p.length ? p[0] : e.target;
    if (el && el.nodeType === 3) el = el.parentElement;
    var f = fieldOf(el);
    if (!f && el && el.closest) {
      // Tap on a <label>-like child inside a contenteditable, or a wrapper around the input.
      var c = el.closest('input,textarea,[contenteditable]');
      if (c) f = fieldOf(c);
    }
    return f;
  }

  function idOf(el) {
    var id = el.getAttribute('data-dd-kbd-id');
    if (!id || els[id] !== el) {
      id = 'k' + (++seq);
      try { el.setAttribute('data-dd-kbd-id', id); } catch (err) {}
    }
    els[id] = el;
    return id;
  }

  function valueOf(el) {
    return el.isContentEditable && el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA'
      ? (el.innerText || '').replace(/\n$/, '')
      : (el.value || '');
  }

  function labelText(el) {
    try {
      if (el.labels && el.labels.length) return el.labels[0].innerText.trim();
      var lb = el.getAttribute('aria-labelledby');
      if (lb) {
        var n = el.ownerDocument.getElementById(lb.split(/\s+/)[0]);
        if (n) return (n.innerText || '').trim();
      }
    } catch (err) {}
    return '';
  }

  function hintOf(el) {
    return el.getAttribute('placeholder') || el.getAttribute('aria-label') ||
      el.getAttribute('aria-placeholder') || el.getAttribute('data-placeholder') ||
      labelText(el) || el.getAttribute('title') || '';
  }

  function typeOf(el) {
    if (el.tagName === 'TEXTAREA') return 'textarea';
    if (el.tagName !== 'INPUT') return 'contenteditable';
    var im = (el.getAttribute('inputmode') || '').toLowerCase();
    if (im === 'numeric' || im === 'decimal') return 'number';
    return (el.getAttribute('type') || 'text').toLowerCase();
  }

  function bridge() {
    return window.AutoDeck || window.AutoDeckWeb || null;
  }

  function open(el, byTap) {
    var b = bridge();
    if (!b) return;
    var id = idOf(el);
    var now = Date.now();
    if (id === openId && now - openAt < 600) return;           // pointerdown + focusin of one tap
    if (!byTap && id === closedId && now - closedAt < 1500) return; // site refocused what we closed
    window.__ddField = el;
    openId = id;
    openAt = now;
    try { el.scrollIntoView({ block: 'center', inline: 'nearest' }); } catch (err) {}
    try {
      if (b.editText) b.editText(id, valueOf(el), hintOf(el), typeOf(el));
      else b.textField(valueOf(el), hintOf(el));
    } catch (err) {}
  }

  function onDown(e) {
    lastTap = Date.now();
    var f = targetOf(e);
    if (f) open(f, true);
  }

  function onFocus(e) {
    var f = targetOf(e);
    if (!f) return;
    // Only focus that follows a real tap opens the keyboard (a search icon that focuses its box,
    // a "next field" jump); a page focusing a field by itself on load does not.
    var act = navigator.userActivation;
    var recent = Date.now() - lastTap < 5000 || (act && act.isActive);
    if (recent) open(f, false);
  }

  function hookDoc(doc) {
    if (!doc || doc.__ddKbdHooked) return;
    try {
      doc.__ddKbdHooked = true;
      doc.addEventListener('pointerdown', onDown, true);
      doc.addEventListener('focusin', onFocus, true);
      watchFrames(doc);
    } catch (err) {}
  }

  function hookFrame(fr) {
    var go = function () {
      try { hookDoc(fr.contentDocument); } catch (err) {} // cross-origin: not reachable
    };
    if (!fr.__ddKbdLoad) {
      fr.__ddKbdLoad = true;
      fr.addEventListener('load', go);
    }
    go();
  }

  function scanFrames(doc) {
    try {
      var frs = doc.querySelectorAll('iframe,frame');
      for (var i = 0; i < frs.length; i++) hookFrame(frs[i]);
    } catch (err) {}
  }

  function watchFrames(doc) {
    scanFrames(doc);
    if (!window.MutationObserver || !doc.documentElement) return;
    // Only to catch iframes added later; plain fields need nothing (listeners are delegated).
    new MutationObserver(function (muts) {
      for (var i = 0; i < muts.length; i++) {
        var a = muts[i].addedNodes;
        for (var j = 0; j < a.length; j++) {
          var n = a[j];
          if (n.nodeType !== 1) continue;
          if (n.tagName === 'IFRAME' || n.tagName === 'FRAME') hookFrame(n);
          else if (n.firstElementChild && n.querySelector('iframe')) scanFrames(n);
        }
      }
    }).observe(doc.documentElement, { childList: true, subtree: true });
  }

  function find(id) {
    var el = id ? els[id] : (window.__ddField || document.activeElement);
    el = el && el.isConnected ? fieldOf(el) : null;   // never write into a non-field (e.g. <body> after a navigation)
    return el;
  }

  function write(el, t) {
    if (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA') {
      el.textContent = t;
      try { el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: t })); }
      catch (err) { el.dispatchEvent(new Event('input', { bubbles: true })); }
      return;
    }
    // The native setter, so React/Vue controlled inputs see the change.
    var proto = el.tagName === 'INPUT' ? HTMLInputElement.prototype : HTMLTextAreaElement.prototype;
    var w = el.ownerDocument.defaultView;
    if (w && w !== window) proto = el.tagName === 'INPUT' ? w.HTMLInputElement.prototype : w.HTMLTextAreaElement.prototype;
    var d = Object.getOwnPropertyDescriptor(proto, 'value');
    if (d && d.set) d.set.call(el, t); else el.value = t;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function blur(el) {
    if (!el) return;
    closedId = el.getAttribute('data-dd-kbd-id');
    closedAt = Date.now();
    if (openId === closedId) openId = null;
    try { el.blur(); } catch (err) {}
  }

  K = window.__ddKbd = {
    v: 1,
    scan: function () { scanFrames(document); },
    /** Live text while typing (no Enter). */
    set: function (id, t) {
      var el = find(id);
      if (el) write(el, t);
    },
    /** Go / Enter on the DashMate keyboard. */
    submit: function (id, t) {
      var el = find(id);
      if (!el) return;
      write(el, t);
      if (/(^|\.)youtube\.com$/.test(location.hostname) &&
          (el.name === 'search_query' || /search/i.test(el.id + ' ' + el.className))) {
        location.href = '/results?search_query=' + encodeURIComponent(t);
        return;
      }
      var o = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true };
      var go = el.dispatchEvent(new KeyboardEvent('keydown', o));
      el.dispatchEvent(new KeyboardEvent('keypress', o));
      el.dispatchEvent(new KeyboardEvent('keyup', o));
      var form = el.form;
      if (go && form && el.tagName === 'INPUT') {
        try { if (form.requestSubmit) form.requestSubmit(); else form.submit(); } catch (err) {}
      }
      blur(el);
    },
    /** The keyboard was closed without Go. */
    close: function (id) {
      blur(find(id));
    }
  };

  hookDoc(document);
})();
