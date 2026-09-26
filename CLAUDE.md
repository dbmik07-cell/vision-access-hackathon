# Regole per Claude Code

## Ambito

Progetto hackathon sviluppato da due persone, con frontend web e backend Python separati. L'architettura, i framework e i comandi di sviluppo saranno definiti con `/grill-with-docs`: non considerarli gia decisi.

## Collaborazione e Git

- Prima di modificare file, controlla il branch corrente e le modifiche locali. Non sovrascrivere o eliminare il lavoro altrui.
- Non sviluppare direttamente su `main`. Usa un branch dedicato a un solo ticket e integra tramite pull request.
- Se il tracker non e ancora disponibile, usa come riferimento l'attivita concordata con l'utente; non inventare numeri di ticket.
- Limita le modifiche ai file necessari per l'attivita. Evita refactoring, formattazioni globali e modifiche a moduli non correlati.
- Nella pull request descrivi cosa cambia e quali verifiche hai eseguito. Non effettuare merge con test falliti.

## Contratti tra frontend e backend

- Prima di implementare una comunicazione tra frontend e backend, definisci il relativo contratto in `docs/api-contract.md`: metodo e percorso, dati JSON di richiesta e risposta, campi obbligatori e risposte di errore.
- Frontend, backend ed eventuali mock devono rispettare lo stesso contratto.
- Se una modifica cambia un contratto esistente, coordinala con chi lavora sull'altra parte e aggiorna documento e implementazioni coinvolte. Non introdurre incompatibilita silenziose.

## Qualita e semplicita

- Preferisci la soluzione piu semplice che soddisfa il ticket e mantieni le dipendenze al minimo.
- Dopo modifiche significative, esegui i test pertinenti e gli eventuali controlli gia configurati. Aggiungi o aggiorna test quando cambia il comportamento applicativo.
- Se test o comandi non esistono ancora, oppure non puoi eseguirli, dichiaralo: non riportarli come superati.
- Non inserire password, token o file `.env` nei commit. Documenta le variabili necessarie in un `.env.example` senza valori segreti.
