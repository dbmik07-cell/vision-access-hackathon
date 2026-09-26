# rules/central-loss

Tier 1. Blocco preset di Amsler con coinvolgimento centrale in un solo occhio: verifica la spaziatura aumentata di R2.

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R2: `centralInvolved` vero nell'occhio destro (basta un occhio) -> `lineHeight 2`, `letterSpacingEm 0.18`, `wordSpacingEm 0.24`, `paragraphSpacingEm` resta 2.
- R1 come `mild-acuity`: `s_target = 0.9` -> x-height `h_x = 400 * 5' * 10^0.9 = 4.62121 mm` -> font `h_x / 0.496 = 9.31696 mm` -> `fontSizeCssPx = 56.24414208900257`.
