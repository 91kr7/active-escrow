# Specifiche per il Mock: Infrastruttura e Flusso CI/CD

## 1. Architettura dell'Ambiente di Test
*   Il mock deve simulare un active escrow che conserva i sorgenti su un'istanza isolata e li compila.
*   **Struttura Docker (da implementare in base alle richieste per il mock):**
    *   **GitLab Sorgente + Runner:** Container con l'istanza di partenza del codice.
    *   **RabbitMQ:** Container per fare da message broker.
    *   **Consumer Java/Maven:** Applicativo sviluppato in Java/Maven e rilasciato come container Docker **all'interno** del GitLab runner sorgente *(Variazione architetturale rispetto alla specifica originale)*.
    *   **GitLab Escrow + Runner:** Container con l'istanza isolata attiva.

## 2. Requisiti del Payload
*   Il messaggio RabbitMQ scambiato tra le code dovrà contenere: relative path del progetto, branch buildata, hash del commit e variabili necessarie alla build.

## 3. Flusso Operativo del Mock
1.  **Innesco:** Uno sviluppatore fittizio committa sul GitLab sorgente (container).
2.  **Build su Sorgente:** Il runner del sorgente esegue `mvn build + deploy`.
3.  **Accodamento:** Se la build ha successo, le informazioni di branch, path, hash e variabili vengono passate come messaggio su RabbitMQ.
4.  **Consumo Sequenziale:** L'applicativo in Java/Maven, all'interno del runner sorgente, scoda i messaggi dalla coda RabbitMQ rispettando l'ordine sequenziale.
5.  **Trigger e Allineamento:** Il consumer avvia la pipeline del fornitore passando le variabili. Questa pipeline pulla repository e commit hash dal sorgente e fa un push sulla medesima branch nel GitLab escrow.
6.  **Avvio Build Escrow:** Una volta pushato, la pipeline triggera la compilazione direttamente sull'escrow fornendogli le variabili ereditate dal messaggio.

## 4. Gestione Eccezioni da Implementare nel Mock
*   **Propagazione Errore in Pipeline:** Assicurarsi che il fallimento della pipeline sull'escrow causi in automatico il fallimento della pipeline chiamante.
*   **Sospensione Coda (Halt):** Implementare una logica per cui l'applicativo Java/Maven cessa di scodare nuovi messaggi nel momento in cui viene registrato l'errore dalla pipeline.
*   **Fix Manuale:** Il sistema deve restare bloccato per simulare l'attesa di un "fix" della build da parte di un utente umano prima che la lettura sequenziale possa riprendere.