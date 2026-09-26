# rules/photophobia-no-preference

Tier 2. Fotofobia senza tema preferito ne luminosita: R4 sceglie il tema scuro e non tocca la luminosita.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R4: `preferredTheme` assente e `photophobia` vera -> tema `dark`, `imageBrightness = 0.85`; `preferredBrightness` assente -> `screen.brightness = null`.
