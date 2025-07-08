#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables globales
LOG_FILE="/var/log/system_install.log"
ERROR_LOG="/var/log/system_install_error.log"
RETRY_ATTEMPTS=3


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
    local operation=$3
    
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "Échec de l'opération: $operation - $error_message (Code: $exit_code)"
        
        # Tentative de récupération selon l'opération
        case $operation in
            "UPDATE")
                log "WARNING" "Tentative de correction des paquets cassés..."
                if [[ $OS == "Ubuntu" ]]; then
                    sudo apt --fix-broken install -y
                    sudo dpkg --configure -a
                elif [[ $OS == "Fedora" ]]; then
                    sudo dnf clean all
                    sudo dnf check
                fi
                ;;
            "DOCKER")
                log "WARNING" "Tentative de réinstallation de Docker..."
                if [[ $OS == "Ubuntu" ]]; then
                    sudo apt remove --purge docker-ce docker-ce-cli containerd.io -y
                elif [[ $OS == "Fedora" ]]; then
                    sudo dnf remove docker-ce docker-ce-cli containerd.io -y
                fi
                ;;
        esac
        
        return 1
    fi
    return 0
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log "INFO" "Vérification des prérequis..."
    
    # Vérification de la connexion Internet
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log "ERROR" "Pas de connexion Internet"
        exit 1
    fi
    
    # Vérification de l'espace disque
    local space_available=$(df / | awk 'NR==2 {print $4}')
    if [ "$space_available" -lt 5242880 ]; then # 5GB en KB
        log "ERROR" "Espace disque insuffisant (minimum 5GB requis)"
        exit 1
    fi  # Correction ici : on ferme la condition avec 'fi' au lieu de '}'
    
    # Vérification de la mémoire RAM
    local ram_available=$(free -m | awk 'NR==2 {print $2}')
    if [ "$ram_available" -lt 2048 ]; then # 2GB minimum
        log "WARNING" "Mémoire RAM limitée (recommandé: 2GB minimum)"
    fi
}

wait_for_docker() {
    log "INFO" "Attente du démarrage complet de Docker..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if sudo docker info >/dev/null 2>&1; then
            log "INFO" "Docker est prêt"
            return 0
        fi
        log "WARNING" "Docker n'est pas encore prêt, tentative $attempt/$max_attempts"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "ERROR" "Docker n'a pas démarré correctement après $max_attempts tentatives"
    return 1
}

# Fonction modifiée pour l'installation de Docker Compose
install_docker_compose() {
    log "INFO" "Installation de Docker Compose..."
    
    local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    
    for i in $(seq 1 $RETRY_ATTEMPTS); do
        if sudo curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
            sudo chmod +x /usr/local/bin/docker-compose
            break
        else
            handle_error $? "Échec du téléchargement de Docker Compose" "DOCKER_COMPOSE"
            if [ $i -eq $RETRY_ATTEMPTS ]; then
                log "ERROR" "Échec de l'installation de Docker Compose après $RETRY_ATTEMPTS tentatives"
                exit 1
            fi
            sleep 5
        fi
    done
    
    # Vérification de l'installation de Docker Compose
    if ! docker-compose --version; then
        log "ERROR" "Échec de la vérification de Docker Compose"
        exit 1
    fi
    
    log "INFO" "Docker Compose installé avec succès"
}

# Nouvelle fonction pour le build et le démarrage des containers
start_docker_compose() {
    log "INFO" "Démarrage des containers Docker..."
    
    # Vérification de l'existence du fichier docker-compose.yml
    if [ ! -f "./docker-compose.yml" ]; then
        log "ERROR" "Fichier docker-compose.yml non trouvé dans le répertoire courant"
        return 1
    fi
    
    # Arrêt des containers existants
    log "INFO" "Arrêt des containers existants..."
    sudo docker-compose down --remove-orphans || {
        log "WARNING" "Erreur lors de l'arrêt des containers existants"
    }
    
    # Build et démarrage des containers
    log "INFO" "Construction et démarrage des containers..."
    for i in $(seq 1 $RETRY_ATTEMPTS); do
        if sudo docker-compose up --build -d; then
            log "INFO" "Containers démarrés avec succès"
            
            # Vérification du statut des containers
            sleep 5
            if sudo docker-compose ps | grep -q "Exit"; then
                log "ERROR" "Certains containers ne se sont pas démarrés correctement"
                sudo docker-compose logs
                return 1
            fi
            
            return 0
        else
            log "WARNING" "Échec du démarrage des containers, tentative $i/$RETRY_ATTEMPTS"
            if [ $i -eq $RETRY_ATTEMPTS ]; then
                log "ERROR" "Impossible de démarrer les containers après $RETRY_ATTEMPTS tentatives"
                return 1
            fi
            sleep 5
        fi
    done
}


# Fonction pour la sauvegarde de sécurité
backup_system_files() {
    local backup_dir="/root/system_backup_$(date +%Y%m%d_%H%M%S)"
    log "INFO" "Création d'une sauvegarde de sécurité dans $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Sauvegarde des fichiers de configuration importants
    cp /etc/hosts "$backup_dir/" 2>/dev/null || log "WARNING" "Impossible de sauvegarder /etc/hosts"
    cp /etc/resolv.conf "$backup_dir/" 2>/dev/null || log "WARNING" "Impossible de sauvegarder /etc/resolv.conf"
    
    # Sauvegarde des repositories
    if [[ $OS == "Ubuntu" ]]; then
        cp -r /etc/apt/sources.list* "$backup_dir/" 2>/dev/null
    elif [[ $OS == "Fedora" ]]; then
        cp -r /etc/yum.repos.d/* "$backup_dir/" 2>/dev/null
    fi
}

# Fonction pour les installations sur Ubuntu avec retry
ubuntu_install() {
    log "INFO" "Démarrage de l'installation sur Ubuntu..."
    
    # Sauvegarde avant modification
    backup_system_files
    
    # Mise à jour du système avec retry
    for i in $(seq 1 $RETRY_ATTEMPTS); do
        log "INFO" "Tentative $i de mise à jour du système..."
        if sudo apt update && sudo apt upgrade -y; then
            break
        else
            handle_error $? "Échec de la mise à jour du système" "UPDATE"
            if [ $i -eq $RETRY_ATTEMPTS ]; then
                log "ERROR" "Échec de la mise à jour après $RETRY_ATTEMPTS tentatives"
                exit 1
            fi
            sleep 5
        fi
    done
    
    # Installation de Git avec vérification
    log "INFO" "Installation de Git..."
    if ! sudo apt install -y git; then
        handle_error $? "Échec de l'installation de Git" "GIT"
        exit 1
    fi
    
    # Installation de Docker avec vérification
    log "INFO" "Installation de Docker..."
    {
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common &&
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - &&
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" &&
        sudo apt update &&
        sudo apt install -y docker-ce docker-ce-cli containerd.io
    } || {
        handle_error $? "Échec de l'installation de Docker" "DOCKER"
        exit 1
    }
    
    install_docker_compose
}

# Fonction pour les installations sur Fedora avec retry
fedora_install() {
    log "INFO" "Démarrage de l'installation sur Fedora..."
    
    # Sauvegarde avant modification
    backup_system_files
    
    # Mise à jour du système avec retry
    for i in $(seq 1 $RETRY_ATTEMPTS); do
        log "INFO" "Tentative $i de mise à jour du système..."
        if sudo dnf update -y; then
            break
        else
            handle_error $? "Échec de la mise à jour du système" "UPDATE"
            if [ $i -eq $RETRY_ATTEMPTS ]; then
                log "ERROR" "Échec de la mise à jour après $RETRY_ATTEMPTS tentatives"
                exit 1
            fi
            sleep 5
        fi
    done
    
    # Installation de Git avec vérification
    log "INFO" "Installation de Git..."
    if ! sudo dnf install -y git; then
        handle_error $? "Échec de l'installation de Git" "GIT"
        exit 1
    fi
    
    # Installation de Docker avec vérification
    log "INFO" "Installation de Docker..."
    if command -v docker &>/dev/null; then
        log "INFO" "Docker déjà installé, on skip..."
    else
        if ! sudo dnf install -y docker; then
            handle_error $? "Échec de l'installation de Docker" "DOCKER"
            exit 1
        fi
    fi
    
    install_docker_compose
}

# Fonction commune pour l'installation de Docker Compose
install_docker_compose() {
    if command -v docker-compose &>/dev/null; then
        log "INFO" "Docker Compose déjà installé, on skip..."
        return 0
    fi

    log "INFO" "Installation de Docker Compose..."
    local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
        | grep 'tag_name' \
        | cut -d'"' -f4)

    for i in $(seq 1 $RETRY_ATTEMPTS); do
        if sudo curl -L \
            "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        then
            sudo chmod +x /usr/local/bin/docker-compose
            break
        else
            handle_error $? "Échec du téléchargement de Docker Compose" "DOCKER_COMPOSE"
            if [ $i -eq $RETRY_ATTEMPTS ]; then
                log "ERROR" "Échec de l'installation de Docker Compose après $RETRY_ATTEMPTS tentatives"
                exit 1
            fi
            sleep 5
        fi
    done
}

# Fonction de nettoyage
cleanup() {
    log "INFO" "Nettoyage du système..."
    
    if [[ $OS == "Ubuntu" ]]; then
        sudo apt autoremove -y
        sudo apt clean
    elif [[ $OS == "Fedora" ]]; then
        sudo dnf autoremove -y
        sudo dnf clean all
    fi
    
    # Compression des logs si trop volumineux
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE") -gt 1048576 ]; then
        gzip -f "$LOG_FILE"
    fi
}

# Fonction principale
main() {
    # Création des fichiers de log
    touch "$LOG_FILE" "$ERROR_LOG" || {
        echo "Impossible de créer les fichiers de log"
        exit 1
    }
    
    # Capture des erreurs non gérées
    trap 'log "ERROR" "Une erreur non gérée est survenue à la ligne $LINENO"' ERR
    
    # Vérification des privilèges root
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "Ce script doit être exécuté en tant que root ou avec sudo"
        exit 1
    fi
    
    # Vérification des prérequis
    check_prerequisites
    
    # Détection du système d'exploitation
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        log "ERROR" "Impossible de détecter le système d'exploitation"
        exit 1
    fi
    
    # Installation selon le système d'exploitation
    case $OS in
        "ubuntu")  ubuntu_install ;;
        "fedora")  fedora_install ;;
        *)         log "ERROR" "Non supporté: $OS" ;;
    esac

    # Attente que Docker soit prêt
    wait_for_docker || {
        log "ERROR" "Docker n'est pas disponible après l'installation"
        exit 1
    }
    
    # Démarrage des services Docker
    if [[ $OS == "Ubuntu" ]] || [[ $OS == "Fedora" ]]; then
        log "INFO" "Démarrage et activation du service Docker..."
        if ! sudo systemctl start docker; then
            log "ERROR" "Échec du démarrage du service Docker"
            exit 1
        fi
        if ! sudo systemctl enable docker; then
            log "WARNING" "Échec de l'activation automatique du service Docker"
        fi
    fi
    
    # Installation de Docker Compose
    install_docker_compose || {
        log "ERROR" "Échec de l'installation de Docker Compose"
        exit 1
    }
    
    # Vérification des versions installées
    log "INFO" "Vérification des versions installées..."
    docker_version=$(docker --version 2>/dev/null)
    compose_version=$(docker-compose --version 2>/dev/null)
    git_version=$(git --version 2>/dev/null)
    
    log "INFO" "Versions installées:"
    log "INFO" "Docker: ${docker_version:-Non installé}"
    log "INFO" "Docker Compose: ${compose_version:-Non installé}"
    log "INFO" "Git: ${git_version:-Non installé}"
    
    # Nettoyage
    cleanup
    
    # Configuration post-installation
    log "INFO" "Configuration des permissions..."
    if ! sudo usermod -aG docker $SUDO_USER; then
        log "WARNING" "Échec de l'ajout de l'utilisateur au groupe docker"
    fi
    
    # Vérification de l'existence du docker-compose.yml
    if [ -f "./docker-compose.yml" ]; then
        log "INFO" "Fichier docker-compose.yml trouvé, démarrage des containers..."
        
        # Démarrage des containers
        if ! start_docker_compose; then
            log "ERROR" "Échec du démarrage des containers Docker"
            exit 1
        fi
        
        # Affichage du statut des containers
        log "INFO" "Statut des containers:"
        sudo docker-compose ps
        
        # Affichage des logs des containers
        log "INFO" "Logs des containers:"
        sudo docker-compose logs
    else
        log "WARNING" "Aucun fichier docker-compose.yml trouvé dans le répertoire courant"
    fi
    
    # Message de fin d'installation
    log "INFO" "============================================="
    log "INFO" "Installation terminée avec succès!"
    log "INFO" "Actions recommandées:"
    log "INFO" "1. Déconnectez-vous et reconnectez-vous pour que les changements de groupe Docker prennent effet"
    log "INFO" "2. Vérifiez les logs dans $LOG_FILE pour plus de détails"
    log "INFO" "3. En cas d'erreur, consultez $ERROR_LOG"
    
    # Vérification finale des services
    if ! sudo systemctl is-active --quiet docker; then
        log "WARNING" "Le service Docker n'est pas actif"
    else
        log "INFO" "Service Docker: Actif"
    fi
    
    # Affichage des informations de connexion Docker
    if sudo docker info &>/dev/null; then
        log "INFO" "Docker fonctionne correctement"
    else
        log "WARNING" "Docker pourrait ne pas fonctionner correctement"
    fi
    
    log "INFO" "============================================="
    
    # Retour du statut de succès
    return 0
}

main
