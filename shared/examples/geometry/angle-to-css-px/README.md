# geometry/angle-to-css-px

Tier 2. Conversione angolo -> mm -> px del dispositivo -> CSS px, incluso un caso con `nativeScale` 2.88 (tipo mini, valore d'esempio).

## Oracolo manuale

Formule: `mm = d * angolo_rad` (1' = pi / 10800 rad); `devicePx = mm * ppi / 25.4`; `cssPx = devicePx / nativeScale`.

- 400 mm, 5': `mm = 400 * 0.00145444 = 0.581776`; `devicePx = 0.581776 * 460 / 25.4 = 10.53611`; `cssPx = 3.51204`.
- 350 mm, 60' (1 grado): `mm = 350 * 0.0174533 = 6.108652`; `devicePx = 6.108652 * 476 / 25.4 = 114.4771`; `cssPx = 114.4771 / 2.88 = 39.74900`.
- 450 mm, 480' (8 gradi): `mm = 450 * 0.139626 = 62.83185`; `devicePx = 62.83185 * 326 / 25.4 = 806.4246`; `cssPx = 403.2123`.
