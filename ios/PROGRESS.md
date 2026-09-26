# IpoView: avanzamento

Ultimo aggiornamento: fasi 1–8 complete (tutto l'MVP e la roadmap), installate sull'iPhone 15. Installazione rapida: `./install.sh`.

## Come compilare e installare
```
xcodebuild -project hackaton.xcodeproj -scheme hackaton -destination 'generic/platform=iOS' -derivedDataPath /tmp/ipodd build
xcrun devicectl device install app --device 00008120-001825461A90A01E /tmp/ipodd/Build/Products/Debug-iphoneos/hackaton.app
```
Test unitari (simulatore): `xcodebuild test -project hackaton.xcodeproj -scheme hackaton -destination 'id=375CC539-598A-48D4-A751-5B9A6099D0A8'` → 13 test OK.

## Fase 1: base ✅
- ARKit face tracking a ~60 Hz, distanza occhi–fotocamera con filtro esponenziale (τ 0,15 s) — `Core/FaceDistanceTracker.swift`
- Tabella ppi per modello, conversioni angolo → mm → px → punti — `Core/Geometry.swift`
- Schermata iniziale con il solo pulsante "Avvia test", voce italiana, testo grande e contrasto alto di default.
- **Prova**: apri l'app → la voce ti accoglie; ingranaggio in alto per le impostazioni.

## Fase 2: acuità con QUEST+ ✅
- `Psychometrics/QuestPlus.swift`: funzione psicometrica (γ 0,25, λ 0,02), griglia soglia −0,3…1,8 passo 0,02 × 5 pendenze, Bayes, entropia attesa minima, stop (min 12, DS < 0,05 + categoria OMS certa al 95%, max 30).
- E ruotata, swipe nelle 4 direzioni, dimensioni ricalcolate alla distanza attuale, distanza e tempo registrati a ogni risposta, pausa automatica fuori 25–60 cm, pulsante Pausa.
- Pannello in basso con stima e intervallo al 95% che si restringe.
- Test unitari: `hackatonTests/QuestPlusTests.swift`.

## Fase 3: contrasto ✅
- Stesso motore; stimolo = log(1/C) di Weber su luminanza fisica (curva di gamma sRGB), tutti i 255 grigi a 8 bit (fino a ~2,05 log). Lettera = max(3°, 4× soglia di acuità).

## Fase 4: profilo, regole, browser ✅
- `Profile/VisualProfile.swift`, `AdaptationPlan.swift` come SPEC 11; `RulesEngine.swift` con R0, R1, R3 e anche R2, R4, R5, R7, R9 (solo formule).
- Browser WKWebView: barra indirizzo/ricerca Google, barra Liquid Glass in basso (indietro, avanti, ricarica, "Originale / Per me"), pagina iniziale con siti e 3 pagine salvate offline.
- `Resources/JS/adapter.js`: `IpoView.apply(plan)`, `setFontSizePx(px)`, `reset()`; font Atkinson iniettato; Readability.js; pulizia cookie/popup/pubblicità; contrasto WCAG; modalità un paragrafo alla volta (anche righe di tabella).
- Testo che segue la distanza in tempo reale (controllo ogni 100 ms, isteresi 8%, transizione 150 ms). Indicatore "cm · pt" in alto a destra.
- Profili di campo visivo predefiniti (tunnel 8°, perdita centrale) in Impostazioni.
- "Ecco come vedi" con valori, intervalli, affidabilità e spiegazione delle regole applicate.
- Modalità demo: Impostazioni → tocca 5 volte la riga "IpoView 1.0 …".

## Già presente in anticipo
- Affidabilità (SPEC 6) per acuità/contrasto: coerenza con la curva (z della log-verosimiglianza), errori su lettere facili, risposte troppo veloci, distanza variabile, coerenza tra test, "vista nella norma" con tutto l'intervallo al 95%.

## Fase 5: campo visivo ✅
- `Psychometrics/ZestField.swift`: griglia ogni 6° (±3…±21 × ±3, ±9; demo più piccola), screening a difficoltà 4, ZEST per punto (priore misto, stop DS < 1 o 4 presentazioni), matrice W = e^(−d²/2σ²) con σ = 6° che sposta i priori dei vicini, punto successivo = incertezza massima.
- Macchia cieca localizzata all'inizio con 5 stimoli forti, poi prove trappola nel 10% (solo nel quadrante dove è sullo schermo); falsi positivi (prove senza stimolo + tocchi < 150 ms); falsi negativi (stimolo forte dove si era visto uno debole); criteri Humphrey.
- `Tests/FieldTestView.swift`: telefono in orizzontale (fotocamera a sinistra), 4 sessioni con la fissazione negli angoli, pallino 0,43° per 200 ms, finestra 1,5 s, intervallo casuale, 10 livelli di contrasto su fondo grigio.
- Mappa di calore per occhio in "Ecco come vedi" (interpolazione per distanza inversa), con macchia cieca e indici di affidabilità.
- Test unitari: `hackatonTests/ZestFieldTests.swift` (18 test in totale, tutti OK).

## Fase 6: Amsler, luce, regole R2 R4 R5 R6 R7 R9 ✅
- `Tests/AmslerTestView.swift`: 10 × 10 quadretti da 1° alla distanza misurata, due passaggi (storte → arancione, mancanti → nero), occhio destro poi sinistro; aree in gradi², 2° centrali, baricentro.
- `Tests/LightTestView.swift`: 4 versioni (chiaro/scuro × luminosità alta/bassa), 6 confronti a coppie, domanda sul fastidio; Bradley-Terry con algoritmo MM; luce ambiente ARKit registrata.
- Ordine del test: acuità, contrasto, Amsler, campo visivo, luce ("test n di 5").
- Regole in `RulesEngine.swift` (R2 spaziature/colonna/L_max dal campo, R4 tema e luminosità, R5 bordi e un paragrafo alla volta, R6 pulizia, R7 link e aree di tocco, R9 lettura grande con voce) e in `adapter.js`.
- Test unitari: `hackatonTests/Phase6Tests.swift` (24 test in totale, tutti OK).

## Fase 7: affidabilità e vista nella norma ✅
- Prove di controllo facili (1 ogni 5) in acuità e contrasto; coerenza con la curva (z), errori su stimoli facili (> 20%), tempi di risposta (correlazione con la distanza dalla soglia, errori velocissimi), distanza variabile, coerenza tra test, criteri Humphrey del campo visivo con i motivi.
- Stop che dipende anche dalla categoria (95%); "vista nella norma" solo con tutto l'intervallo nella fascia normale → messaggio dedicato e browser su "Originale".
- Giudizio per test e complessivo con i motivi in "Ecco come vedi"; se non affidabile, pulsante "Ripeti il test".
- Test unitari: `hackatonTests/ReliabilityTests.swift` (28 test in totale, tutti OK).

## Fase 8: lettura ✅
- `Tests/ReadingEngine.swift`: 30 frasi italiane (~60 caratteri, ~10 parole), riconoscimento vocale italiano sul telefono, Levenshtein sulle parole, parole/min, curva a due tratti → dimensione critica, velocità massima, acuità di lettura.
- `Tests/ReadingTestView.swift`: permessi microfono/voce chiesti solo qui, spiegati a voce; tocco di riserva; "Non riesco a leggerla".
- Ordine completo: acuità, contrasto, lettura, Amsler, campo visivo, luce ("test n di 6"). La dimensione critica diventa la base di R1.
- Test unitari: `hackatonTests/ReadingTests.swift` (31 test in totale, tutti OK).

## Modalità demo (~3 minuti)
Impostazioni → tocca 5 volte la riga della versione → "Test accorciati". Passi: acuità, contrasto, lettura (6 frasi), luce. Il campo visivo si mostra scegliendo un profilo predefinito.

## Limiti noti
- R1 della SPEC (lato prudente + 0,4 + 0,1) produce testo molto grande con acuità ridotta → spesso scatta la lettura grande (R9). Si corregge con "Testo più piccolo" (R10).
- Il riconoscimento vocale soffre il rumore: la demo va fatta in un posto tranquillo, oppure si usa il tocco.
- Le prove trappola della macchia cieca ci sono solo nella sessione del quadrante che la contiene.
- Non provato da me sul telefono reale: solo compilazione, test unitari e simulatore.
