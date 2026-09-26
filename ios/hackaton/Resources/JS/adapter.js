/*
 * adapter.js — IpoView
 * Applica un AdaptationPlan (vedi docs/adaptation-plan-contract.md) alla pagina corrente.
 * Iniettato da Swift come WKUserScript (documentEnd, main frame), dopo Readability.js
 * e Readability-readerable.js. Vanilla ES2020, nessuna dipendenza.
 *
 * API pubblica: IpoView.apply(plan), IpoView.setFontSizePx(px), IpoView.reset()
 */
(function () {
  'use strict';

  // ---------------------------------------------------------------------------
  // Stato interno: tutto ciò che tocchiamo viene registrato per poterlo annullare
  // ---------------------------------------------------------------------------
  const S = {
    applied: false,
    plan: null,
    pendingFontPx: null,  // impostato con setFontSizePx prima di apply
    inline: new Map(),    // Element -> Map(prop -> [valore, priorità]) originali
    classes: [],          // [Element, classe] aggiunte da noi
    attrs: [],            // [Element, attributo, valore originale] rimossi/cambiati
    added: [],            // nodi inseriti da noi
    viewport: null,       // {meta, content, created}
    observer: null,
    timer: null,
    pending: new Set(),
    reader: false,
    listeners: [],        // [target, evento, fn, opzioni]
  };

  const STYLE_ID = 'ipoview-style';
  const WHITE = { r: 255, g: 255, b: 255, a: 1 };
  const BLACK = { r: 0, g: 0, b: 0, a: 1 };
  const DARK = { r: 18, g: 18, b: 18, a: 1 };   // #121212
  const MID_LUM = 0.179;  // luminanza in cui nero e bianco danno lo stesso contrasto

  const COOKIE_RE = /cookie|consent|gdpr|popup|pop-up|modal|newsletter|overlay|iubenda|onetrust|didomi|quantcast|cmp-|paywall|lightbox|backdrop|interstitial/i;
  const COOKIE_SEL = [
    '[id*="cookie" i]', '[class*="cookie" i]', '[id*="consent" i]', '[class*="consent" i]',
    '[class*="gdpr" i]', '[id*="gdpr" i]', '[class*="popup" i]', '[class*="modal" i]',
    '[class*="newsletter" i]', '#onetrust-banner-sdk', '#onetrust-consent-sdk', '.fc-consent-root',
    '#iubenda-cs-banner', '[class*="iubenda" i]', '#didomi-host', '#qc-cmp2-container',
    '#CybotCookiebotDialog', '.cc-window', '[aria-modal="true"]',
  ].join(',');
  const AD_SEL = [
    '[class^="ad-"]', '[class*=" ad-"]', '[id^="ad-"]', '[id^="ad_"]', '.ad', '.ads', '.adsbox',
    '.advertisement', '.banner-pubblicitario', '[id^="google_ads"]', 'iframe[src*="doubleclick"]',
    'iframe[src*="googlesyndication"]', 'ins.adsbygoogle', '[class*="sponsor" i]', '[id*="sponsor" i]',
  ].join(',');
  // Elementi di testo a cui applicare dimensione e font
  const TEXT_TAGS = 'p,li,td,th,dd,dt,span,a,label,input,select,textarea,button,blockquote,figcaption,div.ipo-t,h1,h2,h3,h4,h5,h6';
  // Non toccare il font delle icone (icon font)
  const NOT_ICON = ':not([class*="icon" i]):not([class^="fa"]):not([class*=" fa-"]):not([class*="material" i]):not([aria-hidden="true"])';
  const SKIP_TAGS = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'HEAD', 'META', 'LINK', 'svg', 'SVG', 'PATH', 'BR', 'IFRAME']);

  // ---------------------------------------------------------------------------
  // Utilità
  // ---------------------------------------------------------------------------
  function post(msg) {
    try {
      const h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ipoview;
      if (h) h.postMessage(msg);
      else if (msg.type === 'log') console.log('[IpoView]', msg.message);
    } catch (e) { /* niente */ }
  }
  function log(m) { post({ type: 'log', message: String(m) }); }
  // Esegue un passo isolato: un errore non blocca gli altri
  function step(name, fn) {
    try { return fn(); } catch (e) { log(name + ': ' + (e && e.message ? e.message : e)); }
  }

  function setStyle(el, prop, value, prio = 'important') {
    if (!el || !el.style) return;
    let saved = S.inline.get(el);
    if (!saved) { saved = new Map(); S.inline.set(el, saved); }
    if (!saved.has(prop)) saved.set(prop, [el.style.getPropertyValue(prop), el.style.getPropertyPriority(prop)]);
    el.style.setProperty(prop, value, prio);
  }
  function addClass(el, cls) {
    if (el && el.classList && !el.classList.contains(cls)) { el.classList.add(cls); S.classes.push([el, cls]); }
  }
  function hide(el) { addClass(el, 'ipo-hide'); }
  function removeAttr(el, name) {
    if (el.hasAttribute(name)) { S.attrs.push([el, name, el.getAttribute(name)]); el.removeAttribute(name); }
  }
  function track(node) { S.added.push(node); return node; }
  function listen(target, ev, fn, opts) { target.addEventListener(ev, fn, opts); S.listeners.push([target, ev, fn, opts]); }
  function isOurs(n) { return !!(n && n.nodeType === 1 && n.closest && n.closest('[data-ipoview]')); }
  function isUI(n) { return !!(n && n.closest && n.closest('[data-ipoview="ui"]')); }
  function classStr(el) { return (el.getAttribute && el.getAttribute('class')) || ''; }
  function signature(el) {
    return (el.id + ' ' + classStr(el) + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('role') || '')).toLowerCase();
  }
  function hasDirectText(el) {
    for (const n of el.childNodes) if (n.nodeType === 3 && /\S/.test(n.nodeValue)) return true;
    return false;
  }
  function visible(el) { return el.getClientRects().length > 0; }
  // Contiene il contenuto principale? Allora non va nascosto
  function containsMain(el) {
    return el === document.body || el === document.documentElement ||
      !!el.querySelector('main,article,[role="main"]') || el.querySelectorAll('p').length > 5;
  }
  function collect(root, limit) {
    const out = [root];
    const all = root.querySelectorAll ? root.querySelectorAll('*') : [];
    for (let i = 0; i < all.length && out.length < limit; i++) out.push(all[i]);
    return out;
  }
  function num(v, d) { const n = Number(v); return Number.isFinite(n) ? n : d; }

  // ---------------------------------------------------------------------------
  // Colori: parsing, luminanza WCAG, HSL
  // ---------------------------------------------------------------------------
  const colorCache = new Map();
  let canvasCtx = null;
  function parseColor(str) {
    if (!str) return { r: 0, g: 0, b: 0, a: 0 };
    if (colorCache.has(str)) return colorCache.get(str);
    let c = null;
    let m = str.match(/^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/i);
    if (m) c = { r: +m[1], g: +m[2], b: +m[3], a: m[4] === undefined ? 1 : (m[4].endsWith('%') ? parseFloat(m[4]) / 100 : +m[4]) };
    else if (str === 'transparent') c = { r: 0, g: 0, b: 0, a: 0 };
    else if ((m = str.match(/^color\(srgb\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(?:\s*\/\s*([\d.]+))?\)$/i)))
      c = { r: m[1] * 255, g: m[2] * 255, b: m[3] * 255, a: m[4] === undefined ? 1 : +m[4] };
    else {
      // Formati moderni (oklch, lab…): li facciamo disegnare al canvas e leggiamo il pixel
      try {
        if (!canvasCtx) { const cv = document.createElement('canvas'); cv.width = cv.height = 1; canvasCtx = cv.getContext('2d', { willReadFrequently: true }); }
        canvasCtx.clearRect(0, 0, 1, 1); canvasCtx.fillStyle = str; canvasCtx.fillRect(0, 0, 1, 1);
        const d = canvasCtx.getImageData(0, 0, 1, 1).data;
        c = { r: d[0], g: d[1], b: d[2], a: d[3] / 255 };
      } catch (e) { c = { r: 0, g: 0, b: 0, a: 1 }; }
    }
    if (colorCache.size > 2000) colorCache.clear();
    colorCache.set(str, c);
    return c;
  }
  function hexToColor(hex, fallback) {
    const m = /^#?([0-9a-f]{6})$/i.exec(String(hex || '').trim());
    if (!m) return fallback;
    const v = parseInt(m[1], 16);
    return { r: (v >> 16) & 255, g: (v >> 8) & 255, b: v & 255, a: 1 };
  }
  function cssColor(c) { return `rgb(${Math.round(c.r)}, ${Math.round(c.g)}, ${Math.round(c.b)})`; }
  function blend(top, bottom) {
    const a = top.a;
    return { r: top.r * a + bottom.r * (1 - a), g: top.g * a + bottom.g * (1 - a), b: top.b * a + bottom.b * (1 - a), a: 1 };
  }
  function lum(c) {
    const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }
  function ratio(a, b) { const l1 = lum(a), l2 = lum(b); return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05); }
  function toHsl(c) {
    const r = c.r / 255, g = c.g / 255, b = c.b / 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
    let h = 0, s = 0;
    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
      h /= 6;
    }
    return { h, s, l };
  }
  function fromHsl(h, s, l) {
    if (s === 0) return { r: l * 255, g: l * 255, b: l * 255, a: 1 };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    const k = (t) => { if (t < 0) t += 1; if (t > 1) t -= 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 1 / 2 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
    return { r: k(h + 1 / 3) * 255, g: k(h) * 255, b: k(h - 1 / 3) * 255, a: 1 };
  }
  // R3: sposta solo la luminosità (tinta invariata) finché il contrasto basta; null se impossibile
  function adjustColor(fg, bg, target, preserveHue) {
    const hsl = toHsl(fg), dir = lum(bg) > MID_LUM ? -1 : 1, s = preserveHue ? hsl.s : 0;
    for (let l = hsl.l; ; l += dir * 0.02) {
      const lc = Math.min(1, Math.max(0, l));
      const c = fromHsl(hsl.h, s, lc);
      if (ratio(c, bg) >= target) return c;
      if (lc <= 0 || lc >= 1) return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Viewport
  // ---------------------------------------------------------------------------
  function forceViewport() {
    let meta = document.querySelector('meta[name="viewport"]');
    if (meta) S.viewport = { meta, content: meta.getAttribute('content'), created: false };
    else {
      meta = document.createElement('meta'); meta.name = 'viewport';
      (document.head || document.documentElement).appendChild(meta);
      S.viewport = { meta, created: true };
    }
    meta.setAttribute('content', 'width=device-width, initial-scale=1');
  }

  // ---------------------------------------------------------------------------
  // CSS generato dal piano
  // ---------------------------------------------------------------------------
  function themeColors(plan) {
    const c = plan.color || {};
    const theme = c.theme || 'originale';
    const dark = theme === 'scuro';
    const bg = hexToColor(c.background, dark ? DARK : { r: 255, g: 253, b: 247, a: 1 });
    const fg = hexToColor(c.text, dark ? { r: 232, g: 230, b: 227, a: 1 } : { r: 26, g: 26, b: 26, a: 1 });
    const bgIsDark = lum(bg) <= MID_LUM;
    return {
      theme, bg, fg, bgIsDark,
      link: bgIsDark ? '#8AB4F8' : '#0B4FA8',
      control: bgIsDark ? '#2A2A2A' : '#EFEBE0',
      focus: bgIsDark ? '#FFB000' : '#0047AB',
    };
  }

  function buildCSS(plan, ruleMode) {
    const t = plan.text || {}, l = plan.layout || {}, k = plan.controls || {}, cl = plan.cleanup || {}, c = plan.color || {};
    const tc = themeColors(plan);
    const family = String(t.fontFamily || 'Atkinson Hyperlegible').replace(/"/g, '');
    const fam = `"${family}", "Atkinson Hyperlegible", -apple-system, "Helvetica Neue", sans-serif`;
    const px = num(t.fontSizePx, 20);
    const lh = num(t.lineHeight, 1.5), ls = num(t.letterSpacingEm, 0.12), ws = num(t.wordSpacingEm, 0.16);
    const ps = num(t.paragraphSpacingEm, 2);
    const align = t.align === 'right' ? 'right' : 'left';   // mai giustificato
    const W = num(l.maxLineWidthPx, 600);
    const target = num(k.minTargetPt, 44), outline = num(k.focusOutlinePx, 3);
    const BG = cssColor(tc.bg), FG = cssColor(tc.fg);
    const out = [];

    // Font Atkinson Hyperlegible fornito da Swift come data URL
    if (window.__ipoFontDataURL) out.push(`@font-face{font-family:"${family}";font-weight:400;font-style:normal;src:url("${window.__ipoFontDataURL}");}`);
    if (window.__ipoFontBoldDataURL) out.push(`@font-face{font-family:"${family}";font-weight:700;font-style:normal;src:url("${window.__ipoFontBoldDataURL}");}`);

    out.push(`:root{--ipo-font:${px}px;}`);
    out.push(`.ipo-hide{display:none!important;}`);

    // R1/R2: dimensione, font, spaziatura
    out.push(`body{font-size:var(--ipo-font)!important;}`);
    // :where = specificità zero, così h1-h6 e i figli dei titoli possono sovrascrivere
    out.push(`:where(${TEXT_TAGS}){font-size:var(--ipo-font)!important;transition:font-size 150ms ease-out!important;}`);
    out.push(`h1{font-size:calc(var(--ipo-font) * 1.6)!important;}h2{font-size:calc(var(--ipo-font) * 1.4)!important;}h3{font-size:calc(var(--ipo-font) * 1.2)!important;}h4,h5,h6{font-size:calc(var(--ipo-font) * 1.1)!important;}`);
    out.push(`:is(h1,h2,h3,h4,h5,h6) :is(span,a,label,div,small,strong,em,b,i){font-size:inherit!important;}`);
    out.push(`:is(body,${TEXT_TAGS})${NOT_ICON}{font-family:${fam}!important;}`);
    out.push(`:is(body,${TEXT_TAGS}){line-height:${lh}!important;letter-spacing:${ls}em!important;word-spacing:${ws}em!important;}`);
    out.push(`:is(body,p,li,dd,dt,td,th,blockquote,figcaption,div.ipo-t,h1,h2,h3,h4,h5,h6){text-align:${align}!important;}`);
    out.push(`p,blockquote{margin-bottom:${ps}em!important;}`);

    // Layout a una colonna
    if (S.reader) {
      out.push(`body{display:block!important;margin:0!important;padding:0!important;max-width:none!important;}`);
      out.push(`#ipoview-reader{display:block!important;max-width:${W}px!important;margin:0 auto!important;padding:12px!important;box-sizing:border-box!important;overflow-wrap:break-word;}`);
      out.push(`#ipoview-reader img,#ipoview-reader video,#ipoview-reader figure{max-width:100%!important;height:auto!important;}`);
      out.push(`#ipoview-reader table{display:block!important;overflow-x:auto!important;max-width:100%!important;}`);
    } else if (l.singleColumn) {
      out.push(`html,body{overflow-x:hidden!important;}`);
      out.push(`body{display:block!important;max-width:${W}px!important;margin:0 auto!important;padding:12px!important;box-sizing:border-box!important;overflow-wrap:break-word;}`);
      out.push(`body *{float:none!important;max-width:100%!important;box-sizing:border-box!important;}`);
      out.push(`body *:not(img):not(svg):not(svg *):not(video):not(canvas):not(iframe):not(input):not(select):not(button):not(picture){width:auto!important;min-width:0!important;}`);
      out.push(`.ipo-flexcol{flex-direction:column!important;flex-wrap:wrap!important;}.ipo-grid{display:block!important;}`);
      out.push(`img,video,picture,canvas,iframe{max-width:100%!important;height:auto!important;}`);
      out.push(`table{display:block!important;overflow-x:auto!important;}`);
      out.push(`aside,footer,[role="complementary"],[role="contentinfo"]{display:none!important;}`);
    }
    if (!S.reader && ruleMode) out.push(`${AD_SEL}{display:none!important;}`);

    // Spazio in fondo: la toolbar nativa iOS copre circa 90px della webview
    out.push(`body{padding-bottom:calc(100px + env(safe-area-inset-bottom))!important;}`);

    // Sblocca lo scroll bloccato dai popup
    if (l.moveEdgeElements || cl.removeCookieBanners) out.push(`html,body{overflow-y:auto!important;height:auto!important;}`);

    // R3/R4: tema
    if (tc.theme === 'scuro' || tc.theme === 'chiaro') {
      out.push(`html,body{background:${BG}!important;color:${FG}!important;}`);
      out.push(`body *{color:${FG}!important;border-color:${tc.bgIsDark ? '#555' : '#999'};}`);
      out.push(`a,a *{color:${tc.link}!important;}`);
    }
    const bright = num(c.imageBrightness, 1);
    if (bright !== 1) out.push(`img,video,picture,canvas{filter:brightness(${bright})!important;}`);

    // R6: niente animazioni (resta solo la nostra transizione della dimensione)
    if (cl.stopAnimations) out.push(`*,*::before,*::after{animation:none!important;transition-property:font-size!important;scroll-behavior:auto!important;}`);

    // R7: link e controlli
    if (k.underlineLinks) out.push(`a{text-decoration:underline!important;text-underline-offset:.15em!important;}`);
    out.push(`button,select,input:not([type="checkbox"]):not([type="radio"]):not([type="hidden"]),[role="button"],nav a{min-height:${target}px!important;min-width:${target}px!important;padding:.3em .6em!important;box-sizing:border-box!important;}`);
    out.push(`nav a{display:inline-block!important;}`);
    out.push(`p a,li a{padding-block:.15em!important;}`);
    out.push(`input[type="checkbox"],input[type="radio"]{width:${Math.round(target * 0.6)}px!important;height:${Math.round(target * 0.6)}px!important;}`);
    out.push(`:focus,:focus-visible{outline:${outline}px solid ${tc.focus}!important;outline-offset:2px!important;}`);

    // Nostri controlli (Menù, paragrafo)
    const btnFont = 'clamp(20px, calc(var(--ipo-font) * 0.8), 40px)';  // solo per il pulsante Menù
    out.push(`#ipoview-menu-btn{display:block!important;width:100%!important;max-width:none!important;min-height:${Math.max(64, target)}px!important;margin:0 0 12px!important;padding:8px 16px!important;font:700 ${btnFont} ${fam}!important;background:${FG}!important;color:${BG}!important;border:3px solid ${FG}!important;border-radius:12px!important;position:static!important;text-decoration:none!important;}`);
    out.push(`#ipoview-paragraph{position:fixed!important;inset:0!important;z-index:2147483647!important;display:flex!important;flex-direction:column!important;background:${BG}!important;color:${FG}!important;margin:0!important;padding:0!important;max-width:none!important;width:auto!important;font-family:${fam}!important;}`);
    out.push(`#ipoview-paragraph .ipo-p-text{flex:1 1 auto!important;min-height:0!important;overflow-y:auto!important;padding:24px 16px!important;margin:0!important;color:${FG}!important;background:${BG}!important;font-size:var(--ipo-font)!important;line-height:${lh}!important;letter-spacing:${ls}em!important;word-spacing:${ws}em!important;text-align:left!important;-webkit-overflow-scrolling:touch;overflow-wrap:break-word!important;word-break:normal!important;hyphens:auto!important;-webkit-hyphens:auto!important;}`);
    out.push(`#ipoview-paragraph .ipo-p-text.ipo-h{font-weight:700!important;font-size:calc(var(--ipo-font) * 1.3)!important;}`);
    out.push(`#ipoview-paragraph .ipo-p-text.ipo-speaking{box-shadow:inset 0 0 0 ${outline + 2}px ${tc.focus}!important;}`);
    // Barra in basso a dimensione fissa: non segue --ipo-font (a 85px andrebbe a capo)
    out.push(`#ipoview-paragraph .ipo-p-bottom{flex:0 0 auto!important;background:${BG}!important;padding:8px 8px calc(env(safe-area-inset-bottom) + 90px)!important;border-top:2px solid ${FG}!important;}`);
    out.push(`#ipoview-paragraph .ipo-p-count{text-align:center!important;padding:4px 0 8px!important;color:${FG}!important;background:${BG}!important;font-size:24px!important;font-weight:700!important;line-height:1.2!important;letter-spacing:normal!important;word-spacing:normal!important;white-space:nowrap!important;}`);
    out.push(`#ipoview-paragraph .ipo-p-bar{display:flex!important;gap:8px!important;background:${BG}!important;}`);
    out.push(`#ipoview-paragraph .ipo-p-btn{flex:1 1 50%!important;min-height:72px!important;min-width:0!important;width:auto!important;padding:8px!important;margin:0!important;font-family:${fam}!important;font-size:24px!important;font-weight:700!important;line-height:1.2!important;letter-spacing:normal!important;word-spacing:normal!important;white-space:nowrap!important;background:${FG}!important;color:${BG}!important;border:none!important;border-radius:12px!important;text-decoration:none!important;overflow:hidden!important;text-overflow:clip!important;}`);
    out.push(`#ipoview-paragraph .ipo-p-btn:disabled{opacity:.35!important;}`);
    out.push(`html.ipo-lock,html.ipo-lock body{overflow:hidden!important;}`);
    return out.join('\n');
  }

  function injectStyle(css) {
    let st = document.getElementById(STYLE_ID);
    if (!st) {
      st = document.createElement('style'); st.id = STYLE_ID; st.setAttribute('data-ipoview', 'style');
      (document.head || document.documentElement).appendChild(st);
      track(st);
    }
    st.textContent = css;
  }

  // ---------------------------------------------------------------------------
  // R8: Readability (modalità lettura)
  // ---------------------------------------------------------------------------
  function tryReader(plan) {
    if (!(plan.cleanup && plan.cleanup.useReadability) || !document.body) return false;
    if (typeof Readability !== 'function') return false;
    if (typeof isProbablyReaderable === 'function' && !isProbablyReaderable(document)) return false;
    const article = new Readability(document.cloneNode(true)).parse();
    if (!article || !article.content || (article.textContent || '').trim().length < 200) return false;

    const box = document.createElement('div');
    box.id = 'ipoview-reader'; box.setAttribute('data-ipoview', 'reader');
    const h1 = document.createElement('h1'); h1.textContent = article.title || document.title || '';
    box.appendChild(h1);
    if (article.byline) { const by = document.createElement('p'); by.className = 'ipo-byline'; by.textContent = article.byline; box.appendChild(by); }
    const content = document.createElement('div'); content.className = 'ipo-content';
    content.innerHTML = article.content;
    box.appendChild(content);
    // Nasconde (senza cancellare) tutto il resto
    for (const ch of Array.from(document.body.children)) if (!isOurs(ch)) hide(ch);
    document.body.insertBefore(box, document.body.firstChild);
    track(box);
    return true;
  }

  // ---------------------------------------------------------------------------
  // R5/R6: banner cookie, popup, barre fisse
  // ---------------------------------------------------------------------------
  function hideCookies(root) {
    const list = [];
    if (root.nodeType === 1 && root.matches && root.matches(COOKIE_SEL)) list.push(root);
    if (root.querySelectorAll) list.push(...root.querySelectorAll(COOKIE_SEL));
    for (const el of list) {
      if (isOurs(el) || el === document.body || el === document.documentElement || containsMain(el)) continue;
      hide(el);
    }
  }
  function handleEdge(el, cs) {
    if (el === document.body || el === document.documentElement || isOurs(el)) return;
    const sig = signature(el);
    const role = el.getAttribute('role');
    let overlay = COOKIE_RE.test(sig) || el.getAttribute('aria-modal') === 'true' || role === 'dialog' || role === 'alertdialog';
    if (!overlay && cs.position === 'fixed') {
      const r = el.getBoundingClientRect();
      overlay = r.width * r.height > 0.5 * window.innerWidth * window.innerHeight;  // velo a tutto schermo
    }
    if (overlay && !containsMain(el)) hide(el);
    else setStyle(el, 'position', 'static');   // barre fisse rimesse nel flusso
  }
  function unlockScroll() {
    for (const el of [document.documentElement, document.body]) {
      if (!el) continue;
      const cs = getComputedStyle(el);
      if (cs.position === 'fixed') { setStyle(el, 'position', 'static'); setStyle(el, 'top', 'auto'); }
    }
  }

  // ---------------------------------------------------------------------------
  // Scansione: barre fisse, flex/grid, sfondi del tema, div con testo
  // ---------------------------------------------------------------------------
  function scanElements(root, plan) {
    if (!root) return;
    const l = plan.layout || {}, cl = plan.cleanup || {};
    const edges = !S.reader && (l.moveEdgeElements || cl.removeCookieBanners);
    const single = !S.reader && l.singleColumn;
    const tc = themeColors(plan);
    const themed = tc.theme === 'scuro' || tc.theme === 'chiaro';
    const BG = cssColor(tc.bg);
    for (const el of collect(root, 8000)) {
      if (el.nodeType !== 1 || SKIP_TAGS.has(el.tagName) || isUI(el)) continue;
      if (el.classList.contains('ipo-hide')) continue;
      let cs; try { cs = getComputedStyle(el); } catch (e) { continue; }
      if (cs.display === 'none') continue;
      if (edges && (cs.position === 'fixed' || cs.position === 'sticky')) handleEdge(el, cs);
      if (single) {
        if (cs.display.includes('flex') && !cs.flexDirection.startsWith('column')) addClass(el, 'ipo-flexcol');
        else if (cs.display.includes('grid')) addClass(el, 'ipo-grid');
      }
      if (themed && el !== document.body && parseColor(cs.backgroundColor).a > 0 && !/^(IMG|VIDEO|CANVAS|PICTURE)$/.test(el.tagName)) {
        setStyle(el, 'background-color', /^(BUTTON|INPUT|SELECT|TEXTAREA)$/.test(el.tagName) ? tc.control : BG);
      }
      if (el.tagName === 'DIV' && hasDirectText(el)) addClass(el, 'ipo-t');
    }
  }

  // ---------------------------------------------------------------------------
  // R3: passata di contrasto
  // ---------------------------------------------------------------------------
  function contrastPass(root, plan) {
    if (!root) return;
    const c = plan.color || {};
    const target = num(c.minTextContrast, 4.5), uiTarget = num(c.minUIContrast, 3);
    const preserveHue = c.preserveHue !== false;
    const tc = themeColors(plan);
    const cache = new Map();
    const docEl = document.documentElement;

    // Sfondo effettivo: risale i genitori componendo gli sfondi semitrasparenti
    function effBg(n) {
      if (!n || n.nodeType !== 1) return { c: WHITE, image: false };
      if (cache.has(n)) return cache.get(n);
      const cs = getComputedStyle(n);
      let res;
      if (n !== docEl && n !== document.body && cs.backgroundImage && cs.backgroundImage !== 'none') res = { c: WHITE, image: true };
      else {
        const own = parseColor(cs.backgroundColor);
        if (own.a >= 0.99) res = { c: own, image: false };
        else {
          const p = effBg(n.parentElement);
          res = own.a > 0 ? { c: blend(own, p.c), image: p.image } : p;
        }
      }
      cache.set(n, res);
      return res;
    }

    let count = 0;
    for (const el of collect(root, 20000)) {
      if (count >= 3000) break;
      if (el.nodeType !== 1 || SKIP_TAGS.has(el.tagName) || isUI(el)) continue;
      const isControl = /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(el.tagName);
      const text = hasDirectText(el);
      if (!text && !isControl) continue;
      if (!visible(el)) continue;
      count++;
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden') continue;

      // Bordi dei controlli: almeno minUIContrast rispetto allo sfondo esterno
      if (isControl && !/^(hidden|checkbox|radio|range|color|image)$/.test(el.type || '')) {
        const outer = effBg(el.parentElement).c;
        const bw = parseFloat(cs.borderTopWidth) || 0;
        const bc = blend(parseColor(cs.borderTopColor), outer);
        if (bw < 1 || cs.borderTopStyle === 'none' || ratio(bc, outer) < uiTarget) {
          const nc = adjustColor(bw >= 1 ? bc : blend(parseColor(cs.color), outer), outer, uiTarget, preserveHue) ||
            (lum(outer) > MID_LUM ? BLACK : WHITE);
          setStyle(el, 'border', `2px solid ${cssColor(nc)}`);
        }
      }
      if (!text) continue;

      let info = effBg(el), bg = info.c;
      const fgRaw = parseColor(cs.color);
      if (info.image) {
        // Testo sopra un'immagine: fondo pieno dietro al testo
        let nb;
        if (tc.theme === 'originale') nb = ratio(blend(fgRaw, WHITE), WHITE) >= ratio(blend(fgRaw, DARK), DARK) ? WHITE : DARK;
        else nb = tc.bg;
        setStyle(el, 'background-color', cssColor(nb));
        setStyle(el, 'padding', '0.1em 0.25em');
        setStyle(el, 'box-decoration-break', 'clone');
        setStyle(el, '-webkit-box-decoration-break', 'clone');
        bg = nb; cache.set(el, { c: nb, image: false });
      }
      const fg = blend(fgRaw, bg);
      if (ratio(fg, bg) >= target) continue;
      let nc = adjustColor(fg, bg, target, preserveHue);
      if (!nc) {
        // Il solo testo non basta: cambia anche lo sfondo
        const nb = lum(bg) > MID_LUM ? WHITE : DARK;
        setStyle(el, 'background-color', cssColor(nb));
        cache.set(el, { c: nb, image: false });
        nc = adjustColor(fg, nb, target, preserveHue) || (lum(nb) > MID_LUM ? BLACK : WHITE);
        if (ratio(nc, nb) < target && lum(nb) <= MID_LUM) { setStyle(el, 'background-color', '#000'); nc = WHITE; }
      }
      setStyle(el, 'color', cssColor(nc));
    }
  }

  // ---------------------------------------------------------------------------
  // R6: media e marquee fermi
  // ---------------------------------------------------------------------------
  function stopMedia(root) {
    if (!root || !root.querySelectorAll) return;
    const list = Array.from(root.querySelectorAll('video,audio,marquee'));
    if (root.matches && root.matches('video,audio,marquee')) list.push(root);
    for (const m of list) {
      if (m.tagName === 'MARQUEE') { try { m.stop(); } catch (e) { /* */ } continue; }
      removeAttr(m, 'autoplay');
      try { m.pause(); } catch (e) { /* */ }
    }
  }

  // ---------------------------------------------------------------------------
  // R8: navigazione dentro un pulsante "Menù"
  // ---------------------------------------------------------------------------
  function buildMenu() {
    if (!document.body) return;
    const navs = Array.from(document.querySelectorAll('nav,[role="navigation"]'))
      .filter((n) => !isOurs(n) && !(n.parentElement && n.parentElement.closest('nav,[role="navigation"]')));
    if (!navs.length) return;
    navs.forEach(hide);
    const btn = document.createElement('button');
    btn.type = 'button'; btn.id = 'ipoview-menu-btn'; btn.textContent = 'Menù';
    btn.setAttribute('data-ipoview', 'ui'); btn.setAttribute('aria-expanded', 'false');
    btn.addEventListener('click', () => {
      const open = btn.getAttribute('aria-expanded') !== 'true';
      btn.setAttribute('aria-expanded', String(open));
      navs.forEach((n) => n.classList.toggle('ipo-hide', !open));
    });
    document.body.insertBefore(btn, document.body.firstChild);
    track(btn);
  }

  // ---------------------------------------------------------------------------
  // R5/R9: un paragrafo alla volta
  // ---------------------------------------------------------------------------
  const BLOCK_SEL = 'h1,h2,h3,h4,p,li,dd,blockquote,tr';
  const INNER_BLOCK_SEL = 'h1,h2,h3,h4,p,li,dd,blockquote,table';
  const EXCLUDE_SEL = ['nav', 'footer', 'aside', '[role="navigation"]', '[role="contentinfo"]', '[role="complementary"]',
    '.ipo-hide', '[data-ipoview="ui"]', 'script', 'style', 'noscript', 'template', AD_SEL, COOKIE_SEL].join(',');
  function cleanText(el) { return (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim(); }

  // Riga di tabella → "Partenza: 07:00 · Arrivo: 09:10 · …" (intestazioni dal thead se combaciano)
  function rowText(tr) {
    if (tr.parentElement && tr.parentElement.tagName === 'THEAD') return null;
    const cells = Array.from(tr.cells).map(cleanText);
    if (cells.filter(Boolean).length < 2) return null;
    const table = tr.closest('table');
    let heads = null;
    if (table && table.tHead && table.tHead.rows.length) {
      const hr = table.tHead.rows[table.tHead.rows.length - 1];
      if (hr.cells.length === cells.length) heads = Array.from(hr.cells).map(cleanText);
    }
    return cells.map((t, i) => (!t ? null : heads && heads[i] && heads[i] !== t ? `${heads[i]}: ${t}` : t))
      .filter(Boolean).join(' · ');
  }

  function collectParagraphs() {
    const reader = document.getElementById('ipoview-reader');
    const root = reader || document.body;
    const out = [];
    for (const el of root.querySelectorAll(BLOCK_SEL)) {
      if (out.length >= 2000) break;
      if (el.closest(EXCLUDE_SEL)) continue;
      // Niente doppioni: si prende il blocco più interno (una riga "dati" resta un blocco unico)
      if (el.querySelector(INNER_BLOCK_SEL)) continue;
      if (el.tagName !== 'TR' && el.parentElement && el.parentElement.closest('tr')) continue;
      if (!reader && (!visible(el) || getComputedStyle(el).visibility === 'hidden')) continue;
      if (el.tagName === 'TR') {
        const t = rowText(el);
        if (t) out.push({ text: t, isH: false });
        continue;
      }
      const text = cleanText(el);
      const isH = /^H[1-4]$/.test(el.tagName);
      if (!text || (!isH && text.length < 20)) continue;
      out.push({ text, isH });
    }
    return out;
  }

  function buildParagraphMode(plan) {
    const mode = plan.layout && plan.layout.mode;
    if ((mode !== 'paragrafo' && mode !== 'lettura-grande') || !document.body) return;
    const items = collectParagraphs();
    // Meno di 2 blocchi: niente overlay, resta la pagina adattata normale
    if (items.length < 2) { log('modalità paragrafo: blocchi insufficienti (' + items.length + '), layout normale'); return; }
    const speak = mode === 'lettura-grande' || !!(plan.speech && plan.speech.tapToSpeak);
    const rate = num(plan.speech && plan.speech.rateWpm, 160);

    const ov = document.createElement('div');
    ov.id = 'ipoview-paragraph'; ov.setAttribute('data-ipoview', 'ui');
    ov.setAttribute('lang', document.documentElement.lang || 'it'); ov.setAttribute('role', 'dialog'); ov.setAttribute('aria-label', 'Lettura un paragrafo alla volta');
    const text = document.createElement('div'); text.className = 'ipo-p-text'; text.setAttribute('aria-live', 'polite');
    const counter = document.createElement('div'); counter.className = 'ipo-p-count';
    const bar = document.createElement('div'); bar.className = 'ipo-p-bar';
    const prev = document.createElement('button'); prev.type = 'button'; prev.className = 'ipo-p-btn'; prev.textContent = '◀ Indietro';
    const next = document.createElement('button'); next.type = 'button'; next.className = 'ipo-p-btn'; next.textContent = 'Avanti ▶';
    bar.append(prev, next);
    const bottom = document.createElement('div'); bottom.className = 'ipo-p-bottom';
    bottom.append(counter, bar); ov.append(text, bottom);

    let i = 0;
    function show(n) {
      i = Math.max(0, Math.min(items.length - 1, n));
      text.textContent = items[i].text;
      text.classList.toggle('ipo-h', items[i].isH);
      text.classList.remove('ipo-speaking');
      text.scrollTop = 0;
      counter.textContent = `${i + 1} / ${items.length}`;
      prev.disabled = i === 0; next.disabled = i === items.length - 1;
    }
    prev.addEventListener('click', () => show(i - 1));
    next.addEventListener('click', () => show(i + 1));

    // Swipe sinistra/destra
    let sx = 0, sy = 0, swiped = false;
    ov.addEventListener('touchstart', (e) => { const t = e.changedTouches[0]; sx = t.clientX; sy = t.clientY; swiped = false; }, { passive: true });
    ov.addEventListener('touchend', (e) => {
      const t = e.changedTouches[0], dx = t.clientX - sx, dy = t.clientY - sy;
      if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 1.5) { swiped = true; show(dx < 0 ? i + 1 : i - 1); }
    }, { passive: true });
    // Tasti freccia (utile per i test su desktop)
    listen(document, 'keydown', (e) => {
      if (e.key === 'ArrowRight') show(i + 1);
      else if (e.key === 'ArrowLeft') show(i - 1);
    });
    // Tocco sul paragrafo = ascolto
    if (speak) {
      text.addEventListener('click', () => {
        if (swiped) { swiped = false; return; }
        text.classList.add('ipo-speaking');
        post({ type: 'speak', text: items[i].text, rateWpm: rate });
      });
    }

    document.body.appendChild(ov);
    track(ov);
    addClass(document.documentElement, 'ipo-lock');
    show(0);
  }

  // ---------------------------------------------------------------------------
  // MutationObserver: banner iniettati in ritardo
  // ---------------------------------------------------------------------------
  function startObserver() {
    if (!document.body || typeof MutationObserver !== 'function') return;
    S.observer = new MutationObserver((muts) => {
      for (const m of muts) for (const n of m.addedNodes) {
        if (n.nodeType === 1 && !isOurs(n) && S.pending.size < 500) S.pending.add(n);
      }
      if (S.pending.size) { clearTimeout(S.timer); S.timer = setTimeout(flushPending, 500); }
    });
    S.observer.observe(document.body, { childList: true, subtree: true });
  }

  function flushPending() {
    S.timer = null;
    if (!S.applied || !S.plan) { S.pending.clear(); return; }
    const plan = S.plan, cl = plan.cleanup || {}, l = plan.layout || {};
    const nodes = Array.from(S.pending).filter((n) => n.isConnected);
    S.pending.clear();
    for (const n of nodes) {
      step('observer', () => {
        if (S.reader && n.parentElement === document.body) { hide(n); return; }
        if (!S.reader && (cl.removeCookieBanners || l.moveEdgeElements)) hideCookies(n);
        if (cl.stopAnimations) stopMedia(n);
        scanElements(n, plan);
        contrastPass(n, plan);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // API pubblica
  // ---------------------------------------------------------------------------
  function apply(input) {
    let plan = input;
    if (typeof plan === 'string') { try { plan = JSON.parse(plan); } catch (e) { log('piano JSON non valido: ' + e.message); return; } }
    if (!plan || typeof plan !== 'object') { log('piano mancante'); return; }
    if (S.applied) reset();

    // Dimensione impostata prima di apply: ha la precedenza (poi si consuma)
    if (S.pendingFontPx != null) { plan = JSON.parse(JSON.stringify(plan)); plan.text = plan.text || {}; plan.text.fontSizePx = S.pendingFontPx; S.pendingFontPx = null; }
    S.plan = plan; S.applied = true;
    const cl = plan.cleanup || {}, l = plan.layout || {};
    const body = document.body;

    step('viewport', forceViewport);
    S.reader = !!step('readability', () => tryReader(plan));
    const ruleMode = !S.reader;
    step('style', () => injectStyle(buildCSS(plan, ruleMode)));
    if (body) {
      if (cl.stopAnimations) step('stopMedia', () => stopMedia(body));
      if (ruleMode && (cl.removeCookieBanners || l.moveEdgeElements)) {
        step('cookies', () => hideCookies(body));
        step('unlockScroll', unlockScroll);
      }
      if (ruleMode && l.singleColumn) step('menu', buildMenu);
      const root = S.reader ? document.getElementById('ipoview-reader') : body;
      step('scan', () => scanElements(root, plan));
      step('contrast', () => contrastPass(root, plan));
      step('paragraph', () => buildParagraphMode(plan));
      step('observer', startObserver);
    }
    post({ type: 'applied', readerable: S.reader });
  }

  function setFontSizePx(px) {
    const v = Number(px);
    if (!Number.isFinite(v) || v <= 0) return;
    if (!S.applied) { S.pendingFontPx = v; return; }
    // Solo la variabile CSS: nessuna nuova scansione
    step('setFontSizePx', () => setStyle(document.documentElement, '--ipo-font', v + 'px', ''));
  }

  function reset() {
    step('reset', () => {
      if (S.observer) { S.observer.disconnect(); S.observer = null; }
      clearTimeout(S.timer); S.timer = null; S.pending.clear();
      for (const [t, ev, fn, o] of S.listeners) t.removeEventListener(ev, fn, o);
      S.listeners = [];
      for (const n of S.added) if (n.parentNode) n.parentNode.removeChild(n);
      S.added = [];
      for (const [el, cls] of S.classes) {
        el.classList.remove(cls);
        if (el.getAttribute('class') === '') el.removeAttribute('class');
      }
      S.classes = [];
      S.inline.forEach((props, el) => {
        props.forEach(([val, prio], prop) => {
          if (val) el.style.setProperty(prop, val, prio); else el.style.removeProperty(prop);
        });
        if (el.getAttribute('style') === '') el.removeAttribute('style');
      });
      S.inline = new Map();
      for (const [el, name, val] of S.attrs) el.setAttribute(name, val);
      S.attrs = [];
      if (S.viewport) {
        const v = S.viewport;
        if (v.created) { if (v.meta.parentNode) v.meta.parentNode.removeChild(v.meta); }
        else if (v.content == null) v.meta.removeAttribute('content');
        else v.meta.setAttribute('content', v.content);
        S.viewport = null;
      }
    });
    S.applied = false; S.plan = null; S.reader = false;
  }

  window.IpoView = { apply, setFontSizePx, reset };
})();
