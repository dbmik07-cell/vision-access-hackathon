# geometry/contrast-letter-size

Tier 2. Dimensione della lettera del test di contrasto: `max(3 gradi, 5' * 10^(upper + 0.6))`, massimo 8 gradi.

## Oracolo manuale

- upper 0.3: `5 * 10^0.9 / 60 = 0.662 gradi` -> 3 gradi, non limitata.
- upper 1.0: `5 * 10^1.6 / 60 = 3.31756 gradi` -> 3.31756, non limitata.
- upper 1.5: `5 * 10^2.1 / 60 = 10.491 gradi` -> 8 gradi, `contrastLetterSizeCapped = true`.
