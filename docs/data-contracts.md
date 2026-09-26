# Contratto dati condiviso (MVP)

**Stato:** versione `1.0`, concordata da Michele durante `/grill-with-docs` (Q1-Q26) e **approvata da Rocco il 2026-09-26**, comprese le tre precisazioni di stesura (quantili limitati alla griglia, fascia di contrasto dalla mediana, `unreliable` trattato come `doubtful` in R0). I file condivisi della sezione 2 sono presenti in `shared/`.

Questo documento e **normativo** per l'MVP. In caso di conflitto con la specifica originale (`docs/spec/ipoview-spec.md`, di Rocco), prevale questo contratto. Le differenze sono elencate in "Deviazioni dalla specifica". Le prove a supporto sono in `docs/research/statistical-verification.md`; le decisioni difficili da invertire sono in `docs/adr/`.

Non definisce un servizio backend o endpoint HTTP: Python (`backend/`) e Swift (`ios/`) implementano in parallelo la stessa specifica e si confrontano solo tramite i file in `shared/`.

## 1. Ambito MVP

Distanza del viso + acuita + contrasto -> `VisualProfile` -> regole R0-R8 -> `AdaptationPlan` -> browser adattato. Campo visivo, Amsler e luce entrano nell'MVP solo come **blocchi preset** del profilo, per dimostrare le regole. Test di lettura, R9, R10, campo visivo completo, Amsler, luce e affidabilita avanzata (sezione 6 della specifica) sono post-MVP.

Priorita di Michele: (1) contratto, regole MVP e casi golden tier 1+2 con oracolo manuale; (2) QUEST+ in Python verificato sulle tracce scriptate; (3) simulazioni.

## 2. File condivisi

| File | Contenuto |
| --- | --- |
| `shared/parameters.json` | tutti i parametri numerici di questo documento, ognuno come `{value, unit, source}`; letto da Python a runtime e incluso come risorsa nell'app Swift. Nessuno ricopia i numeri nel codice. |
| `shared/devices.json` | `modelIdentifier -> {name, ppi, ppiSource}` per 38 identificativi di iPhone con Face ID (da iPhone X a iPhone 18 Pro Max), verificati il 2026-09-26: ppi dalle pagine Tech Specs di Apple, identificativi da The Apple Wiki con controlli incrociati. Nel simulatore iOS `hw.machine` restituisce `arm64`/`x86_64`: il modello simulato e in `SIMULATOR_MODEL_IDENTIFIER`. |
| `shared/visual-profile.schema.json` | schema del `VisualProfile` (sezione 8). |
| `shared/adaptation-plan.schema.json` | schema dell'`AdaptationPlan` (sezione 9). |
| `shared/examples/` | casi golden (sezione 10); formati descritti in `shared/examples/README.md`. |

Una modifica a questi file e una modifica del contratto: coinvolge entrambi, aggiorna `schemaVersion` se serve e i casi golden interessati.

## 3. Formato

- JSON Schema draft 2020-12, **rigido** (`additionalProperties: false`).
- `schemaVersion`: stringa `"MAJOR.MINOR"`, inizia da `"1.0"`. MAJOR = modifica incompatibile (campo rinominato o rimosso); MINOR = aggiunta opzionale.
- Nomi camelCase con l'unita nel nome (`referenceDistanceMm`, `fieldRadiusDeg`, `fontSizeCssPx`).
- Blocchi opzionali del profilo non misurati: **assenti**. Campi del piano che significano "non toccare": **`null` esplicito**. Il piano e sempre completo.
- Validazione: Python valida ogni caso golden contro gli schemi (`jsonschema`); Swift verifica con decodifica `Codable` rigorosa. Lo schema JSON e l'autorita.

## 4. Confronto Python/Swift

- Unico ponte: i casi golden in `shared/examples/`. Entrambe le suite di test li leggono; non si esegue Swift da Python ne viceversa.
- **Nessun seed condiviso tra linguaggi** (ADR 0001). I test adattivi si verificano con **tracce scriptate**: risposte fissate in anticipo e, per ogni passo, output attesi. Il seed serve solo nelle simulazioni Python.
- **Tolleranze:**
  - valori intermedi float: `|a - b| <= 1e-9 + 1e-9 * |b|`;
  - output pubblicati (`ci95`, logMAR, logCS, `fontSizeCssPx`, rapporti di contrasto): `|a - b| <= 1e-6`;
  - campi discreti (enum, booleani, indice dello stimolo, stop, numero di prove): uguaglianza **esatta**.
- Nessun arrotondamento nel piano; l'eventuale arrotondamento avviene in `adapter.js`.
- Python usa numpy: l'ordine di somma diverso da un ciclo Swift produce differenze ~1e-15, dentro le tolleranze.

## 5. Motore QUEST+ (unico per acuita e contrasto)

**Variabile di facilita.** Il motore lavora su una variabile `x` che cresce con la visibilita dello stimolo:

| Test | `x` | Soglia pubblicata |
| --- | --- | --- |
| Acuita | logMAR della lettera | `logMAR = t` |
| Contrasto | `log10(C_Weber)`, intervallo `[-2.1, 0]` | `logCS = -t` (gli estremi di `ci95` si scambiano) |

La conversione `logCS = -t` avviene **solo** quando si scrive il profilo.

**Modello psicometrico** (identico per i due test):

```
P(corretta | x, t, beta) = gamma + (1 - gamma - lambda) / (1 + exp(-beta * (x - t)))
```

`gamma = 0.25` (E in 4 direzioni), `lambda = 0.02`. La soglia `t` e il punto al ~61,5% di risposte corrette, vicino alla convenzione ISO 8596 (60%) e FrACT (62,5%).

**Griglie e prior:**

| Parametro | Acuita | Contrasto |
| --- | --- | --- |
| griglia di `t` | -0.30 ... 1.80, passo 0.02 (106 punti) | -2.10 ... 0.00, passo 0.02 (106 punti) |
| griglia di `beta` | {6, 10, 15, 24, 35} per logMAR | {5, 7, 10, 14, 20} per unita log10 |
| stimoli candidati | stessa griglia di `t`, filtrata dagli stimoli ammissibili | stessa griglia di `t`, filtrata dagli stimoli ammissibili |
| prior | uniforme su `t` x `beta` | uniforme su `t` x `beta` |

I punti di ogni griglia si generano come `t_i = min + i * step` con `i` intero da 0 (mai per somme cumulative), cosi gli indici coincidono tra i linguaggi.

Fonti di `beta`: acuita 15/24/35 coprono Carkeet 2001 (beta ~ 24 occhi corretti, ~ 14 con defocus); 6 e 10 sono un'ipotesi di design per l'ipovisione. Contrasto: centro ~10-12 da Weibull 3-3,5 (Watson e Pelli 1983; Wallis e altri 2013); estremi 5 e 20 ipotesi a bassa confidenza. `beta` e un parametro di disturbo: si marginalizza e **non si pubblica**.

**Stimoli ammissibili come input.** A ogni prova il motore riceve la lista degli stimoli ammissibili (calcolata dalla geometria, sezione 7) e sceglie solo tra quelli.

**Aggiornamento.** Dopo ogni risposta `r`: `posterior(t, beta) ∝ posterior(t, beta) * P(r | x, t, beta)`, poi normalizzazione a somma 1.

**Scelta dello stimolo.** Per ogni stimolo ammissibile `x`: probabilita di ciascun esito `p(r | x) = Σ posterior * P(r | x, ·)`; entropia del posterior aggiornato `H_r = -Σ p' ln p'` (logaritmo naturale); entropia attesa `E[H] = Σ_r p(r | x) H_r`. Si sceglie il minimo. **Spareggio:** gli stimoli con `E[H]` entro `1e-12` dal minimo sono pari; vince quello con indice piu basso nella lista degli ammissibili.

**Riassunti della soglia** (sulla marginale `p_i = Σ_beta posterior(t_i, beta)`):

- media `m = Σ p_i t_i` e SD `sqrt(Σ p_i (t_i - m)^2)` sui punti della griglia: usate **solo** dalla regola di stop;
- quantili con **convenzione a bin**: il punto `t_i` distribuisce la sua massa uniformemente su `[t_i - h/2, t_i + h/2]` (h = 0.02), quindi la CDF `F` e continua e lineare a tratti. Quantile `q = min{ x : F(x) >= q }`: si trova il primo bin con `p_i > 0` in cui la somma cumulata raggiunge `q` e si interpola linearmente dentro il bin. Il risultato si limita all'intervallo della griglia `[t_min, t_max]`;
- **stima pubblicata = mediana** (`q = 0.5`); **`ci95 = [q_0.025, q_0.975]`** (ADR 0002).

**Stop.** Dopo ogni aggiornamento, con `n` risposte: stop se `(n >= 12 e SD < target)` oppure `n = 30`. Target SD: acuita 0.05 logMAR, contrasto 0.08 logCS. Nessuna regola sulla certezza della categoria.

**Affidabilita (MVP).** `reliable` se `q_0.975 - q_0.025 <= W`, altrimenti `doubtful` con flag `wideInterval`. `W = 0.30` (logMAR per l'acuita, logCS per il contrasto), parametro di design da calibrare con le simulazioni. `unreliable` resta nell'enum ma l'MVP non lo produce. Il flag `maxTrialsReached` (stop a 30 senza target SD) e solo informativo.

## 6. Test MVP

### Acuita

- E nera su bianco, 4 direzioni, scelta forzata. Stimolo `x` = logMAR: altezza della lettera `5' * 10^x`, tratto `1' * 10^x`.
- La E si disegna in modo nativo ai pixel del dispositivo, non nel web view (Rocco).
- **Limite dello schermo:** `displayLimitLogMAR` = il piu piccolo stimolo ammissibile durante il test (minimo sulle prove). `censoredAtDisplayLimit = mediana < displayLimitLogMAR`; la stima si mostra come "<= limite". La censura taglia l'estremo inferiore, che R0 non usa: non cambia il piano.
- **Categoria OMS** (`whoCategory`) dalla **mediana**, soglie ICD-11: `none` <= 0.3; `mild` > 0.3; `moderate` > 0.48; `severe` > 1.0; `blindness` > 1.3. La schermata dei risultati avvisa che le categorie OMS si riferiscono alla visione da lontano, mentre il test misura quella da vicino.

### Contrasto

- **Contrasto di Weber:** `C = (L_sfondo - L_lettera) / L_sfondo`, `logCS = -log10(C)`. Sfondo bianco sRGB a luminosita fissa; luminanza dai valori sRGB con la curva standard (`V <= 0.04045 ? V/12.92 : ((V+0.055)/1.055)^2.4`).
- **Dimensione della lettera:** `max(3°, 5' * 10^(acuity.ci95[1] + 0.6))`, massimo **8°**. Se il valore non limitato supera 8°: flag `contrastLetterSizeCapped` (succede per acuita superiore a circa 1.4 logMAR).
- **Livelli visualizzabili:** lo stimolo e il contrasto di Weber voluto (griglia continua). Quali livelli sono ammissibili, e se usare il dithering spaziale, e una scelta di rendering di Rocco; Swift passa solo i livelli che mostra davvero. Senza dithering, vicino al bianco, 8 bit danno solo 2.05, 1.75, 1.58, 1.45 logCS.
- **Tetto:** `ceilingLogCS` = il livello ammissibile piu alto durante il test; `censoredAtCeiling = mediana logCS > ceilingLogCS`. Taglia l'estremo superiore, che R0 non usa.
- **Fasce di contrasto** (stesse soglie per etichetta e R3; estremo inferiore incluso): `normal` >= 1.65; `borderline` [1.5, 1.65); `reduced` [1.0, 1.5); `severelyReduced` < 1.0. L'etichetta `band` si calcola dalla **mediana** (come la categoria OMS); R3 usa il limite prudente.
- Nessuna correzione per l'eta nell'MVP.

## 7. Geometria

- Angolo -> millimetri: `h_mm = d_mm * θ_rad` (piccolo angolo, identico nei due linguaggi).
- Millimetri -> pixel del dispositivo: `px = mm * ppi / 25.4`.
- Millimetri -> CSS px (= punti iOS): `cssPx = mm * ppi / (25.4 * nativeScale)`.
- `ppi` da `shared/devices.json`. `nativeScale` letto **a runtime** da `UIScreen.nativeScale` (varia sui mini e con lo Zoom schermo). **Modello assente dalla tabella: il test non parte**, con messaggio chiaro; nessun ppi stimato.
- **Viewport:** i CSS px coincidono con i punti solo con viewport 1:1. `adapter.js` forza `<meta name="viewport" content="width=device-width, initial-scale=1">` prima di applicare il piano (ADR 0003).
- **Stimoli ammissibili per l'acuita** (input: distanza, ppi, lato corto dello schermo in px del dispositivo): tratto >= 2 px del dispositivo alla distanza del momento e lettera interamente nello schermo.
- **Fascia di test:** 35-45 cm durante acuita e contrasto; fuori fascia il test va in pausa e la voce guida. Parametro in `parameters.json`, modificabile da Rocco. Durante la navigazione R1 funziona a qualsiasi distanza.

## 8. VisualProfile (MVP)

Blocchi **obbligatori**: `device`, `acuity`, `contrast`, `summary`. Blocchi **opzionali** (assenti se non misurati): `reading`, `amsler`, `visualField`, `light`, `userAdjustments`. Ogni blocco di risultato ha `source: "measured" | "preset"`. Nei blocchi opzionali i **valori riassuntivi** usati dalle regole sono obbligatori, i **dati grezzi** (`points`, `cells`) opzionali.

| Blocco | Campi |
| --- | --- |
| (radice) | `schemaVersion` |
| `device` | `modelIdentifier`, `ppi`, `nativeScale` |
| `acuity` | `source`, `logMAR` (mediana), `ci95` `[basso, alto]`, `reliability`, `flags`, `whoCategory`; se misurato anche `trials`, `displayLimitLogMAR`, `censoredAtDisplayLimit` |
| `contrast` | `source`, `logCS` (mediana), `ci95`, `reliability`, `flags`, `band`; se misurato anche `trials`, `ceilingLogCS`, `censoredAtCeiling` |
| `amsler` | `source`; `right`, `left`: `distortedAreaDeg2`, `missingAreaDeg2`, `centralInvolved`, opzionale `cells` (10 x 10: 0 normale, 1 distorta, 2 mancante) |
| `visualField` | `source`; `right`, `left`: `fieldRadiusDeg`, `pattern` (`none` / `peripheral` / `tunnel` / `scattered`), dati grezzi e indici di affidabilita opzionali (`points` con `xDeg`, `yDeg`, `sensitivity`, `sd`, `seen`; `meanDefect`; tassi di perdita di fissazione, falsi positivi e falsi negativi; `reliability`) |
| `light` | `source`, `photophobia`, opzionali `preferredTheme` (`light` / `dark`) e `preferredBrightness` (0-1) |
| `reading` | post-MVP; riservato, campi da definire |
| `summary` | `normalVision`, `overallReliability` |
| `userAdjustments` | `textSizeOffsetLogMAR` (default 0) |

- `reliability`: `"reliable" | "doubtful" | "unreliable"`. Flag MVP: `wideInterval`, `maxTrialsReached`, `contrastLetterSizeCapped`.
- `centralInvolved`: almeno una cella distorta o mancante nei 2 gradi centrali. Nei preset e dato direttamente.
- `summary.normalVision` (solo informativo, non cambia il piano): `acuity.ci95[1] < 0.3` **e** `contrast.ci95[0] >= 1.5` **e** nessun blocco opzionale segnala un problema (`amsler` con area non nulla o `centralInvolved`; `visualField` con `pattern != "none"`). Un blocco assente non blocca.
- `summary.overallReliability`: la peggiore tra i blocchi **misurati** (`reliable` < `doubtful` < `unreliable`); i preset non contano; `null` se nessun blocco e misurato.

## 9. AdaptationPlan e regole MVP

Il piano contiene solo numeri pronti. Include `schemaVersion` e l'eco del contesto per cui e calcolato: `context: {referenceDistanceMm, ppi, nativeScale}`.

**Contesto.** `referenceDistanceMm = 400` (costante). A runtime Swift riscala `fontSizeCssPx` per `d / referenceDistanceMm` e chiama `IpoView.setFontSizePx`. Le larghezze di riga sono in `ch` e non dipendono dalla distanza.

**Costanti del font** (Atkinson Hyperlegible, stessa versione nell'app e nelle misure): `r_x` = sxHeight / unitsPerEm = 496 / 1000 = **0.496**; `zeroWidthEm` = avanzamento del glifo "0" / unitsPerEm = 648 / 1000 = **0.648**. Estratte dal file `AtkinsonHyperlegible-Regular.ttf` "Version 1.006" (Google Fonts, commit `1b22086`, SHA-256 in `parameters.json`) leggendo con fontTools, in un ambiente temporaneo, le tabelle `head`, `OS/2` e `hmtx`. L'app deve includere lo stesso file: un altro file o un'altra versione richiede di aggiornare le costanti e i golden.

### R0. Limite prudente

Si usa l'estremo prudente di `ci95`: **superiore** per l'acuita, **inferiore** per il contrasto. Se il blocco e `doubtful` o `unreliable`: altri 0.1 verso il prudente (+0.1 logMAR per l'acuita, -0.1 logCS per il contrasto).

### R1. Dimensione del testo

```
s_target = acuity.ci95[1] + 0.4 (+ 0.1 se doubtful/unreliable) + userAdjustments.textSizeOffsetLogMAR
θ = 5' * 10^s_target            (altezza della x, convenzione MNREAD)
h_x = 400 mm * θ_rad
fontSizeCssPx = (h_x / r_x) * ppi / (25.4 * nativeScale)
```

- La riserva +0.4 e gia il margine sull'acuita (Whittaker e Lovie-Kitchin 1993: riserva >= 2:1). Il margine +0.1 "sopra la dimensione critica" si applica solo quando la base e la dimensione critica di stampa **misurata** (post-MVP).
- `fontSizeCssPx` e la dimensione **minima** del testo del corpo: `adapter.js` non riduce testo gia piu grande.
- Nessun caso speciale per la vista nella norma.

### R2. Impaginazione e spaziatura

- Per tutti (WCAG 1.4.12): `lineHeight` 1.5, `paragraphSpacingEm` 2, `letterSpacingEm` 0.12, `wordSpacingEm` 0.16, `align: "left"`.
- **Coinvolgimento centrale** in almeno un occhio: `lineHeight` 2, `letterSpacingEm` 0.18, `wordSpacingEm` 0.24.
- `layout.singleColumn = true` sempre quando il piano e attivo. `layout.mode = "normal"` sempre nell'MVP.
- **Lunghezza della riga** (indipendente dalla distanza):

```
R = max(right.fieldRadiusDeg, left.fieldRadiusDeg)
L_max_mm = 2 * 400 * tan(R) * 0.8
fontSize_mm = h_x / r_x
maxLineWidthCh = clamp(L_max_mm / (fontSize_mm * zeroWidthEm), 15, 60)
```

  Senza blocco `visualField`, o con `pattern = "none"` in entrambi gli occhi: 60.
- `adapter.js` spezza le parole lunghe (`overflow-wrap`, `hyphens`), cosi il testo non esce mai di lato.

### R3. Contrasto

`x` = `contrast.ci95[0]` (meno 0.1 se `doubtful`/`unreliable`).

| `x` | `minTextContrast` |
| --- | --- |
| x >= 1.65 | 4.5 |
| 1.5 <= x < 1.65 | 7 |
| 1.0 <= x < 1.5 | `12 - 10 * (x - 1.0)` |
| x < 1.0 | 15 |

`minUIContrast = max(3, minTextContrast * 3 / 4.5)`. `color.preserveHue = true`. L'algoritmo di correzione dei colori e in `adapter.js`.

### R4. Tema e luce

- `color.theme ∈ {"original", "light", "dark"}`. `"original"` mantiene i colori del sito; interviene solo R3.
- Senza blocco `light`: `theme = "original"`, `screen.brightness = null`.
- Con blocco `light`: `theme = preferredTheme`; se `preferredTheme` manca, `"dark"` se `photophobia`, altrimenti `"original"`. `screen.brightness = preferredBrightness` o `null`.
- `"dark"`: `background` `#121212`, `text` `#E8E6E3` (contrasto 15,04:1). `"light"`: bianco caldo scelto da Rocco, **ancora da definire**; il tema chiaro non compare nei golden MVP. `"original"`: `background` e `text` = `null`.
- `imageBrightness = 0.85` se `photophobia` o tema scuro, altrimenti 1 (0.85 e una scelta di design).

### R5-R8 e campi restanti

| Campo | Valore MVP |
| --- | --- |
| `layout.moveEdgeElements` | `true` se `visualField` presente con `pattern != "none"` in almeno un occhio |
| `text.fontFamily` | `"Atkinson Hyperlegible"` |
| `cleanup.removeCookieBanners`, `cleanup.stopAnimations`, `cleanup.useReadability` | `true` (per tutti; sulle pagine che non sono articoli `adapter.js` decide con `isProbablyReaderable`) |
| `controls.underlineLinks` | `true` |
| `controls.minTargetPt` | `clamp(44 * fontSizeCssPx / 16, 44, 64)` alla distanza di riferimento |
| `controls.focusOutlinePx` | 3 (scelta di design; WCAG 2.4.13 chiede almeno 2) |
| `speech.tapToSpeak`, `speech.rateWpm` | `false`, `null` |

## 10. Casi golden

**Struttura:**

```
shared/examples/
├── rules/<caso>/      profile.json, context.json, expected-plan.json, README.md
├── summary/<caso>/    input.json, expected.json, README.md
├── quest/<caso>/      trace.json (configurazione, osservatore scriptato, output attesi per passo), README.md
└── geometry/<caso>/   input.json, expected.json, README.md
```

`summary/` verifica le derivazioni del profilo (`summary`, categoria OMS, fascia di contrasto), che non passano dal piano. Ogni `README.md` contiene l'**oracolo manuale**: i valori chiave derivati a mano, con formula e numeri. Python deve riprodurli prima che il suo output diventi golden. I formati dei file sono descritti in `shared/examples/README.md`. Contesto dei casi `rules/`: 400 mm, 460 ppi, `nativeScale` 3.

Le tracce QUEST+ usano un osservatore senza casualita: `scripted` (risposte fissate) oppure `deterministicThreshold` (corretta se e solo se `x >= thresholdX`, con soglia fuori griglia e inversioni in prove elencate).

**Tier 1:**

- `rules/`: `mild-acuity`, `doubtful-acuity` (esattamente +0.1 logMAR rispetto al precedente), `low-contrast` (fascia 1.0-1.5), `tunnel-vision` (preset con raggio 5°, `maxLineWidthCh` limitato a 15), `central-loss` (preset Amsler con `centralInvolved`), `low-contrast-photophobia` (preset luce, tema scuro e R3).
- `quest/`: `tiny-hand-computed` (un passo del motore su una griglia minima, interamente calcolato a mano: stato `final`); `acuity-reaches-sd`, `acuity-max-trials`, `contrast-reaches-sd` (quest'ultimo deve convergere a un logCS plausibile, non allo speculare, per intercettare un segno invertito). Le tre tracce complete hanno output **`pending`**: li genera l'implementazione di riferimento dopo aver superato `tiny-hand-computed` e i controlli di plausibilita del README, poi si congelano con `status: final` in una PR condivisa.

**Tier 2 (parte dell'MVP):**

- `rules/`: `contrast-edge-1-65`, `contrast-edge-1-5`, `contrast-edge-1-0`, `doubtful-contrast` (lo spostamento di R0 porta esattamente a 1.0), `tunnel-vision-10deg` (formula di `maxLineWidthCh` senza limitazione), `near-normal` (vista nella norma, stima censurata, `minTargetPt` sotto il tetto), `user-offset`, `photophobia-no-preference`.
- `summary/`: `label-edges` (bordi delle categorie OMS e delle fasce), `normal-vision-edge` (`ci95[1]` = 0.3), `normal-vision-true` (contrasto esattamente 1.5), `normal-vision-field-defect`, `reliability-ignores-presets`, `all-preset` (`overallReliability = null`).
- `geometry/`: `angle-to-css-px` (incluso `nativeScale` 2.88), `admissible-acuity-stimuli` (400 mm / 460 ppi e 350 mm / 326 ppi), `contrast-letter-size` (incluso il limite di 8°).

## 11. Workspace Python (`backend/`)

- Nuove cartelle: `quest/` (motore unico), `geometry/`, `contract/` (caricamento di `parameters.json`, `devices.json`, schemi). `acuity/` e `contrast/` configurano il motore. Nessuna ristrutturazione delle cartelle esistenti.
- `backend/pyproject.toml`, `requires-python >= 3.12`, `backend/` come radice degli import (`pythonpath = ["."]` per pytest), ambiente virtuale in `backend/.venv` (gia escluso da `.gitignore`).
- Dipendenze: `numpy`, `jsonschema`, `pytest`; gruppo opzionale `[sim]` con `matplotlib`. `fontTools` non e una dipendenza.
- Comando: `cd backend; python -m pytest`. I test leggono `../shared/`.
- CI con GitHub Actions: proposta a Rocco, non per l'hackathon.

## 12. Simulazioni

- Osservatori virtuali con lo stesso modello logistico. Soglie vere su una griglia (acuita -0.2...1.5, contrasto 0.5...2.0), `beta` vero sui valori della griglia.
- Osservatori fuori modello: `beta = 4`, `lambda = 0.05`.
- Stimoli ammissibili dalla geometria a 40 cm con 460 e 326 ppi (limite dello schermo incluso).
- `numpy.random.default_rng(seed)` con seed registrato nei risultati; 500 esecuzioni per condizione.
- Misure: percentuale `reliable` (calibrazione di W), **copertura** di `ci95`, bias della mediana, distribuzione del numero di risposte.
- **Criteri fissati prima dei risultati:** copertura tra 90% e 98% per osservatori nel modello; |bias| della mediana <= 0.05 lontano dal limite dello schermo. Se falliscono, la correzione passa dal contratto (griglia, W, regola di stop), non dal solo Python.
- Output in `backend/simulation/output/`: CSV riassuntivo e grafici PNG. Si committano solo le figure per le slide.
- Ordine: dopo i golden tier 1+2 e dopo che il QUEST+ Python supera le tracce. Prima l'acuita, poi il contrasto se c'e tempo.

## 13. Deviazioni dalla specifica

| § spec | Cosa cambia | Perche | Q |
| --- | --- | --- | --- |
| 11 | Seed condiviso -> tracce scriptate senza casualita | lo stesso seed non da sequenze uguali tra linguaggi | Q7 |
| 11 | Tolleranza unica 0,001 -> 1e-9 relativa, 1e-6 sugli output, discreti esatti, spareggio | 0,001 nasconde bug reali; gli spareggi divergerebbero | Q8 |
| 11 | `fontSizePx` -> `fontSizeCssPx` a 400 mm con contesto `ppi`/`nativeScale` | la formula dava pixel fisici, 3 volte troppo grandi in CSS | Q2, Q11 |
| 7, 11 | Profilo tutto obbligatorio -> blocchi opzionali con `source` | i preset non devono inventare dati grezzi | Q3 |
| 4, 6 | "Intervallo di confidenza" non definito -> quantili a posteriori, stima = mediana | il posterior e troncato al limite dello schermo | Q4-bis |
| 5.1, 6 | Stop anche sulla certezza della categoria -> rimosso | parametri in piu, demo piu lunga sul confine 0,3 | Q6 |
| 6 | Affidabilita -> nell'MVP solo dalla larghezza di `ci95` | con pendenze basse il target SD e irraggiungibile | Q5-bis |
| 5.1 | "4-5 valori" di pendenza -> griglie esplicite; `slope` tolto dal profilo | pendenza non identificabile in 12-30 prove | Q12, Q15 |
| 4 | 25-60 cm -> 35-45 cm durante acuita e contrasto; censura | limite dello schermo e accomodazione | Q13 |
| 5.2 | Contrasto non definito -> Weber; lettera dal limite superiore + 0,6, massimo 8°; niente correzione per l'eta | definizione standard, lettera sempre nello schermo | Q14 |
| 5.2 | Formula con segno sbagliato per logCS -> variabile di facilita `log10 C` | con logCS la curva deve scendere | Q15 |
| 5.2, 8 | Fasce 1,5 e tabella R3 1,65 incoerenti -> quattro fasce comuni | un solo insieme di soglie | Q16 |
| 7 | `summary.level` a 4 valori "normale" -> `acuity.whoCategory` ICD-11 a 5 valori dalla mediana | nome, categorie e valore corretti | Q17 |
| 6 | "Non serve nessun adattamento" -> nessun caso speciale; `fontSizeCssPx` minimo | niente salto al confine 0,3; la frase della schermata va riscritta | Q10 |
| R1 | Riserva +0,4 **e** margine +0,1 -> solo +0,4 senza lettura misurata | prudenza doppia, poche lettere per riga | Q18 |
| R2 | Colonna unica se il testo supera 1,5 volte l'originale -> sempre; `mode` sempre `normal`; R9 post-MVP | l'originale non e noto quando si calcola il piano | Q19 |
| R2 | Lunghezza della riga in px -> in `ch`, raggio dell'occhio migliore; preset tunnel a 5° | indipendente dalla distanza; a 10° non si vede nulla | Q20 |
| R4 | Tema chiaro di default -> `"original"` senza test della luce; effetto della fotofobia definito | rispetta il sito, nessun colore inventato | Q21 |
| R3, R7 | Formule mancanti -> `minUIContrast`, `minTargetPt`, `focusOutlinePx` | valori necessari per i golden | Q16, Q22 |
| 11 | Cartelle golden -> `rules/`, `quest/`, `geometry/` con oracolo manuale | anche motore e geometria vanno verificati | Q9 |
| 5.4 | Amsler 10 x 10 "come la griglia clinica" -> "griglia centrale ridotta" (la clinica e 20 x 20) | verifica delle fonti; post-MVP | - |
| 5.3 | "Metodo di Cheung e altri" -> non attribuire il modello a due tratti a Cheung 2008 (usa un decadimento esponenziale) | verifica delle fonti; post-MVP | - |
| 5.6 | Bradley-Terry -> equivalente al conteggio delle vittorie con 6 confronti | verifica delle fonti; post-MVP | - |
| 9 | Occhiali +3/+4 per il giudice -> a 25-40 cm possono non ridurre l'acuita; servono +4/+5 a 40 cm o un filtro sfocante, mirando a una mediana di 0,3-0,4 | ottica della lente positiva | - |
| 10 | Riferimento MRF -> citare Vingrys 2016 per la tecnica | verifica delle fonti | - |

## 14. Approvazione di Rocco e azioni aperte

Approvati da Rocco il 2026-09-26: fascia 35-45 cm; E disegnata in modo nativo ai pixel del dispositivo; dithering e livelli di contrasto ammissibili come scelta di rendering iOS; `nativeScale` letto a runtime; viewport forzato da `adapter.js`; `fontSizeCssPx` come minimo; parole lunghe spezzate; font e `parameters.json` inclusi nell'app; `Codable` rigoroso; modello sconosciuto = test bloccato; preset tunnel a 5°.

Azioni aperte (Rocco, lato iOS):

- scegliere il bianco caldo del tema chiaro (`parameters.json` `rules.lightTheme`, oggi `null`);
- verificare con un `print` il valore di `nativeScale` con lo Zoom schermo attivo;
- verificare che la lettera del contrasto a 8° stia nello schermo nella fascia di test;
- tarare la sfocatura del giudice per la demo (mediana 0.3-0.4);
- riscrivere la frase della sezione 6 della specifica;
- valutare la proposta di CI con GitHub Actions.

## 15. Post-MVP

Test di lettura (dimensione critica di stampa, velocita, R1 con margine +0,1, R9 con velocita misurata), R9 e la sua isteresi in `adapter.js`, campo visivo completo (ZEST, matrice dei vicini, macchia cieca), Amsler, luce, affidabilita avanzata (verosimiglianza, tempi di risposta, errori su stimoli facili, coerenza tra test), R10.
