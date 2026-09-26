# rules/contrast-edge-1-5

Tier 2. Limite prudente del contrasto esattamente sul bordo 1.5.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R3: `x = 1.5` -> fascia `borderline` (>= 1.5) -> 7; `minUIContrast = 7 * 3 / 4.5 = 4.6666667`.
