# Contesto operativo

## Stato

Contratto MVP approvato e file condivisi pronti in `shared/`. Prossimo passo: implementazione di riferimento Python in `backend/` (Michele) e app Swift in `ios/` (Rocco), in parallelo dagli stessi casi golden. La cartella `tests/` esistente e stata preservata.

## Decisioni concordate

- Rocco: app locale iPhone in SwiftUI/Xcode, Swift e JavaScript di adattamento delle pagine in WKWebView, sotto `ios/`.
- Michele: esclusivamente Python sotto `backend/`, per riferimenti statistici, simulazioni e test.
- Specifica e casi golden comuni in `shared/`, documentati in `docs/data-contracts.md`.
- Crowding incluso nella lettura; nessun modulo autonomo.
- Nessun server runtime, FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete.
- Confronti Python/Swift con tolleranze concordate e seed deterministici dove necessari.

- Contratto MVP `1.0` in `docs/data-contracts.md`, concordato con `/grill-with-docs` e approvato da Rocco il 2026-09-26; prevale sulla specifica `docs/spec/ipoview-spec.md`.
- File condivisi creati: schemi rigidi, `shared/parameters.json`, `shared/devices.json`, casi golden tier 1+2 in `shared/examples/`.

## Da definire

- Output per passo delle tracce QUEST+ `acuity-reaches-sd`, `acuity-max-trials`, `contrast-reaches-sd` (`pending`): si generano con l'implementazione di riferimento dopo `tiny-hand-computed`.
- Bianco caldo del tema chiaro (Rocco); verifica di `nativeScale` con lo Zoom schermo (Rocco).
- Protocolli e modelli dei test post-MVP (lettura, campo visivo, Amsler, luce, affidabilita avanzata).
- Backend: workspace Python, caricatore del contratto, validazione degli schemi e harness dei casi golden pronti (`cd backend; python -m pytest`, #6). I casi golden senza implementazione risultano `skipped` con il motivo; geometria (#7) e derivazioni del profilo (#8) implementate, goldens `geometry/` e `summary/` verdi; regole e QUEST+ non sono ancora implementati.

## Linguaggio

### Profilo e piano

**Profilo visivo funzionale**:
L'insieme dei risultati dei test di una persona, ciascuno con stima, intervallo al 95% e affidabilita; descrive come vede ai fini dell'interfaccia.
_Da evitare_: diagnosi, profilo medico, profilo clinico

**Piano di adattamento**:
I valori pronti che descrivono come trasformare pagine e interfaccia, derivati in modo deterministico dal profilo visivo funzionale.
_Da evitare_: impostazioni, configurazione

**Regola di adattamento**:
Una trasformazione esplicita (R0-R10) da un valore del profilo a una parte del piano.

**Blocco misurato**:
Parte del profilo prodotta da un test eseguito sulla persona.

**Blocco preset**:
Parte del profilo scritta a mano per dimostrare una regola; non conta per l'affidabilita complessiva.
_Da evitare_: dati finti, mock

**Distanza di riferimento**:
La distanza del viso alla quale il piano esprime le dimensioni; il browser le riscala con la distanza reale.

### Misura

**Soglia di acuita**:
La dimensione della lettera, in logMAR, a cui la persona risponde correttamente circa il 61,5% delle volte con la E in quattro direzioni.

**Sensibilita al contrasto**:
Il logaritmo dell'inverso del contrasto di Weber alla soglia (logCS).

**Intervallo al 95%**:
L'intervallo tra i quantili 2,5% e 97,5% della distribuzione a posteriori della soglia.
_Da evitare_: intervallo di confidenza, margine d'errore

**Limite prudente**:
L'estremo dell'intervallo al 95% che rende l'interfaccia piu leggibile: superiore per l'acuita, inferiore per il contrasto.
_Da evitare_: caso peggiore, limite inferiore

**Affidabilita**:
Il giudizio su un risultato: affidabile, dubbio o non affidabile.

**Risultato censurato**:
Un risultato la cui stima cade oltre cio che lo schermo puo mostrare; si riporta come "al massimo" o "almeno" il limite.
_Da evitare_: errore, fuori scala

**Limite dello schermo**:
La lettera piu piccola che il dispositivo puo mostrare correttamente alla distanza del test.

**Tetto del contrasto**:
Il contrasto piu debole che il dispositivo puo mostrare correttamente.

**Stimoli ammissibili**:
Gli stimoli che il dispositivo puo mostrare correttamente alla distanza del momento.

**Fascia di test**:
L'intervallo di distanza del viso in cui si svolgono i test di acuita e contrasto.

**Categoria OMS**:
La categoria ICD-11 dell'acuita: nessuna compromissione, lieve, moderata, grave, cecita.
_Da evitare_: normale (per la prima categoria), livello

**Fascia di contrasto**:
La classe della sensibilita al contrasto: normale, al limite, ridotta, molto ridotta.

**Vista nella norma**:
Acuita e contrasto fuori dalle fasce di compromissione con tutto l'intervallo, e nessun difetto nei blocchi opzionali; e un'informazione, non cambia il piano.
_Da evitare_: vista sana

**Coinvolgimento centrale**:
La presenza di zone distorte o mancanti nei 2 gradi centrali della griglia di Amsler.

**Raggio del campo**:
Il raggio in gradi, attorno al punto fissato, entro cui la sensibilita e sopra soglia.

### Verifica

**Implementazione di riferimento**:
Il codice Python che implementa la stessa specifica dell'app per verificarla; non e un server.
_Da evitare_: backend (nel senso di server)

**Caso golden**:
Un insieme condiviso di input e output attesi che entrambe le implementazioni devono riprodurre.

**Traccia scriptata**:
Un caso golden di un test adattivo con le risposte fissate in anticipo, senza casualita.

**Oracolo manuale**:
I valori chiave di un caso golden derivati a mano, indipendenti da entrambe le implementazioni.

**Deviazione dalla specifica**:
Una decisione che modifica la specifica originale ed e registrata nel contratto.

## Confini finali di ownership

- `backend/` appartiene esclusivamente a Michele su Windows: solo Python per implementazioni statistiche di riferimento, modelli di acuita, contrasto, lettura, campo visivo e luce, regole di adattamento, simulazioni, validazione e test automatici. E un workspace di riferimento e validazione, non un server runtime.
- `ios/` appartiene a Rocco su Mac: Swift, SwiftUI, Xcode, test iOS, logica della distanza dal dispositivo, WKWebView e JavaScript di adattamento delle pagine.
- Michele lavora solo in `backend/`; Rocco lavora solo in `ios/`. Nessuno modifica l'area dell'altro salvo richiesta esplicita.
- `shared/` e il contratto comune: le modifiche agli schemi JSON e ai casi golden coinvolgono entrambi e devono preservare la compatibilita.
- Non aggiungere FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete. L'app finale funziona localmente sull'iPhone.
