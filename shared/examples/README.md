# Casi golden condivisi

Input e output attesi che Python (`backend/`) e Swift (`ios/`) devono riprodurre. Regole di confronto, tolleranze e significato dei campi: `docs/data-contracts.md` (sezioni 4 e 10). Ogni caso ha un `README.md` con l'oracolo manuale.

| Cartella | Verifica | File |
| --- | --- | --- |
| `rules/<caso>/` | profilo -> piano (R0-R8) | `profile.json`, `context.json`, `expected-plan.json` |
| `summary/<caso>/` | blocchi del profilo -> `summary`, categoria OMS, fascia di contrasto | `input.json`, `expected.json` |
| `geometry/<caso>/` | angolo -> CSS px, stimoli ammissibili, lettera del contrasto | `input.json`, `expected.json` |
| `quest/<caso>/` | motore QUEST+ passo per passo | `trace.json` |

I formati di `trace.json`, `summary/` e `geometry/` non hanno uno schema JSON: sono definiti da questo file e dai casi presenti. Chiavi e lunghezze degli array si confrontano in modo esatto.

## Tracce QUEST+ (`trace.json`)

- `engine`: configurazione del motore, esplicita oppure `{"fromParameters": "acuity" | "contrast"}` (griglie, `beta`, `gamma`, `lambda`, stop e `reliableMaxCiWidth` da `shared/parameters.json`).
- `stimuli`: lista esplicita oppure `{"fromParameters": ...}` (stessa griglia della soglia).
- `admissibleIndices`: indici degli stimoli ammissibili, costanti per tutta la traccia.
- `observer`:
  - `scripted`: `responses` fissate in ordine;
  - `deterministicThreshold`: risposta corretta se e solo se lo stimolo scelto `x >= thresholdX`, invertita nelle prove elencate in `invertTrials` (numerate da 1). Nessuna casualita.
- `expected.status`: `final` (golden congelato) oppure `pending` (output da generare con l'implementazione di riferimento dopo i controlli dell'oracolo).
- La traccia termina per stop del motore o quando le risposte scriptate sono esaurite (`endedBy`).

### Output attesi (`expected`)

Tutti i valori sono nella variabile di facilita `x` del motore, anche per il contrasto: la conversione in logCS (`-t`, estremi di `ci95` scambiati) avviene solo quando si scrive il profilo, quindi non compare nella traccia.

`expected.steps`: un elemento per prova, in ordine.

| Campo | Significato |
| --- | --- |
| `trial` | numero della prova, da 1 |
| `expectedEntropy` | entropia attesa `E[H]` di ogni stimolo ammissibile, nell'ordine di `admissibleIndices` (stessa lunghezza) |
| `stimulusIndex` | indice dello stimolo scelto nella lista completa `stimuli`, non la posizione in `admissibleIndices` |
| `stimulus` | valore `x` dello stimolo scelto |
| `correct` | risposta dell'osservatore |
| `thresholdMarginal` | marginale della soglia dopo l'aggiornamento, un valore per punto della griglia di `t` |
| `mean`, `sd` | media e SD della marginale (solo regola di stop) |
| `median`, `ci95` | mediana e `[q_0.025, q_0.975]` con la convenzione a bin |
| `stop` | decisione di stop dopo questa prova |

`expected.final`:

| Campo | Significato |
| --- | --- |
| `trials` | numero di risposte |
| `endedBy` | `engineStop` (stop del motore: SD sotto il target con `n >= minTrials`, oppure `n = maxTrials`; il flag `maxTrialsReached` distingue il secondo caso) oppure `responsesExhausted` (risposte scriptate esaurite prima di uno stop) |
| `estimate`, `ci95` | mediana e `ci95` finali |
| `reliability`, `flags` | affidabilita dalla sola larghezza di `ci95`; flag `wideInterval`, `maxTrialsReached` in quest'ordine |

Entropia: `0 * ln 0 = 0` (limite matematico), cosi un posterior con zeri esatti non produce NaN.

## Stato

Tier 1 e tier 2 presenti. Tracce `tiny-hand-computed`, `acuity-reaches-sd`, `acuity-max-trials`, `contrast-reaches-sd`: `final` (le ultime tre congelate con l'issue #14).
