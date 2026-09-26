# Vision Access Hackathon

Progetto hackathon dedicato all'accessibilita: app nativa iOS che funziona localmente sull'iPhone, con implementazioni Python di riferimento per verificare i modelli.

## Struttura e responsabilita

- `ios/`: Rocco, SwiftUI/Xcode, implementazione Swift e JavaScript per adattare le pagine dentro WKWebView.
- `backend/`: Michele, solo Python; riferimenti statistici, simulazioni e test.
  - `contract/`, `geometry/`, `quest/`, `acuity/`, `contrast/`, `adaptation/`, `tests/`; `reading/`, `visual_field/`, `light/` e `simulation/` sono ancora vuote.
  - Il crowding rientra nella lettura, senza modulo autonomo.
- `shared/`: schemi rigidi `visual-profile.schema.json` e `adaptation-plan.schema.json`, parametri concordati in `parameters.json`, tabella dei dispositivi `devices.json` e casi golden in `examples/`.
- `docs/`: `data-contracts.md` (contratto MVP normativo), `spec/` (specifica originale), `research/` (verifica statistica delle fonti), `adr/` (decisioni architetturali), `agents/` (configurazione degli agenti: tracker, etichette, documenti di dominio).
- `tests/`: cartella esistente preservata; i test Python dei modelli sono in `backend/tests/`.
- `CLAUDE.md`: regole operative e confini di responsabilita.
- `CONTEXT.md`: stato operativo condiviso e glossario del dominio.

Non sono previsti server runtime, FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete.

## Stato e prossima fase

Il contratto MVP (distanza, acuita, contrasto, `VisualProfile` -> `AdaptationPlan` -> browser adattato) e definito e approvato in [docs/data-contracts.md](docs/data-contracts.md), con schemi, parametri e casi golden tier 1+2 in `shared/`. I file `.gitkeep` mantengono in Git le cartelle vuote.

- `backend/`: implementazione di riferimento Python, non un backend di runtime dell'app (geometria, derivazioni del profilo, regole R0-R8, motore QUEST+ e runner delle tracce, blocchi di acuita e contrasto misurati), verificata sui casi golden con `cd backend; python -m pytest` (istruzioni in [backend/README.md](backend/README.md)).
- `ios/`: app SwiftUI `ios/hackaton.xcodeproj` con test in `ios/hackatonTests/` (`xcodebuild test`), che leggono gli stessi casi golden.

Il confronto tra Python e Swift usa tracce scriptate (non seed condivisi) e le tolleranze di `shared/parameters.json`, mai l'uguaglianza esatta dei float. Tutte le tracce QUEST+ in `shared/examples/quest/`, comprese `acuity-reaches-sd`, `acuity-max-trials` e `contrast-reaches-sd`, sono congelate (`final`) e la suite Python le verifica passo per passo. La validazione completa della parita Swift/Xcode su queste tracce e ancora da fare (issue #14 aperta). Prossima fase: quella validazione su Mac, poi le simulazioni Python.

## Collaborazione

Ogni persona lavora su un branch dedicato a una sola attivita, con integrazione su `main` tramite pull request. Le attivita sono tracciate nelle GitHub Issues del repository (`docs/agents/issue-tracker.md`).

Concordare le modifiche condivise in [docs/data-contracts.md](docs/data-contracts.md), mantenendo coerenti schemi, esempi, [CLAUDE.md](CLAUDE.md) e [CONTEXT.md](CONTEXT.md).

## Confini finali di ownership

- `backend/` appartiene esclusivamente a Michele su Windows: solo Python per implementazioni statistiche di riferimento, modelli di acuita, contrasto, lettura, campo visivo e luce, regole di adattamento, simulazioni, validazione e test automatici. E un workspace di riferimento e validazione, non un server runtime.
- `ios/` appartiene a Rocco su Mac: Swift, SwiftUI, Xcode, test iOS, logica della distanza dal dispositivo, WKWebView e JavaScript di adattamento delle pagine.
- Michele lavora solo in `backend/`; Rocco lavora solo in `ios/`. Nessuno modifica l'area dell'altro salvo richiesta esplicita.
- `shared/` e il contratto comune: le modifiche agli schemi JSON e ai casi golden coinvolgono entrambi e devono preservare la compatibilita.
- Non aggiungere FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete. L'app finale funziona localmente sull'iPhone.
