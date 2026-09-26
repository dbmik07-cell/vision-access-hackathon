# Contratto AdaptationPlan → adapter.js

Il piano è JSON (Swift `AdaptationPlan` codificato con JSONEncoder, chiavi camelCase).
Solo numeri pronti: adapter.js non fa scienza della vista.

```json
{
  "text": {
    "fontFamily": "Atkinson Hyperlegible",
    "fontSizePx": 24.0,
    "lineHeight": 1.5,
    "letterSpacingEm": 0.12,
    "wordSpacingEm": 0.16,
    "paragraphSpacingEm": 2.0,
    "align": "left"
  },
  "layout": {
    "singleColumn": true,
    "maxLineWidthPx": 340,
    "mode": "normale",
    "moveEdgeElements": false
  },
  "color": {
    "theme": "originale",
    "background": "#FFFDF7",
    "text": "#1A1A1A",
    "minTextContrast": 7.0,
    "minUIContrast": 3.0,
    "preserveHue": true,
    "imageBrightness": 1.0
  },
  "controls": {
    "underlineLinks": true,
    "minTargetPt": 44,
    "focusOutlinePx": 3
  },
  "cleanup": {
    "removeCookieBanners": true,
    "stopAnimations": true,
    "useReadability": false
  },
  "speech": {
    "tapToSpeak": false,
    "rateWpm": 160
  },
  "screen": {
    "brightness": 0.8
  }
}
```

- `layout.mode`: `"normale"` | `"paragrafo"` (un paragrafo per schermata, R5) | `"lettura-grande"` (R9: un paragrafo alla volta, tocco = ascolto).
- `color.theme`: `"originale"` (colori del sito, solo correzione contrasto R3) | `"chiaro"` | `"scuro"`.
- CSS px = punti iOS (la pagina viene forzata a `width=device-width, initial-scale=1`).
- Messaggi verso Swift: `window.webkit.messageHandlers.ipoview.postMessage({type: "speak", text, rateWpm})`,
  `{type: "log", message}`, `{type: "applied", readerable: bool}`.
- Il font è iniettato da Swift come `window.__ipoFontDataURL` (data: URL base64 del TTF regular) e
  `window.__ipoFontBoldDataURL` prima di `apply`.
