# rules/tunnel-vision

Tier 1. Blocco preset di campo visivo con raggio 5 gradi (preset della demo): verifica `moveEdgeElements` e il limite minimo di `maxLineWidthCh`.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R1 come `mild-acuity`: `s_target = 0.9` -> x-height `h_x = 400 * 5' * 10^0.9 = 4.62121 mm` -> font `h_x / 0.496 = 9.31696 mm` -> `fontSizeCssPx = 56.24414208900257`.
- R2: `R = max(5, 5) = 5`; `L_max = 2 * 400 * tan(5 deg) * 0.8 = 55.99274 mm`; larghezza di un `ch` = `9.31696 * 0.648 = 6.03739 mm`; `55.99274 / 6.03739 = 9.274` caratteri -> limitato al minimo 15.
- R5: `pattern = tunnel` -> `moveEdgeElements = true`.
- Il preset non conta per `overallReliability` (resta `reliable`).
