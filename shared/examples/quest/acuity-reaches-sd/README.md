# quest/acuity-reaches-sd

Tier 1. Acuita con osservatore deterministico (corretta se e solo se `x >= 0.51`, soglia fuori griglia per evitare uguaglianze) e stimoli ammissibili di `geometry/admissible-acuity-stimuli` caso 1 (indici 14...105).

## Stato

Gli output attesi per passo sono `pending`: li genera l'implementazione di riferimento Python solo dopo aver superato `tiny-hand-computed` e i controlli sotto; poi il file si aggiorna con `status: final` in una PR condivisa.

## Oracolo manuale (controlli di plausibilita)

- Le risposte sono coerenti con una soglia tra 0.50 e 0.52: la mediana finale deve cadere in [0.46, 0.56].
- Deve fermarsi per SD < 0.05 con `12 <= n < 30` (nessun `maxTrialsReached`).
- `ci95` deve contenere 0.51; larghezza <= 0.30 -> `reliable`.
