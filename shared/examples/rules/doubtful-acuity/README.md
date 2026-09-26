# rules/doubtful-acuity

Tier 1. Come `mild-acuity` ma con acuita `doubtful` (larghezza di `ci95` 0.35 > 0.30) e stesso limite superiore: la dimensione deve risultare esattamente 0.1 logMAR piu grande (R0).

## Oracolo manuale

Costanti (da `shared/parameters.json`): `r_x = 0.496`, `zeroWidthEm = 0.648`, 5' = 0.00145444104 rad.
Contesto: 400 mm, 460 ppi, `nativeScale` 3, quindi 1 mm = 460 / (25.4 * 3) = 6.0367454 CSS px.

- R0/R1: `s_target = 0.5 + 0.4 + 0.1 = 1.0`. `s_target = 1.0` -> x-height `h_x = 400 * 5' * 10^1.0 = 5.81776 mm` -> font `h_x / 0.496 = 11.72936 mm` -> `fontSizeCssPx = 70.80717974040722`.
- Rapporto con `mild-acuity`: `70.807 / 56.244 = 1.2589 = 10^0.1`.
- Tutto il resto come `mild-acuity`.
