# quest/tiny-hand-computed

Tier 1. Un solo passo del motore QUEST+ su una griglia minima, calcolato a mano: verifica aggiornamento di Bayes, entropia attesa (logaritmo naturale), scelta dello stimolo, media, SD, quantili a bin con limitazione alla griglia. Non usa i parametri di acuita o contrasto: la configurazione e nel file.

## Oracolo manuale

Griglia `t = {0, 0.5, 1}`, `beta = 10`, prior 1/3 ciascuno; `P(c | x, t) = 0.25 + 0.73 / (1 + exp(-10 (x - t)))`.

- `x = 0.25`: `P(c|t) = 0.924624, 0.305376, 0.250404`; `p(c) = 0.493468`. Posterior se corretta `0.624575, 0.206279, 0.169145` (H = 0.920165); se sbagliata `0.049603, 0.457111, 0.493287` (H = 0.855421). `E[H] = 0.493468 * 0.920165 + 0.506532 * 0.855421 = 0.887370`.
- `x = 0.75`: `P(c|t) = 0.979596, 0.924624, 0.305376`; `p(c) = 0.736532`. Posterior se corretta `0.443337, 0.418458, 0.138205` (H = 0.998683); se sbagliata `0.025814, 0.095365, 0.878821` (H = 0.432030). `E[H] = 0.849388`.
- Minimo: `x = 0.75` (indice 1). Risposta scriptata: corretta.
- Marginale `0.443337, 0.418458, 0.138205`; media `0.5 * 0.418458 + 1 * 0.138205 = 0.347434`; SD `0.349441`.
- Quantili a bin (h = 0.5; bin `[-0.25, 0.25]`, `[0.25, 0.75]`, `[0.75, 1.25]`): q 0.025 nel primo bin `-0.25 + 0.5 * 0.025 / 0.443337 = -0.22180` -> limitato a 0; mediana nel secondo bin `0.25 + 0.5 * (0.5 - 0.443337) / 0.418458 = 0.317704`; q 0.975 nel terzo bin `0.75 + 0.5 * (0.975 - 0.861795) / 0.138205 = 1.15955` -> limitato a 1.
- `n = 1 < 12` -> nessuno stop; la traccia finisce perche le risposte scriptate sono esaurite. Larghezza `1.0 > 0.3` -> `doubtful`, `wideInterval`.
