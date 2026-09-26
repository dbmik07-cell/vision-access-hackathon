# Casi golden condivisi

Input e output attesi che Python (`backend/`) e Swift (`ios/`) devono riprodurre. Regole di confronto, tolleranze e significato dei campi: `docs/data-contracts.md` (sezioni 4 e 10). Ogni caso ha un `README.md` con l'oracolo manuale.

| Cartella | Verifica | File |
| --- | --- | --- |
| `rules/<caso>/` | profilo -> piano (R0-R8) | `profile.json`, `context.json`, `expected-plan.json` |
| `summary/<caso>/` | blocchi del profilo -> `summary`, categoria OMS, fascia di contrasto | `input.json`, `expected.json` |
| `geometry/<caso>/` | angolo -> CSS px, stimoli ammissibili, lettera del contrasto | `input.json`, `expected.json` |
| `quest/<caso>/` | motore QUEST+ passo per passo | `trace.json` |

## Tracce QUEST+ (`trace.json`)

- `engine`: configurazione del motore, esplicita oppure `{"fromParameters": "acuity" | "contrast"}` (griglie, `beta`, `gamma`, `lambda`, stop e `reliableMaxCiWidth` da `shared/parameters.json`).
- `stimuli`: lista esplicita oppure `{"fromParameters": ...}` (stessa griglia della soglia).
- `admissibleIndices`: indici degli stimoli ammissibili, costanti per tutta la traccia.
- `observer`:
  - `scripted`: `responses` fissate in ordine;
  - `deterministicThreshold`: risposta corretta se e solo se lo stimolo scelto `x >= thresholdX`, invertita nelle prove elencate in `invertTrials` (numerate da 1). Nessuna casualita.
- `expected.status`: `final` (golden congelato) oppure `pending` (output da generare con l'implementazione di riferimento dopo i controlli dell'oracolo).
- La traccia termina per stop del motore o quando le risposte scriptate sono esaurite (`endedBy`).

## Stato

Tier 1 e tier 2 presenti. Tracce `acuity-reaches-sd`, `acuity-max-trials`, `contrast-reaches-sd`: output `pending`.
