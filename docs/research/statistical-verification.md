# Statistical verification of the IpoView spec

Fact-check of the statistical and psychophysical claims in `docs/spec/ipoview-spec.md` (sections 4-8 and 10), carried out on 2026-09-26 during `/grill-with-docs` by a research sub-agent using web sources. It is the evidence behind several deviations in `docs/data-contracts.md`.

**Caveats.** Some primary pages (PubMed, Wiley, Nature) were blocked by captchas or 403 errors. Claims that could not be confirmed are marked *unverified* or *from memory*. All arithmetic was done by the agent and has not been independently re-derived.

## Section 4: geometry and logMAR

- `h = d·θ` and `px = h·ppi/25.4`: **correct**. The small-angle error is below 0.1% for θ < 5°. Off-centre positions (visual field, Amsler) need `d·tan(eccentricity)`; at 30° the small-angle form is off by about 10%.
- logMAR (0 = 5′ letter with 1′ stroke; 0.1 ≈ 26%, one chart line): **correct** (10^0.1 = 1.259).
- WKWebView CSS px = iOS points, not device pixels: **correct** (standard WebKit behaviour; not re-checked against Apple documentation).
  - Conversion: CSS px = mm × ppi / 25.4 / devicePixelRatio. On some models (e.g. the mini) nativeScale ≈ 2.88.
  - Pages without `<meta viewport width=device-width>` are laid out 980 CSS px wide and scaled down.
  - The acuity E should be drawn natively at device pixels: a 1 pt stroke is 3 device px, a cost of 0.18 logMAR.
- Smallest displayable logMAR for a tumbling E with stroke ≥ 2 device px:

| ppi | 25 cm | 35 cm | 40 cm |
| --- | --- | --- | --- |
| 460 | 0.18 | 0.04 | −0.02 |
| 326 | 0.33 | 0.19 | 0.13 |

  - 0.0 logMAR is only measurable from about 37 cm on 460 ppi. Young adults (−0.1 to −0.2) can't be measured at all.
  - Stroke steps of 2, 3, 4 px are steps of 0.18 and 0.12 logMAR (Carkeet 2018, [doi:10.1111/opo.12434](https://doi.org/10.1111/opo.12434)).
  - FrACT antialiases strokes down to 0.5 px ([manual](https://michaelbach.de/fract/manual.html)).
  - The 25-60 cm range also changes accommodation demand (4 D at 25 cm) for presbyopes. Recommendation: test at about 40 cm.

## Section 5.1: acuity

- Logistic with s in logMAR, γ = 0.25, λ = 0.02: **correct**. β > 0 is the right sign because larger s is easier. The 25-75% width is 2·ln3/β ≈ 2.2/β.
- Realistic β: Carkeet et al. 2001 measured probit σ ≈ 0.07 logMAR in well-corrected eyes and ≈ 0.12 with defocus ([OVS 78:113](https://pubmed.ncbi.nlm.nih.gov/11265926/)), i.e. logistic β ≈ 24 and ≈ 14.
  - Proposed grid {6, 10, 15, 24, 35}; 6 and 10 for low vision are a design assumption.
  - β is barely identifiable in 12-30 trials: treat it as a nuisance parameter and marginalize.
- QUEST+ description (grid prior, Bayes update, minimum expected entropy, joint estimation): **correct**. Watson 2017, JOV 17(3):10, [doi:10.1167/17.3.10](https://doi.org/10.1167/17.3.10).
- Threshold grid −0.3...1.8, step 0.02: **approximately OK**.
  - Below the display floor the posterior only reflects the prior; report censored results ("≤ display limit").
  - Use a uniform or weakly informative prior.
- Stop rule (SD < 0.05, 12-30 trials): **plausible**.
  - Fisher-information estimate: SD ≈ 0.18/√n for β = 15 (0.05 at n = 12). For β = 6, SD is still ≈ 0.08 at n = 30.
  - FrACT defaults: 24 trials for 4AFC, 18 for 8AFC. FrACT test-retest limits: ±0.46 logMAR at 6 trials, ±0.17 at 18 ([Bach 2024](https://link.springer.com/article/10.1007/s00417-024-06638-z)).
- Mean ± 1.96·SD: **concern**. The posterior is skewed or truncated at grid edges and at the display floor; use the 2.5% and 97.5% posterior quantiles.
- Criterion P(t) ≈ 0.615: **fine**. FrACT uses the midpoint between guessing and 100% (62.5% for 4AFC); ISO 8596 uses 60%. FrACT adds +0.05 logMAR to match chart scores. The link to ETDRS letter-by-letter scoring is *unverified*.
- WHO/ICD-11 categories (≤ 0.3 / > 0.3 / > 0.48 / > 1.0 / > 1.3 logMAR, i.e. 6/12, 6/18, 6/60, 3/60): **correct** ([ICD-11 9D90](https://epidemiology.tech/raab/icd-11-vision-categories/)).
  - Rename "Normale" to "no vision impairment".
  - The categories use presenting distance acuity in the better eye. Near vision has a single cut-off (worse than N6/M0.8 at 40 cm ≈ 0.3 logMAR). The spec's near-vs-distance caveat is correct.

## Section 5.2: contrast

- Pelli-Robson letter ≈ 3°: **approximately correct**. Letters are 4.9 cm (2.8° at 1 m); 16 triplets, 0.00-2.25 logCS in 0.15 steps. Pelli, Robson & Wilkins 1988, Clin Vis Sci 2:187-199.
- Contrast definition: use **Weber**, C = (Lb − Lt)/Lb, logCS = −log10 C. FrACT reports Weber contrast for optotypes. The spec never names the definition.
- Letter size max(3°, 4× acuity): reasonable, but it **needs a cap** (4× at 1.8 logMAR ≈ 21°).
- "8 bits ≈ 2.0 log units": **numerically correct but misleading**.
  - One sRGB step below white gives 254 → Y = 0.9911, C = 0.0089, logCS = 2.05.
  - The next levels are 253 → 1.75, 252 → 1.58, 251 → 1.45: only four levels in the critical band. Use spatial dithering (FrACT default).
  - Lock True Tone, Night Shift, auto-brightness and Reduce White Point.
  - The grid to 2.1 exceeds the displayable ceiling; treat results at the top as censored.
- Norms: **approximately correct**.
  - Common convention: 2.0 normal, < 1.5 impairment, < 1.0 disability.
  - Healthy young people mostly ≥ 1.80, older people ≥ 1.65 (Mäntyjärvi & Laitinen 2001, [JCRS 27:261](https://pubmed.ncbi.nlm.nih.gov/11226793/)).
  - The spec uses 1.5 as "normal" but R3 uses 1.65: reconcile.
  - A 4AFC E at 61.5% is not Pelli-Robson triplet scoring; expect an offset.

### Contrast β grid (follow-up)

- **Proposed grid: β ∈ {5, 7, 10, 14, 20} per log10 unit**, uniform prior, marginalized. Middle values medium-to-high confidence; the ends 5 and 20 low confidence. If a single value is needed: β ≈ 11.
- **Sign problem:** with x = logCS, a higher x is a fainter E, so the logistic as written in the spec rises in the wrong direction. Use x = log10 C (threshold = −logCS) or flip the sign.
- **Conversion from Weibull** (QUEST form in log10 intensity, a Gumbel with k = β_W·ln10) to the logistic slope b:
  - matching maximum slope: b = 4·ln10·β_W/e ≈ 3.39·β_W;
  - matching the 25-75% spread: b ≈ 3.22·β_W;
  - used: b ≈ 3.3·β_W.

| Source | Task | β_W | Logistic β | Status |
| --- | --- | --- | --- | --- |
| Watson & Pelli 1983; QUEST default ("typically 3.5") | contrast detection | 3.5 | ≈ 11.5 | verified in Psychtoolbox docs |
| Wallis, Baker, Meese & Georgeson 2013, Vision Res 76:1 ([Europe PMC](https://europepmc.org/article/MED/23041562)) | 2IFC grating detection | ≈ 3 | ≈ 10 | abstract verified |
| Arditi 2005, IOVS 46:2225 ([doi:10.1167/iovs.04-1198](https://doi.org/10.1167/iovs.04-1198)) | letter contrast simulation | 3.5 | ≈ 11.5 | *unverified* (value from a search snippet) |
| qCSF (Lesmes 2010; 10-digit qCSF, TVST) | fixed-slope log-Weibull | 1-3.5 | ≈ 3.3-11.5 | *partly unverified* |
| Carkeet & Bailey 2017, OPO 37:118 ([doi:10.1111/opo.12357](https://doi.org/10.1111/opo.12357)) | low-contrast letter charts, size axis | - | - | verified; only shows low-contrast curves are flatter |

- No low-vision or elderly slopes on the contrast axis were found; the shallow end is an assumption. K-CS reports no slope.
- FrACT contrast: Best PEST, slope not documented. Weber contrast in logCS for optotypes. Dithering on by default ("allows contrast thresholds higher than 2.0 logCS").

## Section 6, case A (normal if the whole CI is in the normal band)

- **Sound in principle, three issues:**
  - "Whole 95% CI below 0.3" is ≈ 97.5% one-sided, but the continue rule is P > 95%: choose one.
  - Display floor and contrast ceiling may prevent clearing the band within 30 trials; add an "undetermined" outcome.
  - ≤ 0.3 means "no WHO impairment", yet 0.25 may still benefit from adaptation.

## Section 8: rules

- **R0:** design choice, fine; use quantile bounds.
- **R1:**
  - Print size defined on x-height: **correct**. MNREAD logMAR = log10(x-height angle / 5′) ([mnread.umn.edu/design](https://mnread.umn.edu/design)). The acuity E uses letter height; keep the two apart.
  - Fallback +0.4 logMAR (×2.5): **approximately correct**. Whittaker & Lovie-Kitchin 1993 (OVS 70:54-65): fluent reading needs an acuity reserve of about 2:1 or more; the often-quoted 3:1 is *unverified*.
  - CPS + 0.1: design choice.
  - font = h_x / r_x: **correct** if r_x = OS/2 sxHeight / unitsPerEm; the Atkinson Hyperlegible value is *unverified* (read it from the font file). Then divide by devicePixelRatio.
  - Linear scaling with distance: **correct**.
- **R2:**
  - WCAG 1.4.12 values (1.5 / 2 / 0.12 / 0.16): **correct**. WCAG 1.4.8 (AAA): ≤ 80 characters per line, no justification.
  - L_max geometry: **correct** (10° at 35 cm → 98.7 mm). But the screen is ~70 mm wide (≈ ±5.8° at 35 cm), so the rule only binds for radii ≲ 6°. Fluent reading is possible with only 4 visible characters (Whittaker & Lovie-Kitchin 1993).
- **R3:**
  - Ratio (L1 + 0.05)/(L2 + 0.05) with sRGB threshold 0.04045 (0.03928 before May 2021, no practical effect); AA 4.5:1 (3:1 large text), AAA 7:1: **correct**.
  - WCAG ties 4.5:1 and 7:1 to the contrast loss typical of ~20/40 and ~20/80 acuity, not to logCS ([Understanding 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)). The logCS mapping is a legitimate design choice.
  - Dark theme #E8E6E3 on #121212 ≈ 15:1, just at the < 1.0 target (15.04:1 by our own calculation).
- **R7:** 44 × 44 pt (Apple HIG): **correct**. WCAG 2.5.5 (AAA) 44 CSS px, 2.5.8 (AA) 24.

## Post-MVP claims (brief)

- **MNREAD speed** = 60 × (10 − errors)/seconds: **correct**. It assumes 10 standard words of 6 characters each; Italian sentences need normalization.
- **Cheung, Kallie, Legge & Cheong 2008** (IOVS 49:828): real paper, but it fits an **exponential-decay** model with nonlinear mixed effects (CPS at 80-90% of max speed). Don't call a two-limb fit "Cheung's method".
- **ZEST**: King-Smith, Grigsby, Vingrys, Benes & Supowit 1994, Vision Res 34:885-912 (citation from memory).
- **Rubinstein, McKendrick & Turpin 2016**: real. "Incorporating spatial models in visual field test procedures", TVST 5(2):7, [doi:10.1167/tvst.5.2.7](https://doi.org/10.1167/tvst.5.2.7). The Gaussian weights with σ = 6° are our own choice, "inspired by" it.
- **Goldmann III** = 0.43° and **200 ms**: correct.
- **Blind spot** ~15° temporal, slightly below horizontal: correct (textbook, from memory).
- **Heijl & Krakau 1975**: real (Acta Ophthalmol 53:293-310).
- **Humphrey criteria**: SITA flags fixation losses ≥ 20% and false positives ≥ 15%; older full-threshold criteria used 33% for false positives and false negatives.
- **Melbourne Rapid Fields**: fixation at the corners reaches 30°, and spot size is scaled for the flat screen (Vingrys 2016, [TVST](https://tvst.arvojournals.org/article.aspx?articleid=2534339)); the spec should also scale spot size with eccentricity. The spec's link points to Schulz et al. 2018, a validation study.
- **Bradley-Terry**: with 6 pairs compared once, the ranking equals the win count, and the maximum-likelihood fit breaks down when one version wins everything. Use win counts or a 2×2 design.
- **Amsler**: **wrong**. The standard grid is 20 × 20 squares of 1° at about 30 cm (±10°); a 10 × 10 grid covers ±5°. Call it a "reduced central Amsler grid".

## References (section 10 of the spec)

- **Correct:** Watson & Pelli 1983 (Percept Psychophys 33:113); Watson 2017; King-Smith 1994; Heijl & Krakau 1975; Pelli, Robson & Wilkins 1988; Cheung 2008; Rubinstein 2016; ICD-11 9D90; Hoogsteen & Szpiro 2023 (RIDD 138:104517); Bonavero, Huchard & Meynard 2015 (W4A, [doi:10.1145/2745555.2746647](https://doi.org/10.1145/2745555.2746647)); K-CS; Alleye (Eye 2019).
- **MRF:** cite Vingrys 2016 for the technique.
- **Not re-checked:** Peek Acuity (JAMA Ophthalmol), W3C Low Vision Needs.
