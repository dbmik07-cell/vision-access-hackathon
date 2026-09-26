# rules/near-normal

Tier 2. Vista nella norma con stima censurata al limite dello schermo: il piano si calcola comunque (nessun caso speciale) e verifica la formula di `minTargetPt` sotto il tetto.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- `normalVision = true` (0.05 < 0.3 e 1.75 >= 1.5) ma non cambia il piano (Q10).
- Mediana -0.05 < `displayLimitLogMAR` -0.02 -> `censoredAtDisplayLimit = true`; la censura non tocca R0, che usa il limite superiore.
- R1: `s_target = 0.05 + 0.4 = 0.45`. `s_target = 0.45` -> x-height `h_x = 400 * 5' * 10^0.45 = 1.63967 mm` -> font `h_x / 0.496 = 3.30578 mm` -> `fontSizeCssPx = 19.956174679133795`.
- R7: `44 * 19.95617 / 16 = 54.87948`, dentro [44, 64].
