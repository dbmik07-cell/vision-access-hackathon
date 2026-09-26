# quest/acuity-max-trials

Tier 1. Come `acuity-reaches-sd`, ma la risposta e invertita nelle prove 3, 6, 9, ..., 30: risposte incoerenti che non devono permettere di raggiungere SD < 0.05.

## Stato

Gli output attesi per passo sono `pending`: li genera l'implementazione di riferimento Python solo dopo aver superato `tiny-hand-computed` e i controlli sotto; poi il file si aggiorna con `status: final` in una PR condivisa.

## Oracolo manuale (controlli di plausibilita)

- Deve arrivare a `n = 30` con flag `maxTrialsReached`.
- L'affidabilita dipende solo dalla larghezza di `ci95` (<= 0.30 `reliable`, altrimenti `doubtful` + `wideInterval`), non dal tetto di prove.
- Se l'esecuzione di riferimento si ferma prima di 30, le inversioni vanno riviste prima di congelare il golden.
