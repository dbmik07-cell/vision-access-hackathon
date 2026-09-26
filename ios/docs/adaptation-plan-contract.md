# Contratto AdaptationPlan → adapter.js

**Normativo:** `docs/data-contracts.md`, sezioni 7 (geometria, viewport) e 9 (AdaptationPlan e regole MVP),
e `docs/adr/0003-piano-in-css-px-alla-distanza-di-riferimento.md`. Questo file è solo un riassunto per chi
lavora su `ios/hackaton/Resources/JS/adapter.js`; in caso di differenze vale `docs/data-contracts.md`.

Il piano è JSON (Swift `AdaptationPlan` codificato con JSONEncoder, chiavi camelCase), solo numeri pronti:
adapter.js non fa scienza della vista.

```json
{
  "schemaVersion": "1.0",
  "context": { "referenceDistanceMm": 400, "ppi": 460, "nativeScale": 3 },
  "text": { "fontFamily": "Atkinson Hyperlegible", "fontSizeCssPx": 22.4, "lineHeight": 1.5,
            "letterSpacingEm": 0.12, "wordSpacingEm": 0.16, "paragraphSpacingEm": 2, "align": "left" },
  "layout": { "singleColumn": true, "maxLineWidthCh": 60, "mode": "normal", "moveEdgeElements": false },
  "color": { "theme": "original", "background": null, "text": null, "minTextContrast": 4.5,
             "minUIContrast": 3, "preserveHue": true, "imageBrightness": 1 },
  "controls": { "underlineLinks": true, "minTargetPt": 44, "focusOutlinePx": 3 },
  "cleanup": { "removeCookieBanners": true, "stopAnimations": true, "useReadability": true },
  "speech": { "tapToSpeak": false, "rateWpm": null },
  "screen": { "brightness": null }
}
```

## Come lo usa adapter.js

- **Viewport:** prima di tutto forza `<meta name="viewport" content="width=device-width, initial-scale=1">`
  (1 CSS px = 1 punto iOS); `reset()` lo ripristina.
- **`text.fontSizeCssPx`** (alla distanza di riferimento di 400 mm) è la dimensione **minima** del corpo: il testo
  già più grande non viene ridotto (`font-size: max(var(--ipo-font), var(--ipo-orig))`, con `--ipo-orig` = dimensione
  calcolata originale registrata sull'elemento). Titoli: `max(--ipo-font × k, originale)`. Transizione 150 ms.
  A runtime Swift riscala per `d / 400` e chiama `IpoView.setFontSizePx(px)`, che aggiorna solo `--ipo-font`.
- **`layout.maxLineWidthCh`:** colonna di lettura `max-width: min(N ch, 100%)` (ch del font Atkinson), mai oltre lo
  schermo; parole lunghe spezzate con `overflow-wrap: break-word; hyphens: auto` (lingua di ripiego `it`), mai `break-all`.
- **`layout.singleColumn`:** sempre `true` con il piano attivo. **`layout.mode`:** `"normal"` nell'MVP (nessun overlay).
- **`color.theme`:** `"original"` (colori del sito, agisce solo la passata di contrasto R3; `background`/`text` = `null`),
  `"light"`, `"dark"` (usano `color.background`/`color.text`; con `null` si usano valori di ripiego).
  Contrasto con `minTextContrast`, `minUIContrast`, `preserveHue`.
- **`color.imageBrightness`:** `filter: brightness()` su immagini e video solo se diverso da 1.
- **`screen.brightness`:** gestita in Swift, ignorata da adapter.js.
- Alias accettati per compatibilità: temi `originale`/`chiaro`/`scuro`, modi `normale`/`paragrafo`/`lettura-grande`.

## Estensioni post-MVP di `layout.mode`

- `"paragraph"` (R5): un paragrafo per schermata, con Avanti/Indietro e swipe.
- `"large-reading"` (R9): come `"paragraph"`, e il tocco sul paragrafo lo fa leggere ad alta voce.

Nel tema `"original"` l'overlay usa sfondo bianco e testo `#1A1A1A`.

## Messaggi verso Swift

`window.webkit.messageHandlers.ipoview.postMessage(...)`:

- `{type: "applied", readerable: bool}` a fine `apply`;
- `{type: "speak", text, rateWpm}`: `rateWpm` è `null` se il piano lo lascia `null` (Swift sceglie il default);
- `{type: "log", message}` per errori non bloccanti.

Il font è iniettato da Swift come `window.__ipoFontDataURL` (data: URL base64 del TTF regular) e
`window.__ipoFontBoldDataURL` prima di `apply`.
