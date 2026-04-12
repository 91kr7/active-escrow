#!/bin/bash
######################################################################
# Questo script auto-registra i Runner forzandoli a parlare 
# con GitLab tramite i DNS interni di Docker (bypassando l'host Mac)
######################################################################

echo "--------------------------------------------------------"
echo "⏳ Creazione e registrazione del Runner su GitLab Source..."
echo "--------------------------------------------------------"
# Interroghiamo a "cuore aperto" il database Rails di GitLab per creare e stampare il token auth!
SRC_TOKEN=$(docker exec -i gitlab-source gitlab-rails runner "runner = Ci::Runner.create!(runner_type: 'instance_type', description: 'docker-runner-source', run_untagged: true, locked: false); puts runner.token")

if [[ ! "$SRC_TOKEN" =~ ^glrt-.* ]] && [[ ! "$SRC_TOKEN" =~ ^glpat-.* ]] && [ ${#SRC_TOKEN} -lt 10 ]; then
    echo "⚠️ Errore nel recuperare il token da Source. Il token letto è invalido: '$SRC_TOKEN'"
    echo "GiLab ha finito il Boot? Prova a rieseguire."
    exit 1
fi

docker exec -i gitlab-runner-source gitlab-runner register \
  --non-interactive \
  --url "http://gitlab-source" \
  --clone-url "http://gitlab-source" \
  --token "$SRC_TOKEN" \
  --executor "docker" \
  --docker-image "maven:3.9.6-eclipse-temurin-17" \
  --docker-network-mode "active-escrow_escrow-net"

echo "--------------------------------------------------------"
echo "⏳ Creazione e registrazione del Runner su GitLab Escrow..."
echo "--------------------------------------------------------"
ESC_TOKEN=$(docker exec -i gitlab-escrow gitlab-rails runner "runner = Ci::Runner.create!(runner_type: 'instance_type', description: 'docker-runner-escrow', run_untagged: true, locked: false); puts runner.token")

docker exec -i gitlab-runner-escrow gitlab-runner register \
  --non-interactive \
  --url "http://gitlab-escrow" \
  --clone-url "http://gitlab-escrow" \
  --token "$ESC_TOKEN" \
  --executor "docker" \
  --docker-image "maven:3.9.6-eclipse-temurin-17" \
  --docker-network-mode "active-escrow_escrow-net"

echo "--------------------------------------------------------"
echo "✅ Entrambi i Runner sono ora registrati e agganciati ai due GitLab perfettamente!"
echo "I pipeline job verranno presi in carico dai rispettivi cloni docker."
echo "--------------------------------------------------------"
