# Analisi Tecnica: Processo di Allineamento Active Escrow

## 1. Obiettivo del Processo
*   La specifica descrive l'allineamento di un active escrow a seguito di un commit effettuato su un'istanza GitLab che funge da sorgente del codice.
*   L'active escrow archivia (stora) il codice e l'artefatto su un'istanza isolata di GitLab.
*   Oltre a contenere il medesimo codice, l'active escrow deve essere capace di effettuare la build del sorgente in autonomia.

## 2. Innesco e Operazioni sul Sorgente
*   Il processo parte quando un dev committa sul GitLab sorgente.
*   A seguito del commit, il GitLab sorgente esegue le direttive di `mvn build + deploy` utilizzando un runner.

## 3. Scrittura in Coda e Trasferimento Dati
*   Se lo step di build e deploy termina con successo (tutto ok), il sistema scrive un messaggio in una coda RabbitMQ.
*   Il payload del messaggio comprende: il relative path del progetto buildato, la branch buildata, l'hash del commit e le variabili della build.

## 4. Consumo ed Elaborazione lato Fornitore
*   Un consumer, che risiede nell'ambiente fornitore, ha il compito di scodare sequenzialmente i messaggi presenti nella coda RabbitMQ.
*   Per ogni messaggio letto, il consumer innesca (trigghera) e monitora una pipeline sul GitLab del fornitore, passandole in input le variabili lette dal messaggio.

## 5. Allineamento del Codice e Build su Escrow
*   La pipeline avviata sul GitLab fornitore effettua il pull della repo e dello specifico hash del commit direttamente dal GitLab sorgente.
*   Successivamente, per allineare il codice, esegue un push sul GitLab escrow puntando alla branch indicata nel messaggio originale.
*   Infine, la pipeline del fornitore avvia a sua volta la pipeline di build sull'escrow, propagando fedelmente le variabili scritte nel messaggio.

## 6. Gestione degli Errori e Intervento Umano
*   Se la pipeline di build in esecuzione sull'escrow fallisce, anche la pipeline chiamante deve fallire, propagando di fatto lo stato di errore.
*   In caso di fallimento della pipeline, il processo sospende immediatamente la scodatura dei messaggi.
*   Questo blocco serve a permettere a un utente umano di intervenire per fixare la build prima di far ripartire la coda.
