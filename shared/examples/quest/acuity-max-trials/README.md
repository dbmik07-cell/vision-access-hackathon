# quest/acuity-max-trials

Tier 1. Come `acuity-reaches-sd`, ma la risposta e invertita nelle prove 2, 3, 6, 12, 15, 18, 21, 24, 27, 30: risposte incoerenti che non devono permettere di raggiungere SD < 0.05.

## Stato

`final`, congelato con l'issue #14 dall'output dell'implementazione di riferimento Python dopo `tiny-hand-computed` e i controlli sotto.

## Scelta delle inversioni (issue #14)

Le inversioni originali (3, 6, 9, ..., 30) facevano fermare il motore a `n = 18` per SD < 0.05, con mediana 1.23: l'inversione alla prova 3 (stimolo 1.0 sbagliato) portava la stima sopra 1.0 e le inversioni successive, tutte su stimoli facili, risultavano coerenti con una soglia di circa 1.22. Si e scelta la variante con 9 spostata alla prova 2 (stesso numero di inversioni), perche:

- arriva esattamente a `n = 30` per `maxTrials`, con `maxTrialsReached` e `endedBy = engineStop`;
- la stima resta vicina alla soglia dell'osservatore simulato: mediana 0.508;
- `ci95` [0.339, 0.624] contiene 0.51;
- i margini sono ampi per l'accordo Python/Swift: SD minima per `n >= 12` 0.0653 (target 0.05); differenza minima tra la migliore e la seconda entropia attesa 5.3e-6, molto sopra lo spareggio 1e-12.

Le inversioni alle prove 2 e 3 cadono su stimoli sotto soglia (0.50 e 0.26, risposte fortunate), quelle successive su stimoli facili (errori): il motore esplora entrambi i lati di 0.51.

## Oracolo manuale (controlli di plausibilita)

- Deve arrivare a `n = 30` con flag `maxTrialsReached`.
- L'affidabilita dipende solo dalla larghezza di `ci95` (<= 0.30 `reliable`, altrimenti `doubtful` + `wideInterval`), non dal tetto di prove: qui larghezza 0.284 -> `reliable` con `maxTrialsReached`.
- Se l'esecuzione di riferimento si ferma prima di 30, le inversioni vanno riviste prima di congelare il golden.
