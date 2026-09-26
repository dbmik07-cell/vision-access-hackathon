# Vision Access Hackathon

Progetto hackathon dedicato all'accessibilita: app nativa iOS che funziona localmente sull'iPhone, con implementazioni Python di riferimento per verificare i modelli.

## Struttura e responsabilita

- `ios/`: Rocco, SwiftUI/Xcode, implementazione Swift e JavaScript per adattare le pagine dentro WKWebView.
- `backend/`: Michele, solo Python; riferimenti statistici, simulazioni e test.
  - `acuity/`, `contrast/`, `reading/`, `visual_field/`, `light/`, `adaptation/`, `simulation/`, `tests/`.
  - Il crowding rientra nella lettura, senza modulo autonomo.
- `shared/`: schemi rigidi `visual-profile.schema.json` e `adaptation-plan.schema.json`, parametri concordati in `parameters.json`, tabella dei dispositivi `devices.json` e casi golden in `examples/`.
- `docs/`: `data-contracts.md` (contratto MVP normativo), `spec/` (specifica originale), `research/` (verifica statistica delle fonti), `adr/` (decisioni architetturali).
- `tests/`: cartella esistente preservata; i test Python dei modelli andranno in `backend/tests/`.
- `CLAUDE.md`: regole operative e confini di responsabilita.
- `CONTEXT.md`: stato operativo condiviso e glossario del dominio.

Non sono previsti server runtime, FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete.

## Stato e prossima fase

Il contratto MVP (distanza, acuita, contrasto, `VisualProfile` -> `AdaptationPlan` -> browser adattato) e definito e approvato in [docs/data-contracts.md](docs/data-contracts.md), con schemi, parametri e casi golden tier 1+2 in `shared/`. Non ci sono ancora codice applicativo, progetto Xcode o test eseguibili. I file `.gitkeep` mantengono in Git le cartelle vuote.

Prossima fase: implementazione di riferimento Python in `backend/` e app Swift in `ios/`, in parallelo dagli stessi casi golden. Il confronto usa tracce scriptate (non seed condivisi) e le tolleranze di `shared/parameters.json`, mai l'uguaglianza esatta dei float.

## Collaborazione

Ogni persona lavora su un branch dedicato a una sola attivita, con integrazione su `main` tramite pull request. Finche il tracker non e disponibile, fa riferimento l'attivita concordata tra i collaboratori.

Concordare le modifiche condivise in [docs/data-contracts.md](docs/data-contracts.md), mantenendo coerenti schemi, esempi, [CLAUDE.md](CLAUDE.md) e [CONTEXT.md](CONTEXT.md).

## Confini finali di ownership

- `backend/` appartiene esclusivamente a Michele su Windows: solo Python per implementazioni statistiche di riferimento, modelli di acuita, contrasto, lettura, campo visivo e luce, regole di adattamento, simulazioni, validazione e test automatici. E un workspace di riferimento e validazione, non un server runtime.
- `ios/` appartiene a Rocco su Mac: Swift, SwiftUI, Xcode, test iOS, logica della distanza dal dispositivo, WKWebView e JavaScript di adattamento delle pagine.
- Michele lavora solo in `backend/`; Rocco lavora solo in `ios/`. Nessuno modifica l'area dell'altro salvo richiesta esplicita.
- `shared/` e il contratto comune: le modifiche agli schemi JSON e ai casi golden coinvolgono entrambi e devono preservare la compatibilita.
- Non aggiungere FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete. L'app finale funziona localmente sull'iPhone.
