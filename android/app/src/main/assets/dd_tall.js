/* DashMate car pages: the "Always tall" layout lock (phone app › Settings › Car layout).
 *
 * Included at the end of <head> on every car page, after its <style>, so it runs before the
 * first paint. When the mode is "tall" (the default) and the page is not in the small Android
 * Auto split panel, <html> gets the class "dd-tall" and every portrait @media rule of the page
 * (aspect-ratio / width / height queries that a 720×1280 tall screen matches) is also applied
 * under :where(html.dd-tall), so a wide surface paints the tall UI. :where() adds no
 * specificity and the copy sits right after the original rule, so the cascade is unchanged.
 *
 * Mode source, first that answers: ?layout=tall|auto (screenshots), DashMate.layoutMode()
 * (bridge, if present), localStorage "dd_layout_mode" (cached from the last ddUpdate), "tall".
 * Pages call window.ddSetLayoutMode(p.layoutMode) from ddUpdate.
 */
(function () {
  var d = document.documentElement, mode = null;
  var q = /[?&]layout=(tall|auto)/.exec(location.search);
  if (q) mode = q[1];
  try { if (!mode && (window.DashMate?.layoutMode || window.DriveDeck?.layoutMode)) mode = (window.DashMate || window.DriveDeck).layoutMode(); } catch (e) {}
  try { if (!mode) mode = localStorage.getItem('dd_layout_mode'); } catch (e) {}
  window.ddLayoutMode = mode === 'tall' ? 'tall' : 'auto';

  // Same test as the pages' small-panel media query / isSmallPanel(): the tall grid can't fit there.
  function smallPanel() {
    var w = window.innerWidth, h = window.innerHeight;
    return w > 0 && h > 0 && h <= w * 1.05 && w < 620 && w / h <= 1.35;
  }
  function isPortrait() {
    return window.innerHeight > window.innerWidth * 1.05;
  }
  /** True when the page should use its tall placement / tall UI whatever the surface shape. */
  window.ddTallLock = function () {
    return (window.ddLayoutMode === 'tall' || (window.ddLayoutMode === 'auto' && isPortrait())) && !smallPanel();
  };

  // ---- Copy portrait @media rules under :where(html.dd-tall) ----
  var REF_W = 720, REF_H = 1280;   // a tall car screen (Jaecoo J7 class), in CSS px
  function ratio(v) { var p = v.split('/'); return p.length === 2 ? (+p[0]) / (+p[1]) : +v; }
  function feature(f) {
    var m = /^\(\s*(min|max)-(aspect-ratio|width|height)\s*:\s*([\d.\/\s]+?)(px)?\s*\)$/.exec(f.trim());
    if (!m) return null;                                  // unknown feature: don't copy
    var v = m[2] === 'aspect-ratio' ? ratio(m[3].replace(/\s/g, '')) : +m[3];
    var have = m[2] === 'aspect-ratio' ? REF_W / REF_H : (m[2] === 'width' ? REF_W : REF_H);
    return m[1] === 'min' ? have >= v : have <= v;
  }
  function matchesTall(text) {
    return text.split(',').some(function (part) {
      var all = part.trim().split(/\s+and\s+/i);
      for (var i = 0; i < all.length; i++) { if (feature(all[i]) !== true) return false; }
      return all.length > 0;
    });
  }
  function scoped(sel) {
    return sel.split(',').map(function (s) {
      s = s.trim();
      if (/^(html|:root)\b/.test(s)) return s.replace(/^(html|:root)/, '$1:where(.dd-tall)');
      return ':where(html.dd-tall) ' + s;
    }).join(', ');
  }
  // A rule's text with every selector under :where(html.dd-tall); nested @container kept as a wrapper.
  function scopedText(c) {
    if (c.type === 1) return scoped(c.selectorText) + ' { ' + c.style.cssText + ' }';
    if (c.cssRules && c.conditionText !== undefined && /^@container/i.test(c.cssText)) {
      var inner = [];
      for (var i = 0; i < c.cssRules.length; i++) { var t = scopedText(c.cssRules[i]); if (t) inner.push(t); }
      return '@container ' + c.conditionText + ' { ' + inner.join(' ') + ' }';
    }
    return null;                                          // anything else: not copied
  }
  function copyRules(list) {
    for (var i = list.length - 1; i >= 0; i--) {
      var r = list[i];
      if (r.type !== 4 || !r.media || !matchesTall(r.media.mediaText)) { if (r.cssRules && r.type !== 4) copyRules(r.cssRules); continue; }
      var parent = r.parentRule || r.parentStyleSheet, at = i + 1, css = [];
      for (var j = 0; j < r.cssRules.length; j++) { var t = scopedText(r.cssRules[j]); if (t) css.push(t); }
      for (var k = css.length - 1; k >= 0; k--) { try { parent.insertRule(css[k], at); } catch (e) {} }
    }
  }
  try { for (var s = 0; s < document.styleSheets.length; s++) copyRules(document.styleSheets[s].cssRules); } catch (e) {}

  function apply() { d.classList.toggle('dd-tall', window.ddTallLock()); }
  window.ddSetLayoutMode = function (v) {
    if (v !== 'tall' && v !== 'auto') return;
    if (!q) window.ddLayoutMode = v;
    try { localStorage.setItem('dd_layout_mode', v); } catch (e) {}
    apply();
  };
  apply();
  window.addEventListener('resize', apply);
})();
