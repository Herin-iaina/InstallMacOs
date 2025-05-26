#!/bin/bash

# Configuration
SCRIPT_DIR="/var/tmp"
CLIENT_SCRIPT="macos_installer_client.sh"
LOG_FILE="/var/tmp/downloader.log"

# Fonction de logging
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Fonction pour vérifier si le client est déjà en cours d'exécution
check_running() {
    if pgrep -f "$CLIENT_SCRIPT" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Fonction pour démarrer le client en arrière-plan
start_client() {
    log "INFO" "Démarrage du client de téléchargement"
    
    # Créer le dossier temporaire si nécessaire
    mkdir -p "$SCRIPT_DIR"
    
    # Copier le script client si nécessaire
    if [ ! -f "${SCRIPT_DIR}/${CLIENT_SCRIPT}" ]; then
        log "INFO" "Copie du script client vers $SCRIPT_DIR"
        cp "$0" "${SCRIPT_DIR}/${CLIENT_SCRIPT}"
        chmod +x "${SCRIPT_DIR}/${CLIENT_SCRIPT}"
    fi
    
    # Lancer le client en arrière-plan avec nohup
    cd "$SCRIPT_DIR"
    nohup "./${CLIENT_SCRIPT}" > /dev/null 2>&1 &
    
    # Vérifier si le processus a bien démarré
    sleep 2
    if check_running; then
        log "INFO" "Client démarré avec succès (PID: $(pgrep -f "$CLIENT_SCRIPT"))"
        return 0
    else
        log "ERROR" "Échec du démarrage du client"
        return 1
    fi
}

# Fonction principale
main() {
    log "INFO" "Démarrage du script de téléchargement"
    
    # Vérifier si le client est déjà en cours d'exécution
    if check_running; then
        log "WARNING" "Le client est déjà en cours d'exécution"
        exit 0
    fi
    
    # Démarrer le client
    if start_client; then
        log "INFO" "Le client a été lancé en arrière-plan"
        # Afficher un message à l'utilisateur
        osascript -e 'display notification "Le téléchargement a démarré en arrière-plan" with title "Téléchargement macOS"'
    else
        log "ERROR" "Impossible de démarrer le client"
        # Afficher un message d'erreur à l'utilisateur
        osascript -e 'display dialog "Erreur lors du démarrage du téléchargement" buttons {"OK"} default button "OK" with icon stop'
        exit 1
    fi
}

# Exécuter le script principal
main 