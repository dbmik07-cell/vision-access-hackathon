# Regole per Claude Code

## Ambito e responsabilita

Applicazione nativa iOS che deve funzionare localmente sull'iPhone. Il contratto MVP (test, modelli statistici, regole di adattamento, casi golden) e definito e approvato in `docs/data-contracts.md`, che prevale sulla specifica originale `docs/spec/ipoview-spec.md`.

- `ios/`: Rocco, app nativa SwiftUI/Xcode e implementazione Swift. Rocco possiede anche il JavaScript per l'adattamento delle pagine dentro WKWebView.
- `backend/`: Michele, esclusivamente Python per implementazioni statistiche di riferimento, simulazioni e test. E un workspace Python, non un server runtime dell'app.
- `shared/`: specifica JSON e casi di test golden condivisi, da concordare tra entrambi prima dell'implementazione.
- `docs/`: decisioni e specifiche condivise; `docs/data-contracts.md` rimane il punto di riferimento per il contratto dati locale, senza endpoint HTTP.
- `tests/`: cartella esistente mantenuta; i test Python dei modelli appartengono a `backend/tests/`.
- Non introdurre server runtime, FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete.
- Il crowding e coperto dal test di lettura in `backend/reading/`; non creare un modulo o test autonomo `crowding/`.
- Non inventare modelli statistici: implementa solo cio che il contratto definisce. Le funzionalita post-MVP richiedono prima un aggiornamento del contratto.

## Collaborazione e Git

- Prima di modificare file, controlla il branch corrente e le modifiche locali. Non sovrascrivere o eliminare il lavoro altrui.
- Non sviluppare direttamente su `main`. Usa un branch dedicato a un solo ticket e integra tramite pull request.
- Se il tracker non e ancora disponibile, usa come riferimento l'attivita concordata con l'utente; non inventare numeri di ticket.
- Limita le modifiche ai file necessari per l'attivita. Evita refactoring, formattazioni globali e modifiche a moduli non correlati.
- Nella pull request descrivi cosa cambia e quali verifiche hai eseguito. Non effettuare merge con test falliti.
- Michele lavora solo in `backend/` e Rocco solo in `ios/`; nessuno modifica l'area dell'altro salvo richiesta esplicita. Le modifiche a `shared/` coinvolgono entrambi e devono preservare la compatibilita.
- Mantieni `CONTEXT.md` aggiornato con stato operativo e decisioni concordate, senza anticipare l'architettura dettagliata.

## Specifica condivisa e confronti numerici

- Python e Swift devono seguire la stessa specifica condivisa e gli stessi casi golden in `shared/examples/`.
- Prima di implementare, concorda e documenta il contratto in `docs/data-contracts.md` e negli schemi in `shared/`.
- Gli schemi in `shared/` sono rigidi (`additionalProperties: false`) e versionati; tutti i parametri numerici stanno in `shared/parameters.json` e non si ricopiano nel codice. Non inventare campi, unita, soglie o valori golden.
- I test adattivi si confrontano tra Python e Swift con tracce scriptate, non con seed condivisi (ADR 0001); il seed serve solo nelle simulazioni Python.
- Confronta i risultati numerici con le tolleranze di `shared/parameters.json`, mai con uguaglianza esatta dei float; i campi discreti si confrontano in modo esatto.
- Coordina ogni variazione del contratto con entrambi gli sviluppatori; aggiorna specifica, casi golden e implementazioni interessate senza incompatibilita silenziose.

## Qualita e semplicita

- Preferisci la soluzione piu semplice che soddisfa il ticket e mantieni le dipendenze al minimo.
- Dopo modifiche significative, esegui i test pertinenti e gli eventuali controlli gia configurati. Aggiungi o aggiorna test quando cambia il comportamento applicativo.
- Se test o comandi non esistono ancora, oppure non puoi eseguirli, dichiaralo: non riportarli come superati.
- Non inserire password, token o file `.env` nei commit. Documenta le eventuali variabili necessarie in un `.env.example` senza valori segreti.

## Confini finali di ownership

- `backend/` appartiene esclusivamente a Michele su Windows: solo Python per implementazioni statistiche di riferimento, modelli di acuita, contrasto, lettura, campo visivo e luce, regole di adattamento, simulazioni, validazione e test automatici. E un workspace di riferimento e validazione, non un server runtime.
- `ios/` appartiene a Rocco su Mac: Swift, SwiftUI, Xcode, test iOS, logica della distanza dal dispositivo, WKWebView e JavaScript di adattamento delle pagine.
- Michele lavora solo in `backend/`; Rocco lavora solo in `ios/`. Nessuno modifica l'area dell'altro salvo richiesta esplicita.
- `shared/` e il contratto comune: le modifiche agli schemi JSON e ai casi golden coinvolgono entrambi e devono preservare la compatibilita.
- Non aggiungere FastAPI, database, API Anthropic, RAG, database vettoriali o dipendenze di rete. L'app finale funziona localmente sull'iPhone.

## Agent skills

### Issue tracker

Le issue sono tracciate nelle GitHub Issues di `dbmik07-cell/vision-access-hackathon`, tramite CLI `gh`. Vedi `docs/agents/issue-tracker.md`.

### Triage labels

Si usano le cinque etichette canoniche di default (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). Vedi `docs/agents/triage-labels.md`.

### Domain docs

Layout single-context: `CONTEXT.md` e `docs/adr/` nella root. Vedi `docs/agents/domain.md`.
