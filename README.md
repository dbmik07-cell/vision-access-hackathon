# Vision Access Hackathon

Progetto hackathon dedicato all'accessibilita, sviluppato da due persone con Claude Code come coding assistant.

## Struttura iniziale

- `frontend/`: frontend web.
- `backend/`: backend Python.
- `docs/`: documentazione e contratti API condivisi.
- `tests/`: test.

L'architettura applicativa e le tecnologie saranno definite successivamente con `/grill-with-docs` in Claude Code.

## Collaborazione

Ogni persona lavora su un branch dedicato a una sola attivita (ticket), con integrazione su `main` tramite pull request. Fino all'attivazione del tracker, fa riferimento l'attivita concordata tra i collaboratori.

Prima di collegare frontend e backend, concordare e documentare il relativo contratto in [docs/api-contract.md](docs/api-contract.md). Il file e gia presente come segnaposto: non definisce ancora endpoint o strutture JSON.

Questo README presenta il progetto ai collaboratori. [CLAUDE.md](CLAUDE.md) contiene le istruzioni operative per Claude Code, incluse le regole sui branch, sui contratti e sui test.

Non sono ancora presenti codice applicativo o test eseguibili. I file `.gitkeep` mantengono in Git le cartelle inizialmente vuote.
