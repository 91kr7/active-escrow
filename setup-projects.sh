#!/bin/bash

# Vai alla root del progetto
BASE_DIR="$(pwd)"
cd "$BASE_DIR" || exit

echo "--------------------------------------------------------"
echo "⏳ Creazione progetti su GitLab tramite Rails Console..."
echo "--------------------------------------------------------"

# Crea source-repo, provider-sync-repo e consumer-app su GitLab Source (-i = pass into stdin)
docker exec -i gitlab-source gitlab-rails runner "
root = User.find_by_username('root')
['source-repo', 'provider-sync-repo', 'consumer-app'].each do |repo_name|
  unless Project.find_by_path(repo_name)
    Project.create!(name: repo_name, path: repo_name, namespace: root.namespace, creator: root)
    puts %Q(-> Creato progetto #{repo_name} su GitLab Source)
  else
    puts %Q(-> Progetto #{repo_name} esiste gia su GitLab Source)
  end
end
"

# Crea escrow-repo su GitLab Escrow
docker exec -i gitlab-escrow gitlab-rails runner "
root = User.find_by_username('root')
['source-repo'].each do |repo_name|
  unless Project.find_by_path(repo_name)
    Project.create!(name: repo_name, path: repo_name, namespace: root.namespace, creator: root)
    puts %Q(-> Creato progetto #{repo_name} su GitLab Escrow)
  else
    puts %Q(-> Progetto #{repo_name} esiste gia su GitLab Escrow)
  end
end
"

echo "--------------------------------------------------------"
echo "⬆️ Inizializzazione Git locale e push sui container..."
echo "--------------------------------------------------------"

# Funzione veloce per il push
push_repo() {
  REPO_DIR=$1
  REPO_NAME=$2
  PORT=$3
  
  if [ -d "$REPO_DIR" ]; then
    echo "📍 Pushing $REPO_NAME to GitLab instance port $PORT..."
    # Lavora su una copia temporanea per non toccare la working dir locale
    TMP_REPO_DIR=$(mktemp -d "/tmp/${REPO_NAME}.XXXXXX")
    rsync -a --exclude='.git' "$REPO_DIR/" "$TMP_REPO_DIR/"

    cd "$TMP_REPO_DIR" || return
    git init --quiet
    git add .
    git commit --quiet -m "Initial automated commit for $REPO_NAME"
    git branch -M main
    
    # Rimuovi eventuali origin precedenti e piazza quello col login e l'apice escapato per via del ! nella pw
    git remote remove origin 2>/dev/null
    git remote add origin "http://root:Rivoli30!230110@127.0.0.1:$PORT/root/$REPO_NAME.git"
    
    # Push su gitlab (quiet per evitare la valanga di logs, -u force)
    git push -u origin main
    echo "✅ Successo: $REPO_NAME è su http://127.0.0.1:$PORT/root/$REPO_NAME"
    rm -rf "$TMP_REPO_DIR"
    cd "$BASE_DIR" || return
  else
    echo "⚠️ Directory $REPO_DIR non trovata, impossibile pushare."
  fi
}

push_repo "$BASE_DIR/source-repo" "source-repo" "8081"
push_repo "$BASE_DIR/provider-sync-repo" "provider-sync-repo" "8081"
push_repo "$BASE_DIR/consumer-app" "consumer-app" "8081"

echo "--------------------------------------------------------"
echo "🔑 Rigenerazione Token (dopo la creazione dei progetti e il push)..."
echo "--------------------------------------------------------"

docker exec -i gitlab-source gitlab-rails runner "
root = User.find_by_username('root')
token = root.personal_access_tokens.find_or_initialize_by(name: 'mock')
token.scopes = ['api', 'read_repository', 'write_repository']
token.expires_at = 1.year.from_now
token.revoked = false if token.respond_to?(:revoked=)
token.set_token('Glpat-SourceToken')
token.save!
puts '-> Token rigenerato con successo su GitLab Source'
"

docker exec -i gitlab-escrow gitlab-rails runner "
root = User.find_by_username('root')
token = root.personal_access_tokens.find_or_initialize_by(name: 'mock')
token.scopes = ['api', 'read_repository', 'write_repository']
token.expires_at = 1.year.from_now
token.revoked = false if token.respond_to?(:revoked=)
token.set_token('Glpat-EscrowToken')
token.save!
puts '-> Token rigenerato con successo su GitLab Escrow'
"

echo "--------------------------------------------------------"
echo "🎉 Tutti i backend GitLab sono inizializzati!"
echo "--------------------------------------------------------"
