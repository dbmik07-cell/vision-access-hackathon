# rules/tunnel-vision-10deg

Tier 2. Campo visivo preset con raggio 10 gradi: verifica la formula di `maxLineWidthCh` senza limitazione.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R1 come `mild-acuity`: `s_target = 0.9` -> x-height `h_x = 400 * 5' * 10^0.9 = 4.62121 mm` -> font `h_x / 0.496 = 9.31696 mm` -> `fontSizeCssPx = 56.24414208900257`.
- R2: `L_max = 2 * 400 * tan(10 deg) * 0.8 = 112.84927 mm`; `112.84927 / (9.31696 * 0.648) = 18.69172` caratteri, dentro [15, 60].
