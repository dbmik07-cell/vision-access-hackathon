# summary/label-edges

Tier 2. Etichette ai bordi: categoria OMS dalla mediana dell'acuita e fascia di contrasto dalla mediana del contrasto.

## Oracolo manuale

- Categoria OMS: si entra in una categoria solo se la mediana e **strettamente maggiore** della soglia (0.3, 0.48, 1.0, 1.3). Quindi 0.3 -> `none`, 0.31 -> `mild`, 0.48 -> `mild`, 0.5 -> `moderate`, 1.0 -> `moderate`, 1.02 -> `severe`, 1.3 -> `severe`, 1.32 -> `blindness`.
- Fascia di contrasto: estremo inferiore **incluso** (1.65, 1.5, 1.0). Quindi 1.65 -> `normal`, 1.64 -> `borderline`, 1.5 -> `borderline`, 1.49 -> `reduced`, 1.0 -> `reduced`, 0.99 -> `severelyReduced`.
