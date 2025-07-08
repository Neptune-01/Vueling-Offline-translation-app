#!/bin/bash

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
SCREEN_NAME="translation_api"
LOG_FILE="/var/log/translation_api_run.log"
ERROR_LOG="/var/log/translation_api_run_error.log"
DOCKER_COMPOSE_FILE="docker-compose.yml"
MAX_RETRIES=3

# Fonction de logging
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $timestamp - $message"
            echo "[INFO] $timestamp - $message" >> "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $timestamp - $message"
            echo "[WARNING] $timestamp - $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message"
            echo "[ERROR] $timestamp - $message" >> "$ERROR_LOG"
            ;;
    esac
}

# Fonction de gestion d'erreur
handle_error() {
    local exit_code=$1
    local error_message=$2
    
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "$error_message (Code: $exit_code)"
        return 1
    fi
    return 0
}

# Fonction pour vérifier si screen est installé
check_screen() {
    if ! command -v screen &> /dev/null; then
        log "INFO" "Installation de screen..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update -qq && sudo apt-get install -y screen
        elif [ -f /etc/fedora-release ]; then
            sudo dnf install -y screen
        else
            log "ERROR" "Système d'exploitation non supporté"
            exit 1
        fi
        
        handle_error $? "Échec de l'installation de screen" || exit 1
    fi
}

# Fonction pour vérifier si Docker est en cours d'exécution
check_docker() {
    if ! sudo systemctl is-active --quiet docker; then
        log "WARNING" "Docker n'est pas en cours d'exécution. Tentative de démarrage..."
        sudo systemctl start docker
        sleep 5
        
        if ! sudo systemctl is-active --quiet docker; then
            log "ERROR" "Impossible de démarrer Docker"
            exit 1
        fi
    fi
}

# Fonction pour vérifier si les containers sont en cours d'exécution
check_containers() {
    local containers_running=0
    
    if sudo docker-compose ps --quiet | wc -l | grep -q "^0$"; then
        log "WARNING" "Aucun container en cours d'exécution"
        return 1
    else
        log "INFO" "Containers déjà en cours d'exécution"
        return 0
    fi
}

# Fonction pour arrêter proprement les containers
stop_containers() {
    log "INFO" "Arrêt des containers existants..."
    sudo docker-compose down --remove-orphans
    handle_error $? "Échec de l'arrêt des containers"
}

# Fonction pour démarrer les containers
start_containers() {
    log "INFO" "Démarrage des containers..."
    sudo docker-compose up --build -d
    
    # Vérification du statut des containers
    sleep 5
    if sudo docker-compose ps | grep -q "Exit"; then
        log "ERROR" "Certains containers ne se sont pas démarrés correctement"
        sudo docker-compose logs
        return 1
    fi
    return 0
}

# Fonction pour créer et gérer la session screen
manage_screen_session() {
    # Vérifier si la session screen existe déjà
    if screen -list | grep -q "$SCREEN_NAME"; then
        log "WARNING" "Une session screen '$SCREEN_NAME' existe déjà"
        log "INFO" "Terminaison de l'ancienne session..."
        screen -S "$SCREEN_NAME" -X quit
    fi
    
    log "INFO" "Création d'une nouvelle session screen..."
    screen -dmS "$SCREEN_NAME" bash -c "
        cd $(pwd) && 
        sudo docker-compose up --build;    # Suppression du -d pour voir les logs
        exec bash"
    
    handle_error $? "Échec de la création de la session screen" || return 1
    
    log "INFO" "Session screen '$SCREEN_NAME' créée avec succès"
    log "INFO" "Pour s'attacher à la session: screen -r $SCREEN_NAME"
    return 0
}

# Fonction de nettoyage
cleanup() {
    log "INFO" "Nettoyage des logs anciens..."
    find /var/log -name "translation_api_run*.log" -mtime +7 -exec rm {} \;
}

# Fonction principale
main() {
    # Création des fichiers de log
    sudo touch "$LOG_FILE" "$ERROR_LOG" || {
        echo "Impossible de créer les fichiers de log"
        exit 1
    }
    
    # Vérification des permissions
    if [ "$EUID" -ne 0 ] && [ ! -w "$LOG_FILE" ]; then
        log "ERROR" "Ce script doit être exécuté avec sudo"
        exit 1
    fi
    
    # Vérification du fichier docker-compose.yml
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log "ERROR" "Fichier $DOCKER_COMPOSE_FILE non trouvé"
        exit 1
    fi
    
    # Installation et vérification de screen
    check_screen
    
    # Vérification de Docker
    check_docker
    
    # Arrêt des containers existants
    stop_containers
    
    # Démarrage dans screen
    manage_screen_session
    
    if [ $? -eq 0 ]; then
        log "INFO" "================================================="
        log "INFO" "Application démarrée avec succès dans screen"
        log "INFO" "Nom de la session: $SCREEN_NAME"
        log "INFO" "Commandes utiles:"
        log "INFO" "- Voir la session: screen -r $SCREEN_NAME"
        log "INFO" "- Détacher de la session: CTRL+A puis D"
        log "INFO" "- Logs: tail -f $LOG_FILE"
        log "INFO" "================================================="
    else
        log "ERROR" "Échec du démarrage de l'application"
        exit 1
    fi
    
    # Nettoyage
    cleanup
}

# Gestion des signaux
trap 'log "WARNING" "Script interrompu"; stop_containers; exit 1' INT TERM

# Exécution du script
main

