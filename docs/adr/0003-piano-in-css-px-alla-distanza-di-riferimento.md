# Piano in CSS px alla distanza di riferimento

La dimensione del testo dipende dalla distanza del viso, che cambia circa 60 volte al secondo, quindi un piano "solo numeri pronti" non e definito senza una distanza. L'`AdaptationPlan` esprime la dimensione come `fontSizeCssPx` calcolata a una **distanza di riferimento fissa di 400 mm**, con l'eco del contesto (`ppi`, `nativeScale`); a runtime Swift la riscala per `d / 400`, esatto perche R1 e lineare nella distanza. I casi golden cosi coprono l'intera catena angolo -> mm -> CSS px, dove le implementazioni divergono piu facilmente. La conversione usa `nativeScale` letto a runtime (non una tabella) perche differisce da `scale` sui mini e con lo Zoom schermo, e il contratto richiede un viewport 1:1 forzato da `adapter.js`, perche senza di esso WebKit impagina a 980 px e 1 CSS px non corrisponde piu a un punto.

## Opzioni considerate

- Solo angolo nel piano, pixel calcolati sull'iPhone: piu pulito, ma lascia fuori dai golden la conversione piu rischiosa.
- `fontSizePx` senza distanza ne unita, come nella specifica: la formula dava pixel fisici, 3 volte troppo grandi come CSS px.
