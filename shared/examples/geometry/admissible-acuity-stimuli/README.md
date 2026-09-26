# geometry/admissible-acuity-stimuli

Tier 2. Stimoli ammissibili per l'acuita sulla griglia di `parameters.json` (-0.30...1.80, passo 0.02, indici 0...105, `x_i = -0.30 + 0.02 i`): tratto >= 2 px del dispositivo e lettera (5 tratti) non piu grande del lato corto dello schermo.

## Oracolo manuale

Tratto in px del dispositivo: `d * (1' in rad) * 10^x * ppi / 25.4`.

- 400 mm, 460 ppi: tratto = `2.107217 * 10^x`. A x = -0.04 (indice 13) 1.9218 px, scartato; a x = -0.02 (indice 14) 2.0124 px, ammesso. A x = 1.80 la lettera e 664.8 px <= 1179. Ammessi gli indici 14...105 (92 stimoli); `displayLimitLogMAR = -0.02`.
- 350 mm, 326 ppi: tratto = `1.306685 * 10^x`. A x = 0.18 (indice 24) 1.9778 px, scartato; a x = 0.20 (indice 25) 2.0710 px, ammesso. A x = 1.80 la lettera e 412.2 px <= 828. Ammessi gli indici 25...105 (81 stimoli); `displayLimitLogMAR = 0.2`.

I valori limite sono lontani dalla soglia di 2 px (margine > 0.01 px), quindi il risultato non dipende da differenze di arrotondamento.
