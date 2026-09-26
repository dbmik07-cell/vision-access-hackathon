# rules/user-offset

Tier 2. Correzione manuale della dimensione: l'offset si somma per ultimo a `s_target`.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R1: `s_target = 0.5 + 0.4 + 0.2 = 1.1`. `s_target = 1.1` -> x-height `h_x = 400 * 5' * 10^1.1 = 7.32413 mm` -> font `h_x / 0.496 = 14.76639 mm` -> `fontSizeCssPx = 89.1409579126758`.
