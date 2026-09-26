# rules/low-contrast

Tier 1. Contrasto nella fascia 1.0-1.5: verifica l'interpolazione di R3.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R3: `x = ci95[0] = 1.2` (affidabile, nessuno spostamento) -> fascia `reduced` -> `12 - 10 * (1.2 - 1.0) = 10`.
- `minUIContrast = max(3, 10 * 3 / 4.5) = 6.6666667`.
- R1 come `mild-acuity`: `s_target = 0.9` -> x-height `h_x = 400 * 5' * 10^0.9 = 4.62121 mm` -> font `h_x / 0.496 = 9.31696 mm` -> `fontSizeCssPx = 56.24414208900257`.
