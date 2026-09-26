# rules/low-contrast-photophobia

Tier 1. Contrasto ridotto piu blocco preset di luce con fotofobia e tema scuro preferito: verifica R4 insieme a R3.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R4: `preferredTheme = dark` -> tema scuro `#121212` / `#E8E6E3`; fotofobia -> `imageBrightness = 0.85`; `screen.brightness = preferredBrightness = 0.4`.
- R3 come `low-contrast`: `minTextContrast = 10`, `minUIContrast = 6.6666667`.
- R1 come `mild-acuity`: `s_target = 0.9` -> x-height `h_x = 400 * 5' * 10^0.9 = 4.62121 mm` -> font `h_x / 0.496 = 9.31696 mm` -> `fontSizeCssPx = 56.24414208900257`.
