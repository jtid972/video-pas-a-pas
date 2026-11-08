#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Script de maintenance mensuelle pour Vidéo pas à pas
# Exécute : mise à jour complète, reconstruction Docker, scan Trivy complet, tests complets
# Usage : ./scripts/maintenance-mensuelle.sh
#         MENSUEL_FORCE=1 ./scripts/maintenance-mensuelle.sh  (ignore les erreurs non critiques)

set -euo pipefail
cd "$(dirname "$0")/.."

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

LOG_FILE="/tmp/vpap-maintenance-mensuelle-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

echo "========================================" | tee -a "$LOG_FILE"
log "DEBUT : Maintenance mensuelle Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"

# Compteurs
PASS=0
FAIL=0
SKIP=0

# 1. Vérification des prérequis
log "\n--- 1. Vérification des prérequis ---"

if ! command -v git &>/dev/null; then
    error "git est requis"
    FAIL=$((FAIL + 1))
else
    success "git est disponible"
    PASS=$((PASS + 1))
fi

if ! command -v python3 &>/dev/null; then
    error "python3 est requis"
    FAIL=$((FAIL + 1))
else
    success "python3 est disponible"
    PASS=$((PASS + 1))
fi

if ! command -v ffmpeg &>/dev/null; then
    error "ffmpeg est requis"
    FAIL=$((FAIL + 1))
else
    success "ffmpeg est disponible"
    PASS=$((PASS + 1))
fi

DOCKER_AVAILABLE=0
if command -v docker &>/dev/null; then
    DOCKER_AVAILABLE=1
    success "Docker est disponible"
    PASS=$((PASS + 1))
else
    warning "Docker n'est pas disponible"
    SKIP=$((SKIP + 1))
fi

# 2. Mise à jour complète du dépôt
log "\n--- 2. Mise à jour complète du dépôt ---"

if [ -n "$(git status --porcelain)" ]; then
    warning "Des modifications locales non commitées sont présentes"
    git status --short | while read line; do
        warning "  $line"
    done
    if [ -z "${MENSUEL_FORCE:-}" ]; then
        error "Modifications locales détectées - annulation"
        FAIL=$((FAIL + 1))
        exit 1
    else
        warning "Mode FORCE activé - continuation malgré les modifications locales"
    fi
fi

# Mise à jour depuis origin
log "Mise à jour depuis origin/main..."
if git fetch origin 2>&1; then
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
        log "Des mises à jour sont disponibles"
        if git pull 2>&1; then
            success "Dépôt mis à jour"
            PASS=$((PASS + 1))
        else
            error "Echec de la mise à jour"
            FAIL=$((FAIL + 1))
        fi
    else
        success "Dépôt déjà à jour"
        PASS=$((PASS + 1))
    fi
else
    warning "Impossible de récupérer les mises à jour"
    SKIP=$((SKIP + 1))
fi

# 3. Vérification et mise à jour des dépendances Python
log "\n--- 3. Mise à jour des dépendances Python ---"

if [ -f "requirements.txt" ]; then
    log "Vérification des dépendances figées..."
    
    # Vérifier que toutes les dépendances sont figées
    UNPINNED=$(grep -v "^#" requirements.txt | grep -v "^$" | grep -v "==" || true)
    if [ -n "$UNPINNED" ]; then
        error "Certaines dépendances ne sont pas figées avec =="
        echo "$UNPINNED" | while read line; do
            error "  $line"
        done
        FAIL=$((FAIL + 1))
    else
        success "Toutes les dépendances sont figées"
        PASS=$((PASS + 1))
    fi
    
    # Mise à jour de pip et des paquets
    if [ ! -d ".venv" ]; then
        log "Création de l'environnement virtuel..."
        python3 -m venv .venv
    fi
    
    log "Mise à jour de pip..."
    .venv/bin/pip install -q --upgrade pip
    
    log "Réinstallation des dépendances..."
    .venv/bin/pip install -q --force-reinstall -r requirements.txt
    
    if [ -f "requirements-dev.txt" ]; then
        .venv/bin/pip install -q --force-reinstall -r requirements-dev.txt
    fi
    
    success "Dépendances mises à jour"
    PASS=$((PASS + 1))
else
    warning "requirements.txt introuvable"
    SKIP=$((SKIP + 1))
fi

# 4. Vérification du code avec ruff
log "\n--- 4. Vérification du code avec ruff ---"

if [ -f "requirements-dev.txt" ] && [ -d ".venv" ]; then
    if .venv/bin/ruff check app tests scripts --fix 2>&1; then
        success "Aucune erreur ruff trouvée"
        PASS=$((PASS + 1))
    else
        error "Des erreurs ruff ont été trouvées"
        FAIL=$((FAIL + 1))
    fi
else
    warning "ruff non disponible - vérification sautée"
    SKIP=$((SKIP + 1))
fi

# 5. Exécution complète des tests
log "\n--- 5. Exécution complète des tests ---"

if [ -d ".venv" ]; then
    if .venv/bin/python -m pytest tests/ -v --tb=short -x 2>&1; then
        success "Tous les tests ont réussi"
        PASS=$((PASS + 1))
    else
        error "Certains tests ont échoué"
        FAIL=$((FAIL + 1))
    fi
else
    warning "Environnement virtuel non disponible - tests sautés"
    SKIP=$((SKIP + 1))
fi

# 6. Reconstruction complète de l'image Docker
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    log "\n--- 6. Reconstruction complète de l'image Docker ---"
    
    log "Construction sans cache pour intégrer les derniers correctifs..."
    if docker compose build --pull --no-cache 2>&1; then
        success "Image Docker reconstruite avec succès"
        PASS=$((PASS + 1))
    else
        error "Echec de la reconstruction Docker"
        FAIL=$((FAIL + 1))
    fi
else
    warning "Docker non disponible - reconstruction Docker sautée"
    SKIP=$((SKIP + 1))
fi

# 7. Scan de sécurité Trivy complet
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    log "\n--- 7. Scan de sécurité Trivy complet ---"
    
    TRIVY_IMAGE="ghcr.io/aquasecurity/trivy:0.76.2"
    
    log "Scan des fichiers du dépôt..."
    if docker run --rm \
        -v "$(pwd):/src" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$TRIVY_IMAGE" fs --quiet --ignore-unfixed --severity CRITICAL,HIGH /src 2>&1; then
        success "Aucune faille critique ou haute corrigeable dans les fichiers"
        PASS=$((PASS + 1))
    else
        error "Des failles critiques ou hautes corrigeables trouvées dans les fichiers"
        FAIL=$((FAIL + 1))
    fi
    
    log "Scan de l'image Docker..."
    if docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        "$TRIVY_IMAGE" image --quiet --ignore-unfixed --severity CRITICAL,HIGH video-pas-a-pas:local 2>&1; then
        success "Aucune faille critique ou haute corrigeable dans l'image"
        PASS=$((PASS + 1))
    else
        error "Des failles critiques ou hautes corrigeables trouvées dans l'image"
        FAIL=$((FAIL + 1))
    fi
else
    warning "Docker non disponible - scan Trivy sauté"
    SKIP=$((SKIP + 1))
fi

# 8. Test de démarrage et de santé
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    log "\n--- 8. Test de démarrage et de santé ---"
    
    log "Démarrage du service..."
    if docker compose up -d 2>&1; then
        # Attendre le démarrage
        for i in $(seq 1 30); do
            if curl -fs http://localhost:8080/healthz >/dev/null 2>&1; then
                success "Service démarré avec succès"
                PASS=$((PASS + 1))
                break
            fi
            if [ $i -eq 30 ]; then
                error "Service n'a pas démarré à temps"
                FAIL=$((FAIL + 1))
            fi
            sleep 1
        done
        
        # Test de l'API
        log "Test de l'API..."
        if curl -fs http://localhost:8080/api/config >/dev/null 2>&1; then
            success "API accessible"
            PASS=$((PASS + 1))
        else
            error "API non accessible"
            FAIL=$((FAIL + 1))
        fi
        
        # Arrêter le service
        docker compose down 2>/dev/null
    else
        error "Echec du démarrage Docker"
        FAIL=$((FAIL + 1))
    fi
else
    warning "Docker non disponible - tests de démarrage sautés"
    SKIP=$((SKIP + 1))
fi

# 9. Vérification des versions des outils
log "\n--- 9. Vérification des versions des outils ---"

log "Versions des outils utilisés :"
log "  - git: $(git --version 2>&1 || echo 'non disponible')"
log "  - python: $(python3 --version 2>&1 || echo 'non disponible')"
log "  - ffmpeg: $(ffmpeg -version 2>&1 | head -1 || echo 'non disponible')"
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    log "  - docker: $(docker --version 2>&1 || echo 'non disponible')"
    log "  - docker-compose: $(docker compose version 2>&1 || echo 'non disponible')"
fi

success "Vérification des versions terminée"
PASS=$((PASS + 1))

# 10. Nettoyage final
log "\n--- 10. Nettoyage final ---"

log "Nettoyage des anciens jobs..."
if [ -d "data/jobs" ]; then
    find "data/jobs" -type d -mtime +2 -exec rm -rf {} + 2>/dev/null || true
fi

log "Nettoyage des modèles non utilisés..."
if [ -d "data/models" ]; then
    # Garder seulement les modèles utilisés récemment
    find "data/models" -type f -atime +30 -delete 2>/dev/null || true
fi

log "Nettoyage du cache Docker..."
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    docker system prune -f 2>/dev/null || true
fi

success "Nettoyage terminé"
PASS=$((PASS + 1))

# Résumé final
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
log "FIN : Maintenance mensuelle Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
log "Résumé : $PASS réussite(s), $FAIL échec(s), $SKIP sauté(s)"
echo "" | tee -a "$LOG_FILE"

if [ $FAIL -gt 0 ]; then
    error "La maintenance mensuelle a détecté des problèmes critiques !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
elif [ $SKIP -gt 0 ]; then
    warning "La maintenance mensuelle s'est terminée avec des avertissements"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
else
    success "La maintenance mensuelle s'est terminée avec succès !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
fi
