# quest/contrast-reaches-sd

Tier 1. Contrasto nella variabile di facilita `x = log10(C_Weber)`: corretta se e solo se `x >= -1.51` (contrasto alto = facile). Ammessi gli indici 3...105 (`x >= -2.04`, cioe `ceilingLogCS = 2.04`).

## Stato

Gli output attesi per passo sono `pending`: li genera l'implementazione di riferimento Python solo dopo aver superato `tiny-hand-computed` e i controlli sotto; poi il file si aggiorna con `status: final` in una PR condivisa.

## Oracolo manuale (controlli di plausibilita)

- Soglia del motore tra -1.52 e -1.50, quindi logCS pubblicato `= -t` in [1.46, 1.56]; un valore vicino a 0.6 o a 2 indica un segno invertito.
- `ci95` pubblicato in logCS con estremi scambiati: `[-q_0.975, -q_0.025]`.
- Deve fermarsi per SD < 0.08 con `12 <= n < 30`; `censoredAtCeiling = false`.
