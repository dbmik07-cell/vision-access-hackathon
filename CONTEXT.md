# Contesto operativo

## Stato

Repository predisposta con modifiche strutturali minime prima di `/grill-with-docs`. La precedente cartella `frontend/`, contenente solo `.gitkeep`, e stata rinominata in `ios/`. Il workspace Python preparato come `models` e stato normalizzato in `backend/`, preservandone tutti i contenuti. La cartella `tests/` esistente e stata preservata.

## Decisioni concordate

- Rocco: app locale iPhone in SwiftUI/Xcode, Swift e JavaScript di adattamento delle pagine in WKWebView, sotto `ios/`.
- Michele: esclusivamente Python sotto `backend/`, per riferimenti statistici, simulazioni e test.
- Specifica e casi golden comuni in `shared/`, documentati in `docs/data-contracts.md`.
- Crowding incluso nella lettura; nessun modulo autonomo.
- Nessun server runtime, FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete.
- Confronti Python/Swift con tolleranze concordate e seed deterministici dove necessari.

## Da definire

MVP, protocolli dei test, modelli statistici, campi degli schemi, casi golden e regole di adattamento durante `/grill-with-docs`. Nessuna funzionalita o architettura dettagliata e stata implementata. Non esistono ancora test eseguibili.

## Confini finali di ownership

- `backend/` appartiene esclusivamente a Michele su Windows: solo Python per implementazioni statistiche di riferimento, modelli di acuita, contrasto, lettura, campo visivo e luce, regole di adattamento, simulazioni, validazione e test automatici. E un workspace di riferimento e validazione, non un server runtime.
- `ios/` appartiene a Rocco su Mac: Swift, SwiftUI, Xcode, test iOS, logica della distanza dal dispositivo, WKWebView e JavaScript di adattamento delle pagine.
- Michele lavora solo in `backend/`; Rocco lavora solo in `ios/`. Nessuno modifica l'area dell'altro salvo richiesta esplicita.
- `shared/` e il contratto comune: le modifiche agli schemi JSON e ai casi golden coinvolgono entrambi e devono preservare la compatibilita.
- Non aggiungere FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete. L'app finale funziona localmente sull'iPhone.
