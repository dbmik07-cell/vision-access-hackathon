# IpoView: specifica completa

Sep 26, 2026 · @rocco

## 1. Panoramica

IpoView è un browser per iPhone che misura come vedi con un test di circa 6-10 minuti e poi adatta ogni pagina web ai tuoi occhi. La parte centrale e più tecnica è il test: metodi statistici presi dalla ricerca clinica, con la distanza dal viso misurata dalla TrueDepth a ogni risposta.

**Frase del pitch:** "Misuriamo come vedi, e ogni pagina web si adatta ai tuoi occhi."

**Per chi.** Persone ipovedenti che conoscono già la propria condizione (maculopatia, glaucoma, retinite pigmentosa, cataratta), non persone cieche. Molte sono anziane. Sanno cosa hanno, ma non sanno quanto è compromessa ciascuna dimensione della vista, né come tradurlo in impostazioni.

**Il problema.** I siti sono pensati per chi vede bene. Le impostazioni di accessibilità di iOS esistono, ma sono sparse, tecniche e uguali per tutti. Nessuno ti dice quali ti servono e quanto.

**Impatto.** Circa 440 milioni di persone nel mondo hanno un deficit visivo, e circa la metà sono ipovedenti (Bourne e altri, 2017, citato in Hoogsteen e Szpiro, 2023). Il numero cresce con l'invecchiamento della popolazione.

**Cosa esiste già e cosa manca.**

| Cosa esiste | Limite |
| --- | --- |
| Estensioni per ipovedenti (es. Vision Aid per Chrome) | impostazioni scelte a mano, nessun test, l'impaginazione resta com'è |
| Overlay di accessibilità (accessiBe, UserWay) | li installa il sito, profili generici, pessima reputazione nella comunità |
| Modalità lettura (Safari Reader) | uguale per tutti |
| Ricerca accademica (Bonavero e altri, 2015) | adatta solo i colori; il profilo utente è inserito a mano e l'impaginazione non si tocca |
| Distanza dallo schermo in iOS | serve solo ad avvisare che sei troppo vicino |

Nessun prodotto misura la vista funzionale e poi adatta le pagine in automatico, tenendo conto anche della distanza. Il paper del 2015 lo indica esplicitamente come lavoro futuro.

## 2. Piattaforma e scelte di base

IpoView è un'app solo per iPhone con Face ID, cioè dall'iPhone X in poi, esclusi gli iPhone SE. Tutti questi modelli hanno la fotocamera TrueDepth, che misura la distanza del viso senza bisogno di calibrazione.

| Scelta | Decisione | Motivo |
| --- | --- | --- |
| Dispositivo | solo iPhone con Face ID | la TrueDepth misura la distanza con precisione; l'iPad Air non ce l'ha |
| Calibrazione | nessuna | la TrueDepth non ne ha bisogno |
| Linguaggio | Swift e SwiftUI, grafica Liquid Glass | nativo iOS |
| Distanza dal viso | ARKit, tracciamento del viso, circa 60 volte al secondo | usata in ogni calcolo |
| Browser | WKWebView (motore WebKit, lo stesso di Safari e di Chrome per iOS) | carica qualsiasi sito, Google compreso; permette di inserire CSS e JavaScript in ogni pagina |
| Da evitare | SFSafariViewController | non permette di modificare le pagine |
| Account e login | nessuno | il profilo resta sul telefono |
| Font nelle pagine | Atkinson Hyperlegible | disegnato dal Braille Institute per ipovedenti, gratuito e open source |
| Struttura delle pagine | solo Readability.js (Mozilla), offline; nessuna AI a runtime | vedi R8 |

**Limite noto.** Lo schermo dell'iPhone è piccolo per il campo visivo. Con il punto da fissare negli angoli si arriva a circa 25-30 gradi, di più sui modelli Pro Max. Basta per la visione a tunnel della retinite pigmentosa; per i primi danni del glaucoma, che stanno più in periferia, è al limite. Lo diciamo apertamente.

## 3. Percorso dell'utente

L'app si apre con un solo pulsante, "Avvia test". Il test completo parte subito, e alla fine sia l'app sia le pagine web si adattano al profilo.

1. **Prima schermata.** Un pulsante grande "Avvia test" che occupa quasi tutto lo schermo. Una voce spiega cosa fare. Niente testi lunghi.
2. **Permessi al momento giusto.** Fotocamera quando parte il test; microfono e riconoscimento vocale solo prima del test di lettura. Ogni richiesta viene spiegata a voce un attimo prima.
3. **Preparazione (circa 20 secondi).** "Tieni il telefono come quando leggi, con i tuoi soliti occhiali." La TrueDepth controlla la distanza e la voce guida.
4. **Test completo, in quest'ordine:**
   1. acuità, a due occhi;
   2. contrasto, a due occhi;
   3. lettura, a due occhi;
   4. Amsler, occhio destro poi sinistro;
   5. campo visivo, prima screening poi approfondimento, occhio destro poi sinistro;
   6. luce.
5. **Risultati.** Schermata "Ecco come vedi": i valori spiegati in parole semplici, con l'affidabilità del test.
6. **Navigazione.** Da qui IpoView è un browser che si usa ogni giorno.
7. **Nel tempo.** Il test si può ripetere. Promemoria ogni 3 mesi e avviso se un valore peggiora (R10).

**Perché quest'ordine.** Prima tutti i test a due occhi, poi quelli con un occhio coperto, così la persona si copre l'occhio una volta sola per blocco. La lettura viene dopo l'acuità perché parte da una dimensione scelta in base al risultato, e il contrasto usa l'acuità per scegliere la dimensione della lettera.

**Durante il test.** Breve pausa tra un test e l'altro, con la voce che dice "test 3 di 6". Pausa possibile in qualsiasi momento.

**Leggibile fin dall'inizio.** Chi apre l'app per la prima volta vede male per definizione, quindi di default l'app parte con testo grande, contrasto alto e voce attiva.

**Alla fine del test l'app cambia.** Dimensione, contrasto e tema dell'interfaccia dell'app si adattano al profilo, non solo le pagine web.

**Durata.** Chi vede bene finisce in circa 6 minuti; chi ha zone cieche nel campo visivo arriva a circa 10. Una modalità demo nascosta nelle impostazioni accorcia tutto a circa 3 minuti.

## 4. Fondamenta comuni a tutti i test

Ogni misura viene calcolata in angolo visivo, usando la distanza reale del viso nel momento della risposta. È questo che rende il test valido anche se la persona si muove.

**Distanza a ogni risposta.** ARKit con la TrueDepth traccia il viso circa 60 volte al secondo. A ogni risposta si registra la distanza di quell'istante e la si usa nei calcoli. Se la persona esce dall'intervallo 25-60 cm il test va in pausa e la voce la guida ("avvicina un po'").

**Dall'angolo ai pixel.**

```latex
h_{mm} = d_{mm} \cdot \theta_{rad} \qquad px = h_{mm} \cdot \frac{ppi}{25{,}4}
```

Il primo passo converte l'angolo visivo in millimetri alla distanza misurata; il secondo converte i millimetri in pixel. iOS non fornisce la densità dello schermo (ppi), quindi serve una tabella per modello di iPhone.

**Scala logMAR.** È la scala clinica dell'acuità: 0 = vista normale, valori più alti = serve una lettera più grande; ogni 0,1 corrisponde a una riga della tabella dell'oculista (lettera circa il 26% più grande). Una E a logMAR 0 è alta 5 minuti d'arco, con tratti di 1 minuto d'arco.

**Condizioni controllate.** Luminosità dello schermo fissa durante il test. Luce ambiente registrata con la stima di ARKit: se la stanza è troppo buia o troppo luminosa, l'app lo segnala.

**Voce e gesti grandi.** Istruzioni sempre lette ad alta voce. Risposte con uno swipe nelle quattro direzioni o con un tocco ovunque sullo schermo. Niente pulsanti piccoli.

**Scelta forzata.** Se la persona non è sicura, tira a indovinare. Serve alla statistica, perché il modello tiene conto della probabilità di indovinare. Va detto chiaramente nelle istruzioni.

**Prima screening, poi approfondimento.** Dove possibile, ogni test fa prima una verifica rapida e approfondisce solo dove trova un problema, come fanno i perimetri clinici. Chi vede bene finisce in fretta; chi ha un problema viene misurato con precisione proprio lì.

**Nel dubbio, più leggibile.** Ogni risultato ha un intervallo di confidenza. Per adattare le pagine si usa il lato prudente dell'intervallo, non la stima centrale (R0).

## 5. I sei test

Ogni test stima una soglia con un metodo bayesiano adattivo e restituisce un valore con intervallo di confidenza. Il campo visivo aggiunge una matrice che collega i punti vicini.

| # | Test | Occhi | Metodo | Durata |
| --- | --- | --- | --- | --- |
| 1 | Acuità | entrambi | QUEST+ su soglia e pendenza | 1-1,5 min |
| 2 | Contrasto | entrambi | QUEST+ | circa 1 min |
| 3 | Lettura | entrambi | ispirato a MNREAD, curva a due tratti | circa 2 min |
| 4 | Amsler | uno alla volta | mappa a griglia di 1 grado per cella | circa 30 s per occhio |
| 5 | Campo visivo | uno alla volta | screening + ZEST per punto + matrice dei vicini + macchia cieca | 1-3 min per occhio |
| 6 | Luce | entrambi | confronti a coppie, modello di Bradley-Terry | circa 30 s |

### 5.1 Acuità visiva

**Cosa vede la persona.** Una E nera su bianco, girata in una delle quattro direzioni. Scorre il dito verso il lato in cui sono aperte le "gambe" della E. Con i suoi occhiali abituali.

**Modello: funzione psicometrica.** Probabilità di rispondere giusto a una lettera di dimensione s:

```latex
P(\text{giusta} \mid s) = \gamma + (1 - \gamma - \lambda) \cdot \frac{1}{1 + e^{-\beta (s - t)}}
```

- s: dimensione della lettera in logMAR;
- t: soglia della persona, da stimare;
- β: pendenza, quanto è netto il passaggio da "vedo" a "non vedo", da stimare;
- γ = 0,25: probabilità di indovinare con 4 direzioni;
- λ = 0,02: errori da distrazione su lettere chiaramente visibili.

**Algoritmo: QUEST+** (Watson, 2017).

- Griglia di ipotesi su soglia (da −0,3 a 1,8 logMAR, passo 0,02) e pendenza (4-5 valori), ognuna con una probabilità.
- A ogni risposta le probabilità si aggiornano con la formula di Bayes.
- La lettera successiva è quella che minimizza l'entropia attesa, cioè quella che insegna di più.
- Dimensioni possibili ricalcolate in tempo reale alla distanza attuale: tratto della E di almeno 2 pixel, lettera interamente nello schermo.
- Stop: deviazione standard della soglia sotto 0,05 logMAR (mezza riga), oppure 30 risposte; mai prima di 12. Si continua anche finché la categoria non è certa al 95% (sezione 6).

**Risultato.** Soglia in logMAR con intervallo al 95%; equivalente in decimi e Snellen (6/x); categoria secondo le fasce OMS.

| Categoria OMS | logMAR | Snellen |
| --- | --- | --- |
| Normale | fino a 0,3 | 6/12 o meglio |
| Lieve | oltre 0,3 | peggio di 6/12 |
| Moderata | oltre 0,48 | peggio di 6/18 |
| Grave | oltre 1,0 | peggio di 6/60 |
| Cecità | oltre 1,3 | peggio di 3/60 |

Le fasce OMS si riferiscono alla visione da lontano, mentre il test misura quella da vicino: va detto.

**In una frase:** "A ogni risposta il test aggiorna quanto è sicuro della tua soglia e sceglie la lettera che gli insegna di più."

### 5.2 Sensibilità al contrasto

**Cosa vede la persona.** La stessa E con lo stesso gesto, di dimensione fissa, mentre il colore sbiadisce dal nero verso il bianco.

**Dimensione della lettera.** Il valore più grande tra circa 3 gradi (come la tabella Pelli-Robson) e 4 volte la soglia di acuità misurata. Così chi ha un'acuità molto bassa non sbaglia per la dimensione, e il test misura davvero il contrasto.

**Colore corretto.** Il contrasto si calcola sulla luminosità fisica, non sul valore del colore. La luminosità desiderata viene convertita in valore sRGB con la curva di gamma. Con 8 bit per canale si arriva a circa 2,0 unità logaritmiche, sufficiente per l'intervallo che interessa.

**Algoritmo.** QUEST+ sul logaritmo della sensibilità al contrasto, da 0 a 2,1. Stop con deviazione standard sotto 0,08, oppure 30 risposte.

**Risultato e fasce.** Normale da 1,5 in su (con correzione per l'età: dopo i 60 anni scende un po'); ridotta tra 1,0 e 1,5; molto ridotta sotto 1,0.

**In una frase:** "Misuriamo il contrasto sulla luce che esce davvero dallo schermo, con lettere abbastanza grandi da non confonderlo con l'acuità."

### 5.3 Lettura

Misura direttamente la dimensione di testo a cui la persona legge alla sua velocità massima, invece di stimarla dall'acuità. Si ispira al MNREAD (Legge e colleghi), lo standard per la lettura negli ipovedenti.

**Cosa vede la persona.** Una frase semplice su tre righe; la legge ad alta voce il più veloce possibile. Frase dopo frase, il testo rimpicciolisce.

- **Frasi:** una trentina di frasi italiane da circa 60 caratteri e 10 parole, con parole comuni. Una frase nuova per ogni dimensione.
- **Dimensioni:** si parte da una dimensione scelta in base all'acuità e si scende a passi di 0,1 logMAR, calcolati alla distanza del momento. Stop quando la persona non riesce più a leggere.
- **Misura del tempo:** parte alla comparsa della frase; si ferma all'ultima parola, rilevata dal riconoscimento vocale in italiano, offline. Riserva: un tocco sullo schermo quando ha finito.
- **Errori:** trascrizione confrontata con la frase parola per parola (distanza di Levenshtein sulle parole).
- **Velocità:** parole corrette × 60 ÷ secondi, cioè parole al minuto.
- **Analisi:** curva a due tratti adattata ai dati, piatta per le dimensioni grandi e poi in discesa. Il punto in cui inizia a scendere è la dimensione critica di stampa. Approssimazione pratica del metodo di Cheung, Kallie, Legge e Cheong (2008).

**Risultato.** Velocità massima di lettura, dimensione critica di stampa (è la base di R1), acuità di lettura.

**Rischio.** Il rumore di fondo disturba il riconoscimento vocale: per questo c'è il tocco di riserva, e la demo va fatta in un posto tranquillo.

**In una frase:** "Non indoviniamo quanto ingrandire il testo: misuriamo la dimensione a cui leggi alla tua velocità massima."

### 5.4 Griglia di Amsler

**Cosa vede la persona.** Un occhio alla volta, l'altro coperto. Una griglia con un punto al centro. Primo passaggio: "Guarda il punto e passa il dito dove le linee sono storte." Secondo passaggio: "Passa il dito dove le linee mancano o sono sfocate." Se la griglia risulta pulita, si passa subito all'altro occhio.

**Dimensioni.** Ogni quadretto occupa esattamente 1 grado alla distanza misurata, come la griglia clinica. La griglia copre i 10 gradi centrali, la zona colpita dalla maculopatia.

**Risultato.** Matrice 10 × 10, ogni cella normale, distorta o mancante. Da questa: area distorta e area mancante in gradi quadrati; coinvolgimento dei 2 gradi centrali (quelli che contano di più per leggere); distanza e direzione della zona dal centro.

**In una frase:** "Ogni quadretto è grande esattamente un grado nel tuo occhio, quindi la mappa della zona danneggiata è in unità reali."

### 5.5 Campo visivo (il test più tecnico)

**Cosa vede la persona.** Un occhio alla volta, a circa 25 cm, sfondo grigio, un punto da fissare. Compaiono per un attimo dei pallini più chiari; lei tocca lo schermo ovunque quando ne vede uno.

**Allargare il campo.** Il punto da fissare non sta al centro: il test si divide in sessioni con il punto in angoli diversi dello schermo. Fissando l'angolo in basso a sinistra, lo schermo copre la zona in alto a destra del campo visivo. È la tecnica del test su iPad Melbourne Rapid Fields.

**Stimolo.** Pallino di 0,43 gradi (dimensione Goldmann III dei perimetri clinici), mostrato per 200 ms. Finestra di risposta di 1,5 secondi. Intervallo casuale tra uno stimolo e l'altro, così il ritmo non si può prevedere.

**Intensità.** Lo schermo non raggiunge la luminosità di un perimetro clinico: si usano 10 livelli di contrasto relativi al fondo. Non sono i decibel dell'Humphrey, è una misura relativa, e va detto.

**Fase 1, screening.** Circa 30 punti per occhio su una griglia ogni 6 gradi (simile allo schema 24-2), limitata a dove arriva lo schermo. Ogni punto viene testato una volta con uno stimolo abbastanza forte.

**Fase 2, approfondimento con la matrice.** Solo i punti non visti nello screening, più i loro vicini, passano alla misura completa.

- Ogni punto ha la sua distribuzione di probabilità sulla soglia: metodo ZEST (King-Smith e altri, 1994).
- Le zone cieche sono macchie, quindi i punti vicini sono correlati. Matrice dei pesi tra i punti i e j:

```latex
W_{ij} = e^{-\frac{d_{ij}^2}{2\sigma^2}} \qquad \sigma = 6^\circ
```

- dᵢⱼ è la distanza in gradi tra i due punti. Quando un punto termina, il suo risultato sposta le probabilità iniziali dei vicini in proporzione al peso. Modelli spaziali simili sono usati in perimetria per accorciare il test (Rubinstein, McKendrick e Turpin, 2016).
- Il prossimo punto da testare è quello con l'incertezza più alta.
- Stop per punto: deviazione standard sotto 1 livello, oppure 4 presentazioni.

**Affidabilità, come nei perimetri clinici.**

- **Fissazione con la macchia cieca** (Heijl e Krakau, 1975). Ogni occhio ha una macchia cieca naturale, circa 15 gradi verso l'esterno e poco sotto l'orizzonte. All'inizio l'app la localizza con qualche stimolo; poi nel 10% delle prove mostra un pallino forte lì. Se viene visto, la persona non stava fissando.
- **Falsi positivi:** prove senza stimolo in cui la persona tocca, più tocchi entro 150 ms dallo stimolo.
- **Falsi negativi:** stimolo forte in un punto già visto a intensità più bassa, e non visto.
- **Criteri Humphrey:** perdite di fissazione oltre il 20% o falsi positivi oltre il 15% rendono il test non affidabile; l'app propone di ripeterlo.

**Risultato.** Mappa di calore della sensibilità per occhio; estensione del campo in gradi (raggio entro cui la sensibilità è sopra soglia); indice di difetto medio rispetto ai valori attesi; classificazione: nessuna riduzione, riduzione periferica, visione a tunnel (raggio sotto 20 gradi), zone cieche sparse.

**In una frase:** "Il campo visivo è una matrice di punti: ogni risposta informa anche i punti vicini, e la macchia cieca naturale dell'occhio ci dice se stai davvero guardando il centro."

### 5.6 Luce

**Cosa vede la persona.** Lo stesso paragrafo in quattro versioni (chiaro o scuro, luminosità alta o bassa), mostrate a coppie: "Quale leggi meglio?" Sei confronti, più una domanda sul fastidio della luce.

**Sotto.** Dai confronti a coppie si ricava una classifica con il modello di Bradley-Terry, lo standard statistico per le preferenze a coppie. Si registra anche la luce ambiente.

**Risultato.** Tema preferito, luminosità preferita, sensibilità alla luce sì o no.

## 6. Affidabilità e riconoscimento di chi non è ipovedente

Il test riconosce due casi: la vista nella norma e le risposte non credibili. In entrambi i casi decide con la statistica, non con una soglia a occhio.

**Caso A: vista nella norma.** Non basta che la stima sia nella fascia normale: deve esserlo tutto l'intervallo di confidenza al 95%.

| Test | Condizione per "nella norma" |
| --- | --- |
| Acuità | intervallo tutto sotto 0,3 logMAR |
| Contrasto | intervallo tutto sopra 1,5 |
| Amsler | nessuna zona segnata |
| Campo visivo | nessun punto sotto soglia oltre quanto atteso per caso |

Se tutte valgono, l'app dice: "La tua vista risulta nella norma per questi test, non serve nessun adattamento." Se un intervallo sta a cavallo della soglia, il test continua finché la probabilità di stare da una parte supera il 95%. La regola di stop dipende quindi anche dalla classificazione, non solo dalla precisione.

**Caso B: risposte non credibili** (distrazione, fretta, o qualcuno che finge).

1. **Coerenza con il modello.** Chi sbaglia davvero sbaglia sulle lettere piccole. Errori sulle lettere grandi insieme a risposte giuste su quelle piccole sono improbabili secondo la curva stimata. Se la verosimiglianza delle risposte è troppo bassa, il test è incoerente.
2. **Errori su stimoli facili.** Se più del 20% degli errori riguarda lettere almeno 0,3 logMAR sopra la soglia, viene segnalato.
3. **Tempi di risposta.** Vicino alla soglia si risponde più lentamente, per incertezza. Risposte sbagliate e velocissime su lettere grandi sono sospette. Ogni tempo di risposta viene registrato e confrontato con questo schema.
4. **Coerenza tra i test.** Combinazioni rare, come un contrasto molto ridotto con un'acuità perfetta, vengono segnalate.
5. **Campo visivo:** perdite di fissazione, falsi positivi e falsi negativi (sezione 5.5).

**Risultato.** Per ogni test un giudizio (affidabile, dubbio, non affidabile) con il motivo, e un giudizio complessivo. Se non è affidabile, l'app propone di ripetere il test.

**In una frase:** "Il test non si ferma finché non è sicuro al 95% della categoria in cui sei, e controlla la coerenza delle risposte: chi finge sbaglia nel modo sbagliato."

## 7. Il profilo visivo

**Nota di prodotto.** Il risultato è un **profilo funzionale della vista**, non una diagnosi medica e non sostituisce una visita oculistica. Le misure servono esclusivamente a personalizzare l'interfaccia.

Il profilo è l'insieme dei risultati dei test, ognuno con il suo intervallo e il suo giudizio di affidabilità. È l'unica cosa che collega i test al browser, e resta sul telefono.

| Valore | Da quale test | Usato da |
| --- | --- | --- |
| Acuità (logMAR, intervallo al 95%) | 5.1 | R1 (riserva), R0, livello |
| Sensibilità al contrasto (log, intervallo) | 5.2 | R3 |
| Dimensione critica di stampa, velocità massima, acuità di lettura | 5.3 | R1, R9 |
| Zona centrale distorta o mancante: no / piccola / grande, coinvolgimento dei 2 gradi centrali | 5.4 | R2 |
| Campo visivo: mappa, raggio in gradi, classificazione | 5.5 | R2, R5 |
| Tema, luminosità, sensibilità alla luce | 5.6 | R4 |
| Livello complessivo: normale / lieve / moderato / grave | acuità, fasce OMS | R2, R9 |
| Affidabilità per test e complessiva | sezione 6 | R0 |
| Correzioni manuali della persona | uso del browser | R1, R10 |

## 8. Regole di adattamento

Ogni regola parte da un valore del profilo e cambia una parte precisa della pagina, con una formula esplicita. Tutte si applicano con CSS e JavaScript inseriti nella pagina dal WKWebView.

| Regola | Da quale valore | Cosa cambia |
| --- | --- | --- |
| R0 | intervalli e affidabilità | quale lato dell'intervallo usare |
| R1 | dimensione critica di stampa, distanza | dimensione del testo, in tempo reale |
| R2 | livello, campo visivo, Amsler | colonne, lunghezza della riga, spaziatura |
| R3 | sensibilità al contrasto | colori di testo e sfondo |
| R4 | test della luce | tema e luminosità |
| R5 | campo visivo | posizione dei controlli, un paragrafo alla volta |
| R6 | nessuno, per tutti | animazioni, popup, disordine |
| R7 | dimensione del testo | link e pulsanti |
| R8 | nessuno, per tutti | struttura della pagina |
| R9 | dimensione del testo | modalità lettura grande |
| R10 | uso nel tempo | correzioni, nuovo test |

### R0. Nel dubbio, più leggibile

Si usa il lato prudente dell'intervallo di confidenza: per la dimensione del testo il limite peggiore dell'acuità e della dimensione critica, per il contrasto il limite peggiore della sensibilità. Se un test è "dubbio", ci si sposta ancora di 0,1 unità verso il prudente. L'incertezza del test diventa così una scelta concreta nell'interfaccia.

### R1. Dimensione del testo

**Base:** la dimensione critica di stampa del test di lettura. Se manca o non è affidabile: acuità + 0,4 logMAR (circa 2,5 volte la soglia, la "riserva di acuità").

**Formula.**

```latex
s_{obiettivo} = s_{critica} + 0{,}1 \qquad h_x = d \cdot \theta(s_{obiettivo}) \qquad font = \frac{h_x}{r_x}
```

- 0,1 logMAR di margine sopra la dimensione critica, circa il 26% in più.
- hₓ è l'altezza della x minuscola, quella che il test di lettura misura.
- rₓ è il rapporto tra altezza della x e dimensione del font di Atkinson Hyperlegible, noto, quindi la formula è esatta.
- Poi da millimetri a pixel con la densità dello schermo.

**In tempo reale con la distanza.**

- La dimensione è proporzionale alla distanza: telefono allontanato del 20%, testo più grande del 20%.
- Filtro esponenziale sulla distanza per togliere il tremolio della mano.
- Isteresi: la pagina si ridisegna solo se la variazione supera l'8%.
- Transizione animata sotto i 200 ms.

### R2. Impaginazione e spaziatura

**Base per tutti (WCAG 1.4.12):** interlinea 1,5 volte il font; spazio tra paragrafi 2 volte il font; spazio tra lettere 0,12 volte; spazio tra parole 0,16 volte. Testo allineato a sinistra, mai giustificato.

**Una colonna** quando il testo è più grande di 1,5 volte l'originale o quando il campo visivo è ridotto.

**Lunghezza della riga basata sul campo visivo.** Con la visione a tunnel, una riga più larga della zona che si vede costringe a muovere la testa. Quindi:

```latex
L_{max} = 2 \cdot d \cdot \tan(R_{campo}) \cdot 0{,}8
```

Con un raggio di 10 gradi a 35 cm, le righe sono larghe al massimo circa 10 cm e cadono tutte dentro la zona visibile. Minimo 15 caratteri per riga; senza riduzione del campo, massimo 60.

**Zona cieca al centro (Amsler):** interlinea 2; spazio tra lettere 0,18; spazio tra parole 0,24. Aiuta a non perdere la riga.

### R3. Contrasto

| Sensibilità al contrasto (log) | Contrasto minimo del testo |
| --- | --- |
| 1,65 o più | 4,5:1 (livello AA del W3C) |
| 1,5 – 1,65 | 7:1 (livello AAA) |
| 1,0 – 1,5 | da 7:1 a 12:1, in proporzione |
| sotto 1,0 | 15:1 |

Le soglie oltre l'AAA sono una scelta di design nostra, ancorata ai livelli del W3C, e va detto.

**Algoritmo.**

1. Per ogni elemento con testo: colore del testo e sfondo effettivo, risalendo gli elementi genitori fino a uno sfondo pieno.
2. Contrasto con la formula del W3C, basata sulla luminosità relativa.
3. Se è sotto l'obiettivo, si schiarisce o si scurisce solo il testo, mantenendo la tinta (un link blu resta blu, solo più scuro).
4. Se non basta, si cambia anche lo sfondo.
5. Testo sopra un'immagine: fondo pieno dietro al testo.
6. Bordi di campi e pulsanti: almeno 3:1, alzato in proporzione all'obiettivo del testo.

Il principio viene da Bonavero e altri (2015): adattare il meno possibile e rispettare il design del sito.

### R4. Luce e tema

- **Tema scuro:** sfondo #121212, testo bianco sporco #E8E6E3 (il bianco puro abbaglia), immagini leggermente scurite. R3 controlla comunque il contrasto.
- **Tema chiaro:** sfondo bianco caldo invece del bianco puro, per ridurre il riverbero.
- **Luminosità dello schermo:** il valore scelto nel test, mentre il browser è aperto.

### R5. Campo visivo e controlli

- Nessun elemento importante ai bordi: barre fisse e colonne laterali dei siti rimesse nel flusso della pagina o nascoste.
- La barra dei controlli del browser resta compatta e centrata, dentro la zona visibile.
- Raggio sotto 10 gradi: modalità "un paragrafo alla volta", uno per schermata.

### R6. Movimento e disordine (per tutti)

Animazioni disattivate, video fermi, niente caroselli automatici. Banner dei cookie, popup e barre fisse rimossi o chiusi. Pubblicità nascosta tramite R8.

### R7. Link e pulsanti

- Link sempre sottolineati, per non dipendere dal colore.
- Area di tocco minima 44 punti (regola Apple), aumentata in proporzione alla dimensione del testo fino a 64.
- L'elemento su cui si sta agendo ha un contorno spesso, con un colore che rispetta il contrasto del profilo.

### R8. Struttura della pagina

- **Metodo principale:** Readability.js, la libreria open source di Mozilla della modalità lettura di Firefox. Deterministica, veloce, offline, adatta ad articoli e pagine di testo.
- **Pagine che non sono articoli** (orari, negozi, moduli): regole semplici e deterministiche: si nascondono navigazione, colonne laterali, footer e riquadri pubblicitari riconosciuti da tag e classi comuni. Nessuna AI a runtime. Per la demo si scelgono pagine che vengono bene.
- **Ordine finale:** titolo, contenuto, moduli. Il menù va in un pulsante "Menù", la pubblicità sparisce.
- **Senza rete:** l'adattamento funziona tutto offline; la rete serve solo a caricare il sito.

### R9. Quando il testo non ci sta più

Se la dimensione necessaria lascia meno di 12 caratteri per riga, il browser passa alla modalità lettura grande: un paragrafo alla volta, e toccandolo lo si ascolta con la sintesi vocale, alla velocità di lettura misurata nel test.

### R10. Nel tempo

- Correzione manuale della dimensione con + e −, a passi di 0,1 logMAR, salvata nel profilo.
- Se la persona ingrandisce spesso, l'app propone di rifare il test.
- Promemoria ogni 3 mesi. Se un valore peggiora oltre il margine di errore, l'app suggerisce di sentire l'oculista.

## 9. Browser, privacy e demo

### Browser

Il browser è un WKWebView con pochi controlli grandi; tutto il lavoro sta nello strato che adatta le pagine.

- **In alto:** barra grande per un indirizzo o una ricerca, che apre google.com/search?q=…
- **In basso:** barra Liquid Glass con pochi pulsanti grandi: indietro, avanti, ricarica, "Originale / Per me".
- **"Originale / Per me":** passa dalla pagina com'è alla pagina adattata. Serve a chi usa l'app per controllare, ed è il momento più forte della demo.
- **Pagina iniziale:** alcuni siti di esempio: Google, un giornale (Repubblica o Corriere), Trenitalia.
- **Impostazioni:** rifare il test, correggere a mano i valori, modalità demo nascosta.
- **Nessun assistente AI** sulla pagina: deciso di non includerlo.

**Limite pratico.** Alcuni siti, una volta ridisposti, verranno male. Per la demo si scelgono due o tre siti e si fa in modo che lì funzioni perfettamente.

### Privacy

- Test, profilo e adattamento avvengono sul telefono.
- Niente account.
- Nessun server runtime, nessuna API esterna e nessuna AI a runtime: l'AI serve solo durante lo sviluppo del codice.
- Frase: "Non serve un account, e i dati sulla tua vista non lasciano mai il telefono."
- Non è una diagnosi: "profilo della tua vista funzionale", non sostituisce l'oculista.

### Demo (circa 3 minuti)

1. **Storia (30 secondi):** una persona concreta, per esempio "Maria, 68 anni, maculopatia, prova a controllare l'orario del treno".
2. **Simulazione:** il giudice indossa occhiali da lettura da farmacia da +3 o +4, che simulano un'acuità ridotta.
3. **Test dal vivo sul giudice** in modalità demo: acuità e contrasto, circa 1 minuto e mezzo, con l'intervallo di confidenza che si restringe sullo schermo.
4. **L'app si trasforma** appena finisce il test.
5. **Trenitalia:** prima "Originale", illeggibile con gli occhiali, poi "Per me".
6. **Il momento tecnico:** il giudice allontana il telefono e il testo cresce.
7. **Campo visivo:** mostrato con un profilo già salvato, con la mappa di calore e gli indici di affidabilità.
8. **Chiusura:** impatto e privacy.

La funzione da lasciar provare al giudice come "la più complessa" è il test dell'acuità insieme al testo che segue la distanza: funziona sempre, senza rete e senza AI.

## 10. Costruzione, fuori scope e riferimenti

### MVP hackathon: priorità congelata

Il minimo dimostrabile deve essere completo e affidabile prima di aggiungere altri test:

1. **Distanza del viso con ARKit** e conversione angolo visivo → pixel.
2. **Test di acuità** con algoritmo adattivo e intervallo di confidenza.
3. **Test di contrasto**, riutilizzando l'infrastruttura dell'acuità.
4. **VisualProfile → AdaptationPlan → browser adattato**, almeno per dimensione testo, contrasto, tema e layout di base.
5. **Profilo di campo visivo predefinito** usato per dimostrare l'adattamento in caso di tunnel vision/perdita centrale, anche se il test completo del campo visivo non è ancora pronto.

Solo dopo che questi cinque punti funzionano end-to-end si aggiungono, in ordine di valore/tempo disponibile: campo visivo completo, Amsler, luce, affidabilità avanzata e test di lettura.

### Ordine di costruzione

Questa è la roadmap estesa oltre l'MVP. Ogni passo deve lasciare qualcosa di funzionante da mostrare; non si passa allo step successivo se il flusso precedente non è stabile.

1. Distanza con ARKit, geometria dell'angolo visivo, test dell'acuità con QUEST+.
2. Contrasto (riusa quasi tutto dell'acuità).
3. Browser con dimensione del testo che segue la distanza (R1) e contrasto (R3).
4. Campo visivo con screening, matrice dei vicini e macchia cieca.
5. Amsler e luce, più le altre regole (R2, R4-R9).
6. Affidabilità e riconoscimento della vista nella norma.
7. Test di lettura.

Divisione del lavoro, architettura e contratti definitivi: sezione 11.

### Tempi della giornata

| Ora | Cosa |
| --- | --- |
| 11:30 - 13:00 | idee e specifica (questo documento) |
| 13:00 - 16:00 | codice con Claude Code |
| 16:00 - 17:00 | controlli finali e prove della demo |

Consiglio: iniziare il codice verso le 12:30, perché l'ultima ora di controlli si allunga sempre.

### Fuori dalla prima versione

- Assistente AI sulla pagina.
- Test dei colori.
- Versione per iPad (niente TrueDepth sull'iPad Air).
- Estensione per Safari o altri browser.

### Domande aperte

- Nome definitivo dell'app (per ora IpoView).
- Tabella della densità dello schermo (ppi) per i modelli di iPhone da supportare.

### Riferimenti

Da verificare titoli e anni prima di metterli nelle slide.

- Watson e Pelli (1983), QUEST; Watson (2017), QUEST+.
- King-Smith e altri (1994), ZEST.
- Heijl e Krakau (1975), controllo della fissazione con la macchia cieca.
- Pelli, Robson e Wilkins (1988), tabella del contrasto.
- Legge e colleghi, MNREAD; Cheung, Kallie, Legge e Cheong (2008), analisi delle curve MNREAD.
- Rubinstein, McKendrick e Turpin (2016), modelli spaziali in perimetria.
- Classificazione OMS (ICD-11) delle categorie di deficit visivo.
- [Hoogsteen e Szpiro (2023), A holistic understanding of challenges faced by people with low vision](https://doi.org/10.1016/j.ridd.2023.104517).
- [Bonavero, Huchard e Meynard (2015), Reconciling user and designer preferences in adapting web pages for people with low vision](https://hal-lirmm.ccsd.cnrs.fr/lirmm-01160733v1).
- [W3C, Accessibility Requirements for People with Low Vision](https://www.w3.org/TR/low-vision-needs/).
- [Peek Acuity, validazione (JAMA Ophthalmology)](https://jamanetwork.com/journals/jamaophthalmology/fullarticle/2296911).
- [K-CS, test del contrasto su smartphone (PLOS One)](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0288512).
- [Alleye, iperacuità per la maculopatia (Eye)](https://www.nature.com/articles/s41433-019-0455-6).
- [Melbourne Rapid Fields, perimetria su iPad](https://onlinelibrary.wiley.com/doi/10.1111/ceo.13082).

## 11. Architettura, divisione del lavoro e contratti

Tutto gira sull'iPhone, senza server runtime, senza API esterne e senza AI a runtime. Claude serve solo durante lo sviluppo del codice. La cartella backend/ non è un backend di rete: è il workspace Python di Michele per modelli statistici, simulazioni, validazione e golden test. Rocco e Michele lavorano in parallelo dalla stessa specifica; il Python e Swift vengono sviluppati in parallelo dalla stessa specifica; il Python di Michele verifica lo Swift, non lo precede.

### Flusso nell'app

```
test sull'iPhone → algoritmi Swift locali → VisualProfile → regole locali (R0-R10) → AdaptationPlan → adapter.js → pagina adattata
```

### Divisione del lavoro

| Rocco (Mac, Xcode, Claude Code) | Michele (Windows, Python, Claude Code) |
| --- | --- |
| app iOS in SwiftUI, design | implementazione di riferimento dei test in Python, dentro backend/ |
| ARKit e distanza del viso | stessi algoritmi: QUEST+, ZEST, matrice dei vicini, curva di lettura |
| i sei test in Swift | simulazioni con utenti virtuali: precisione e numero di risposte, grafici per le slide |
| regole R0-R10 in Swift (profilo → piano) | stesse regole in Python, per validazione |
| WKWebView e adapter.js | golden test: input fissi e risultati attesi in shared/examples |
| integrazione finale e demo | verifica numerica Swift contro Python |

### Repository

```
project/
├── ios/                 Rocco: SwiftUI, Xcode, ARKit, WKWebView, adapter.js
├── backend/             Michele: Python, modelli statistici, simulazioni e validazione
│   ├── acuity/
│   ├── contrast/
│   ├── reading/
│   ├── visual_field/
│   ├── light/
│   ├── adaptation/
│   ├── simulation/
│   └── tests/
├── shared/
│   ├── visual-profile.schema.json
│   ├── adaptation-plan.schema.json
│   └── examples/
│       ├── central-loss/              profile.json + expected-plan.json
│       ├── tunnel-vision/             profile.json + expected-plan.json
│       └── low-contrast-photophobia/  profile.json + expected-plan.json
├── docs/
│   └── data-contracts.md
├── tests/
├── CLAUDE.md
├── CONTEXT.md
├── README.md
└── .gitignore
```

Niente server runtime, niente crowding/ separato (l'affollamento delle lettere è già misurato dal test di lettura). La cartella backend/ è solo il workspace Python di Michele per implementazioni di riferimento, simulazioni, validazione e test.

### Ownership e lavoro in parallelo

- **Rocco** modifica principalmente `ios/` e possiede anche `adapter.js`; testa tutto su Mac/Xcode/iPhone.
- **Michele** modifica principalmente `backend/` e lavora solo in Python: modelli statistici, simulazioni, validazione, regole di adattamento di riferimento e golden test.
- `shared/` è il confine comune: ogni modifica agli schema o agli esempi deve restare compatibile con entrambe le implementazioni.
- Swift e Python partono subito dalla stessa specifica e procedono in parallelo. Nessuna delle due implementazioni deve aspettare l'altra.
- Per la verifica incrociata si usano input condivisi, seed fissi quando c'è casualità e confronti numerici con tolleranza.

### Regole dei contratti

- Gli **schema** descrivono i campi e i valori ammessi; gli **esempi** contengono solo valori reali (per esempio "pattern": "tunnel", mai l'elenco delle opzioni).
- Esempi con nomi funzionali (central-loss, tunnel-vision, low-contrast-photophobia), non diagnosi: il sistema misura come vede la persona.
- Unità: gradi, logMAR, log della sensibilità al contrasto, millimetri, pixel. Campo visivo in gradi rispetto al punto fissato, x positivo a destra, y positivo in alto.
- Amsler: "cells" è una vera matrice 10 × 10 (0 normale, 1 distorta, 2 mancante).
- Ogni risultato dei test ha stima, intervallo al 95%, giudizio di affidabilità e motivi.

### VisualProfile (campi)

| Blocco | Campi principali |
| --- | --- |
| device | model, ppi |
| acuity | logMAR, ci95, slope, trials, reliability, flags |
| contrast | logCS, ci95, trials, reliability, flags |
| reading | measured, criticalPrintSizeLogMAR, ci95, maxReadingSpeedWpm, readingAcuityLogMAR, reliability, flags |
| amsler | right, left: cells 10 × 10, distortedAreaDeg2, missingAreaDeg2, centralInvolved |
| visualField | right, left: points (x, y, sensitivity, sd, seen), fieldRadiusDeg, meanDefect, pattern, fixationLossRate, falsePositiveRate, falseNegativeRate, reliability |
| light | preferredTheme, preferredBrightness, photophobia |
| summary | level, normalVision, overallReliability |
| userAdjustments | textSizeOffsetLogMAR |

### AdaptationPlan (campi)

Solo numeri pronti, nessuna scienza della vista: è l'uscita delle regole R0-R10.

| Blocco | Campi |
| --- | --- |
| text | fontFamily, fontSizePx, lineHeight, letterSpacingEm, wordSpacingEm, paragraphSpacingEm, align |
| layout | singleColumn, maxLineWidthPx, mode (normale, paragrafo, lettura-grande), moveEdgeElements |
| color | theme, background, text, minTextContrast, minUIContrast, preserveHue, imageBrightness |
| controls | underlineLinks, minTargetPt, focusOutlinePx |
| cleanup | removeCookieBanners, stopAnimations, useReadability |
| speech | tapToSpeak, rateWpm |
| screen | brightness |

### adapter.js: tre funzioni e basta — ownership Rocco/iOS

- IpoView.apply(plan): applica tutto il piano.
- IpoView.setFontSizePx(px): aggiorna solo la dimensione del testo; l'app la chiama quando cambia la distanza.
- IpoView.reset(): torna alla pagina originale (pulsante "Originale / Per me").

### Verifica Python contro Swift

- Stessi input, presi da shared/examples.
- Seme casuale fisso nei test di verifica, così prove trappola e intervalli sono identici.
- Confronto con tolleranza, per esempio |swift − python| < 0,001, mai uguaglianza esatta tra numeri decimali.
- Test deterministici separati dal comportamento casuale reale dell'app.

### Sicurezza della demo

Il browser ha 2-3 pagine HTML salvate in locale (una copia di Trenitalia, un articolo, una ricerca). Se il Wi-Fi dell'hackathon cade, la demo continua su quelle.
