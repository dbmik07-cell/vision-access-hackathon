# rules/mild-acuity

Tier 1. Acuita affidabile, contrasto normale, nessun blocco opzionale: verifica R1 con la formula di riserva e l'intera catena fino a `fontSizeCssPx`.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R0/R1: acuita `reliable`, limite prudente `ci95[1] = 0.5`; `s_target = 0.5 + 0.4 = 0.9`. `s_target = 0.9` -> x-height `h_x = 400 * 5' * 10^0.9 = 4.62121 mm` -> font `h_x / 0.496 = 9.31696 mm` -> `fontSizeCssPx = 56.24414208900257`.
- R3: `x = ci95[0] = 1.7 >= 1.65` -> `minTextContrast = 4.5`; `minUIContrast = max(3, 4.5 * 3 / 4.5) = 3`.
- R2: nessun `visualField` -> `maxLineWidthCh = 60`; nessun `amsler` -> spaziatura WCAG di base.
- R4: nessun blocco `light` -> tema `original`, `screen.brightness = null`, `imageBrightness = 1`.
- R7: `44 * 56.244 / 16 = 154.7` -> limitato a 64.
