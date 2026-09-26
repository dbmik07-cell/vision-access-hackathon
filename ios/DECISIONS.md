# Decisioni prese dove SPEC.md non era esplicita

Regola: la soluzione più semplice coerente con SPEC.md.

## Piattaforma e progetto
- **Target**: iOS 26.0, SDK iOS 27, solo iPhone (`TARGETED_DEVICE_FAMILY = 1`), solo verticale. Signing non toccato.
- **Volume ExFAT**: macOS crea file `._*`; aggiunto `EXCLUDED_SOURCE_FILE_NAMES = "._*"` perché il gruppo sincronizzato di Xcode non li compili.
- **Test unitari**: target `hackatonTests` (Swift Testing) + schema condiviso. Girano nel simulatore (`xcodebuild test`), dove la TrueDepth non c'è: nel simulatore la distanza è fissa a 40 cm.
- **Struttura**: SPEC 11 descrive un repo `ios/ backend/ shared/`; qui lavoriamo nel progetto Xcode esistente (`hackaton/`). Il contratto del piano è in `docs/adaptation-plan-contract.md`.

## Distanza e geometria
- **Distanza** = punto medio tra i due occhi (ARKit `leftEyeTransform`/`rightEyeTransform`) → posizione della fotocamera. La fotocamera è in cima allo schermo, non al centro: differenza di 1-2 cm a 35 cm, trascurata.
- **Filtro**: media mobile esponenziale con costante di tempo 0,15 s (α = 1 − e^(−Δt/τ)).
- **Viso perso** per più di 0,5 s → "non vedo il tuo viso", test in pausa.
- **ppi**: tabella per identificatore di modello; modelli sconosciuti = 460 ppi. Pixel fisici per punto = `nativeScale` (2,88 sui mini).
- **h = d·θ** (piccoli angoli) come in SPEC, anche per angoli di qualche grado.

## QUEST+
- **Pendenze**: {4, 8, 15, 25, 40} per unità logaritmica, uguali per acuità e contrasto.
- **Priore uniforme** su soglia e pendenza.
- **Intervallo al 95%**: intervallo di credibilità bayesiano, quantili 2,5% e 97,5% della marginale della soglia.
- **Dimensioni possibili (acuità)**: griglia −0,3…1,8 passo 0,02 filtrata (tratto ≥ 2 px, lettera ≤ 80% della larghezza dello schermo). Tratti non interi (antialiasing) ammessi.
- **logMAR effettivo**: la risposta aggiorna QUEST+ con il logMAR ricalcolato dalla dimensione mostrata e dalla distanza **all'istante della risposta** (non quello scelto al momento della presentazione).
- **Stop acuità**: min 12, max 30; stop quando DS < 0,05 **e** la categoria OMS è certa al 95% (SPEC 5.1 + 6). In pratica chi è vicino a un confine arriva a 30.
- **Stop contrasto**: min 10 (non in SPEC), max 30, DS < 0,08 e categoria (confini 1,0 e 1,5) certa al 95%.
- **Demo**: acuità 8–16 risposte (DS 0,08, solo confine 0,3); contrasto 8–14 (DS 0,12, solo confine 1,5).
- **Calcolo dello stimolo successivo** fuori dal thread principale, durante la pausa di 350 ms tra le lettere.

## Contrasto
- **Contrasto di Weber** su fondo bianco: C = 1 − L(lettera), con L dalla curva di gamma sRGB. Gli stimoli possibili sono i 255 grigi a 8 bit (log 1/C da 0 a ~2,05).
- **Lettera**: max(logMAR 1,556 = 3°, acuità + 0,602 = 4× la soglia), limitata all'80% della larghezza dello schermo.
- **Luminosità schermo** fissata all'80% durante i test, ripristinata alla fine. True Tone / Night Shift non si possono disattivare da app: va detto.

## Regole (R0–R10)
- **Senza nessun test** il browser "Per me" usa acuità 0,2 logMAR (lato leggibile).
- **R1**: altezza della x = 5′·10^s (convenzione MNREAD), r_x = 0,496 (sxHeight 496 / unitsPerEm 1000 di Atkinson Hyperlegible). px CSS = punti iOS (viewport forzato a device-width).
- **R0 "dubbio"**: +0,1 logMAR (acuità, dimensione critica) o −0,1 log (contrasto) anche per "non affidabile" quando il valore viene comunque usato.
- **R2**: "testo più grande di 1,5 volte l'originale" = oltre 24 px (originale di riferimento 16 px). Larghezza media carattere 0,55 em.
- **R4 senza test della luce**: tema "chiaro" (bianco caldo) se il livello non è normale o il contrasto è ridotto, altrimenti "originale".
- **R7**: area di tocco = 44 · font/17 punti, tra 44 e 64.
- **R9**: meno di 12 caratteri per riga → "lettura-grande". Velocità della voce: velocità massima di lettura misurata, altrimenti 140 parole/min.
- Tutte le regole sono calcolate già dalla fase 4 (sono solo formule), così i profili predefiniti di campo visivo mostrano subito R2/R5.

## Interfaccia
- **Avvio**: senza profilo → schermata "Avvia test"; con profilo → direttamente il browser.
- **Dimensione UI per livello**: nessun profilo → Dynamic Type accessibility1 e contrasto alto; normale → large/xxLarge; lieve → xxxLarge; moderato → accessibility2; grave → accessibility3. Tema scuro se il test della luce lo preferisce.
- **Modalità demo nascosta**: Impostazioni → toccare 5 volte la riga della versione.
- **Profili predefiniti**: "Visione a tunnel (8°)" e "Perdita centrale" (con Amsler coerente), in Impostazioni. Si sovrappongono al profilo misurato.
- **Indicatore "cm · pt"** in alto a destra nel browser adattato, per il momento tecnico della demo.
- **Voce**: AVSpeechSynthesizer it-IT con la voce di qualità migliore installata; categoria audio `.playback` per parlare anche col silenzioso.

## Campo visivo
- **Telefono in orizzontale** (fotocamera a sinistra, tela ruotata di 90° nell'app solo verticale): in verticale a 25 cm lo schermo dell'iPhone 15 (65 mm) copre meno di 15° per lato e la macchia cieca (15°) non ci sta. In orizzontale (141 mm) si arriva a ~29° orizzontali e ~14° verticali per quadrante.
- **Griglia**: x ∈ ±3, ±9, ±15, ±21; y ∈ ±3, ±9 (32 punti); demo: x fino a ±15, y ±3 (12 punti). I punti che alla distanza attuale non entrano nello schermo vengono saltati.
- **Scala**: sensibilità 0–10 = livello di difficoltà più alto visto; P(visto) con fp = fn = 3%, pendenza 2. Priore: 85% gaussiana (media 8, DS 2) + 15% uniforme.
- **Neighbor matrix**: quando un punto termina, prior_j ← (1−W)·prior_j + W·posteriore_i per i punti non ancora misurati con ZEST (l'eventuale risposta dello screening viene riapplicata).
- **Fase 2 per quadrante**: vicini = W > 0,3 (entro ~9°) nello stesso quadrante (serve la stessa fissazione).
- **Prove trappola della macchia cieca** solo nella sessione del quadrante che la contiene (altrove non è sullo schermo).
- **Nella norma**: difetti (sensibilità < attesa − 3) non oltre l'8% dei punti (minimo 1). Raggio del campo = eccentricità del primo punto difettoso − 3°.
- Senza macchia cieca trovata il test è "dubbio".

## Affidabilità (fase 7)
- **Prove di controllo**: una lettera ogni 5 (dalla 5ª) è facile, 0,4 unità sopra la stima; aggiornano comunque QUEST+. Senza queste QUEST+ non mostra quasi mai lettere grandi e chi finge non si scopre. Con ~6 prove di controllo per test la scoperta è probabilistica: un finto utente che sbaglia a caso la metà delle lettere grandi può passare; uno che le sbaglia quasi tutte viene segnalato.
- **Coerenza con il modello**: z = (log-verosimiglianza osservata − attesa)/√varianza, alla stima a posteriori; z < −2 → dubbio, z < −3 → non affidabile.
- **Tempi di risposta**: correlazione di Pearson tra tempo e |stimolo − soglia| > 0,4 (più lenti sulle facili) → segnalato; errori < 400 ms su lettere facili (≥ 2) → segnalato.
- **Giudizio**: 0 segnalazioni affidabile, 1-2 dubbio, ≥ 3 o z < −3 non affidabile. Complessivo = il peggiore; coerenza tra test (acuità < 0,1 con contrasto < 1,0) → almeno dubbio.
- **Vista nella norma**: il browser parte su "Originale" (nessun adattamento), "Per me" resta disponibile.

## Lettura (fase 8)
- **Dimensione di stampa**: altezza della x = 5′·10^s (MNREAD), stessa formula di R1; si parte da acuità + 0,5 logMAR, limitata alla dimensione più grande con almeno 14 caratteri per riga; passi di 0,1.
- **Stop**: "Non riesco a leggerla", meno di metà delle parole giuste, meno di 15 parole/min, 16 frasi (6 in demo).
- **Fine della frase**: l'ultima parola della frase compare tra le ultime 3 parole riconosciute (riconoscimento sul telefono, `requiresOnDeviceRecognition`), oppure tocco. Senza riconoscimento sul telefono (o senza permessi) si usa solo il tocco e tutte le parole si considerano corrette (segnalato come "dubbio").
- **Curva a due tratti**: log10(velocità) piatto per s ≥ b, retta in discesa sotto; b = punto di rottura con errore quadratico minimo tra le dimensioni misurate (a parità, il più piccolo). Intervallo della dimensione critica = ±0,1 (un passo). Misurato solo con almeno 3 frasi lette.
- **Acuità di lettura**: dimensione più piccola letta con almeno metà delle parole giuste.

## Modalità demo
- Passi: acuità, contrasto, lettura (6 frasi), luce (~3 minuti). Amsler e campo visivo si mostrano con i profili predefiniti (Impostazioni), come nel copione della demo in SPEC 9.

## Allineamento al contratto dati di Michele (docs/data-contracts.md, v1.0) — prevale su SPEC.md
- **Costanti**: `shared/parameters.json` e `shared/devices.json` sono inclusi nel bundle come riferimenti ai file di `shared/` (nessuna copia, voce "shared" nel progetto Xcode) e letti a runtime da `hackaton/Contract/ContractParameters.swift` (`SharedContract`). Unica costante rimasta nel codice: il raggio del preset tunnel (5°), che non è in parameters.json. Modello assente da devices.json → il test non parte. Il font incluso ha lo SHA-256 indicato in parameters.json.
- **Tema chiaro**: `rules.lightTheme` è ancora `null` in parameters.json → l'app usa la proposta #FAF7F0 / #1A1A1A finché il valore non viene scritto nel file condiviso (modifica di shared/ da concordare con Michele).
- **QUEST+**: variabile di facilità (contrasto: x = log10 C di Weber in [−2,1, 0], logCS = −t con estremi di ci95 scambiati solo nel profilo); β acuità {6,10,15,24,35}, contrasto {5,7,10,14,20}; stima = mediana; ci95 con quantili a bin; spareggio all'indice più basso entro 1e-12; stop (n ≥ 12 e SD < obiettivo) o n = 30, senza la regola della categoria; affidabilità = larghezza di ci95 ≤ 0,30 (altrimenti doubtful + wideInterval), maxTrialsReached informativo.
- **Stimoli ammissibili del contrasto**: i grigi a 8 bit mostrati davvero (senza dithering), non la griglia continua. Per l'acuità: la griglia di t filtrata (tratto ≥ 2 px del dispositivo, lettera nel lato corto dello schermo).
- **Distanza alla risposta**: QUEST+ si aggiorna con il logMAR ricalcolato alla distanza dell'istante della risposta (non sempre un punto della griglia): più corretto fisicamente, fuori dalle tracce scriptate.
- **Fascia di test** 35–45 cm per acuità e contrasto (pausa fuori fascia); 25–60 cm per gli altri test.
- **Limite dello schermo**: oltre alla censura del contratto (displayLimitLogMAR, censoredAtDisplayLimit, ceilingLogCS, censoredAtCeiling), stop anticipato dopo 3 risposte giuste di fila allo stimolo più difficile disegnabile; stop dopo 3 mancate allo stimolo più facile → ci95 alto = 1,8 (acuità) o [0, …] (contrasto): adattamento al massimo. Messaggi nei risultati.
- **Gesto "non vedo"**: tocco con due dita = risposta sbagliata, con conferma vocale.
- **Prove di controllo facili** (fase 7) disattivate: affidabilità avanzata post-MVP. I controlli avanzati restano solo come note informative nei risultati ("diagnostics"), fuori dal VisualProfile e senza effetto sul piano.
- **Lettera del contrasto**: max(3°, 5′·10^(ci95 alto + 0,6)), massimo 8°, flag contrastLetterSizeCapped.
- **Profilo**: nomi e valori delle sezioni 8; blocchi opzionali con source; reliability in inglese; whoCategory, band; summary.overallReliability null se nulla è misurato. La lettura (riservata nel contratto) usa i campi dell'app. `Codable` non rifiuta i campi sconosciuti (decodifica non rigorosa: da fare quando gli schemi saranno definitivi).
- **Profilo di partenza senza test** (serve un profilo completo per applicare i preset): acuità preset 0,0 [−0,1, 0,1], contrasto preset 1,8 [1,7, 1,9].
- **Piano**: R0–R8 della sezione 9; fontSizeCssPx a 400 mm, riscalata per d/400 a runtime; righe in ch (zeroWidthEm 0,648 dal glifo "0" di Atkinson Hyperlegible 1.006); tema "original" senza test della luce; tema chiaro #FAF7F0 / #1A1A1A; preset tunnel 5°; perdita centrale = Amsler preset con centralInvolved.
- **Estensioni post-MVP** (interruttore in Impostazioni, attivo di default): sopra il piano del contratto, R5 "un paragrafo alla volta" con campo < 10° e R9 "lettura grande" con meno di 12 caratteri per riga. Il piano del contratto (e i golden) restano con mode "normal"; l'estensione modifica solo la copia inviata ad adapter.js.
- **Casi golden**: `hackatonTests/GoldenTests.swift` legge direttamente `shared/examples/` (rules, summary, geometry, quest) con le tolleranze della sezione 4 e verifica anche il giro completo del profilo (Codable rigoroso). Le tracce QUEST+ "pending" si eseguono solo come controlli di plausibilità; `acuity-max-trials` si ferma a 18 prove (mediana ≈ 1,23) invece di 30: segnato come problema noto da rivedere nel contratto, come prevede il suo README.
- **FieldPoint**: nel JSON le coordinate si chiamano `xDeg` e `yDeg` (sezione 8).
