#!/bin/bash

# Setup Git e primo commit
cd "$(dirname "$0")" || exit

echo "🚀 Inizializzazione repository Git locale..."
git init
git add .
git commit -m "Initial commit del Mock Escrow"
git branch -M main

echo "🔗 Configurazione Remote su GitLab Source..."
# Assicurati di aver prima creato un progetto vuoto chiamato "source-repo" dalla UI!
git remote remove origin 2>/dev/null
git remote add origin http://root:Rivoli30!230110@127.0.0.1:8081/root/source-repo.git

echo "⬆️ Eseguo la push del codice..."
git push -u origin main

echo "✅ Fatto! Puoi controllare l'esecuzione della pipeline su http://127.0.0.1:8081/root/source-repo/-/pipelines"
