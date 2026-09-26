# quest/contrast-reaches-sd

Tier 1. Contrasto nella variabile di facilita `x = log10(C_Weber)`: corretta se e solo se `x >= -1.51` (contrasto alto = facile). Ammessi gli indici 3...105 (`x >= -2.04`, cioe `ceilingLogCS = 2.04`).

## Stato

`final`, congelato con l'issue #14 dall'output dell'implementazione di riferimento Python dopo `tiny-hand-computed` e i controlli sotto.

La traccia (`steps` e `final`) e nello spazio del motore, come ogni traccia: `final.estimate` -1.5236, `final.ci95` [-1.6963, -1.3778]. I controlli in logCS riguardano il blocco del profilo che si scrive da questo `final` (`logCS` 1.5236, `ci95` [1.3778, 1.6963]), non la traccia. La traccia non contiene un risultato di acuita: `contrastLetterSizeCapped` (dal limite superiore di `acuity.ci95`) appartiene al blocco del profilo e non compare nel `final`.

Risultato `doubtful` con `wideInterval`: larghezza di `ci95` 0.319 > `W = 0.30`. E l'output corretto secondo il contratto (affidabilita dalla sola larghezza); se le simulazioni cambieranno `W`, la traccia si ricongela.

## Oracolo manuale (controlli di plausibilita)

- La soglia dell'osservatore (-1.51) sta tra -1.52 e -1.50, quindi il logCS pubblicato `= -t` (mediana del motore cambiata di segno) deve cadere in [1.46, 1.56]; un valore vicino a 0.6 o a 2 indica un segno invertito.
- `ci95` pubblicato in logCS con estremi scambiati: `[-q_0.975, -q_0.025]`.
- Deve fermarsi per SD < 0.08 con `12 <= n < 30`; `censoredAtCeiling = false`.
