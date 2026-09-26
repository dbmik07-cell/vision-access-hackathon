# Vision Access Hackathon

Progetto hackathon dedicato all'accessibilita: app nativa iOS che funziona localmente sull'iPhone, con implementazioni Python di riferimento per verificare i modelli.

## Struttura e responsabilita

- `ios/`: Rocco, SwiftUI/Xcode, implementazione Swift e JavaScript per adattare le pagine dentro WKWebView.
- `backend/`: Michele, solo Python; riferimenti statistici, simulazioni e test.
  - `acuity/`, `contrast/`, `reading/`, `visual_field/`, `light/`, `adaptation/`, `simulation/`, `tests/`.
  - Il crowding rientra nella lettura, senza modulo autonomo.
- `shared/`: `visual-profile.schema.json`, `adaptation-plan.schema.json` e casi golden in `examples/`.
- `docs/`: specifiche e decisioni; `data-contracts.md` descrivera il contratto dati condiviso locale.
- `tests/`: cartella esistente preservata; i test Python dei modelli andranno in `backend/tests/`.
- `CLAUDE.md`: regole operative e confini di responsabilita.
- `CONTEXT.md`: stato operativo condiviso.

Non sono previsti server runtime, FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete.

## Stato e prossima fase

Sono presenti solo struttura, documentazione e segnaposto. Gli schemi JSON sono permissivi e non validano ancora dati applicativi; non ci sono casi golden, codice applicativo, progetto Xcode o test eseguibili. I file `.gitkeep` mantengono in Git le cartelle vuote.

MVP, test, modelli statistici e regole di adattamento saranno definiti con `/grill-with-docs`. Python e Swift useranno la stessa specifica e gli stessi casi golden, con seed deterministici dove necessari e confronti numerici basati su tolleranze concordate, non su uguaglianza esatta dei float.

## Collaborazione

Ogni persona lavora su un branch dedicato a una sola attivita, con integrazione su `main` tramite pull request. Finche il tracker non e disponibile, fa riferimento l'attivita concordata tra i collaboratori.

Concordare le modifiche condivise in [docs/data-contracts.md](docs/data-contracts.md), mantenendo coerenti schemi, esempi, [CLAUDE.md](CLAUDE.md) e [CONTEXT.md](CONTEXT.md).

## Confini finali di ownership

- `backend/` appartiene esclusivamente a Michele su Windows: solo Python per implementazioni statistiche di riferimento, modelli di acuita, contrasto, lettura, campo visivo e luce, regole di adattamento, simulazioni, validazione e test automatici. E un workspace di riferimento e validazione, non un server runtime.
- `ios/` appartiene a Rocco su Mac: Swift, SwiftUI, Xcode, test iOS, logica della distanza dal dispositivo, WKWebView e JavaScript di adattamento delle pagine.
- Michele lavora solo in `backend/`; Rocco lavora solo in `ios/`. Nessuno modifica l'area dell'altro salvo richiesta esplicita.
- `shared/` e il contratto comune: le modifiche agli schemi JSON e ai casi golden coinvolgono entrambi e devono preservare la compatibilita.
- Non aggiungere FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete. L'app finale funziona localmente sull'iPhone.
