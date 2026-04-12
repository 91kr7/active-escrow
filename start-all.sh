#!/bin/bash

BASE_DIR="/Users/christianmariani/IdeaProjects/me/escrow"
cd "$BASE_DIR" || exit

echo "🚀 Avvio i container dell'ambiente Mock Escrow..."
# Usa docker-compose o docker compose a seconda della versione. Usiamo "docker compose" che ormai è standard.
docker compose up -d

echo ""
echo "⏳ Attendo l'inizializzazione dei servizi web di GitLab."
echo "   NB: Questo step può richiedere diversi minuti in base alla potenza della macchina."

# Funzione per attendere che GitLab accetti richieste sulla pagina di login (che garantisce che i servizi web siano su)
wait_for_gitlab() {
    URL=$1
    NAME=$2
    
    echo -n "Attendendo $NAME ($URL) "
    
    # Esegue curl in modo silente, e controlla se lo status HTTP in ritorno è 200
    until [ "$(curl -s -o /dev/null -L -w "%{http_code}" "$URL/users/sign_in")" -eq 200 ]; do
        echo -n "."
        sleep 10
    done
    echo " ✅ Online!"
}

# Invoca l'attesa su entrambi i GitLab in esecuzione locale
wait_for_gitlab "http://127.0.0.1:8081" "GitLab Source"
wait_for_gitlab "http://127.0.0.1:8082" "GitLab Escrow"

# Una volta online, chiama gli ulteriori script
echo ""
echo "📦 Setup dei Repository e push automatico..."
chmod +x setup-projects.sh
./setup-projects.sh

echo ""
echo "🏃‍♂️ Creazione Runner e aggancio a GitLab..."
chmod +x register-runners.sh
./register-runners.sh

echo ""
echo "🎉 Fatto! L'ambiente è pronto, i progetti creati e i runner sono attivi!"
