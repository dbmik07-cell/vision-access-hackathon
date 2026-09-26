# rules/contrast-edge-1-65

Tier 2. Limite prudente del contrasto esattamente sul bordo 1.65.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R3: `x = 1.65` -> fascia `normal` (>= 1.65) -> 4.5; `minUIContrast = 3`.
