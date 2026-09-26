# rules/doubtful-contrast

Tier 2. Contrasto `doubtful`: lo spostamento prudente di R0 (-0.1 logCS) porta `x` esattamente sul bordo 1.0.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R0/R3: `x = 1.1 - 0.1 = 1.0` (in IEEE 754 il risultato e esattamente 1.0) -> fascia `reduced` (estremo inferiore incluso) -> `12 - 10 * 0 = 12`; `minUIContrast = 12 * 3 / 4.5 = 8`.
