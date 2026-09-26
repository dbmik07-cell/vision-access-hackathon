# Intervallo a quantili e affidabilita per larghezza

La regola R0 costruisce l'interfaccia dall'estremo prudente dell'intervallo al 95%, quindi la sua definizione determina direttamente dimensione del testo e contrasto. Il posterior di QUEST+ e troncato al limite dello schermo e ai bordi della griglia, dove media +- 1,96 SD da un intervallo simmetrico che non lo riflette: per questo la stima pubblicata e la **mediana** e l'intervallo e dato dai **quantili 2,5% e 97,5%** della marginale sulla soglia, con CDF lineare a tratti (convenzione a bin) per restare riproducibile tra Python e Swift entro 1e-9. L'affidabilita dell'MVP dipende dalla **larghezza dell'intervallo** (<= 0,30) e non dal motivo dello stop: con le pendenze basse tipiche dell'ipovisione il target di SD non si raggiunge in 30 prove, e legare `doubtful` al tetto di prove avrebbe marcato come dubbi quasi tutti gli utenti a cui l'app e destinata.

## Opzioni considerate

- Media +- 1,96 SD: semplice, ma sbagliata proprio dove conta.
- Quantili con convenzione "primo punto con CDF >= q": possono differire di un intero passo di griglia tra linguaggi.
- `doubtful` al raggiungimento di 30 prove: scartato per l'effetto sulle pendenze basse.
