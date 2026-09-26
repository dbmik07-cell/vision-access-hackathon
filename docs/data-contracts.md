# Contratto dati condiviso

Segnaposto per la specifica locale comune alle implementazioni Python di riferimento e Swift sull'iPhone. Non definisce un servizio backend o endpoint HTTP.

- `shared/visual-profile.schema.json`: futuro schema del profilo visivo.
- `shared/adaptation-plan.schema.json`: futuro schema del piano di adattamento.
- `shared/examples/`: futuri casi golden condivisi.

Gli schemi attuali sono permissivi e non validano dati applicativi. Campi, unita, vincoli, versionamento, casi golden, seed/generatori e tolleranze numeriche saranno concordati durante `/grill-with-docs`. Non sono ancora definiti modelli statistici o regole di adattamento.

Entrambe le implementazioni dovranno rispettare la stessa specifica e gli stessi casi golden. I confronti numerici useranno tolleranze concordate anziche uguaglianza esatta dei float e seed deterministici dove necessari. Il crowding rientra nel test di lettura.
