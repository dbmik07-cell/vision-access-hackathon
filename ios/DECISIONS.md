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
