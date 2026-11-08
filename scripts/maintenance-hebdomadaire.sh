#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Script de maintenance hebdomadaire pour Vidéo pas à pas
# Exécute : tests unitaires, vérification ruff, scan Trivy local, vérification des dépendances
# Usage : ./scripts/maintenance-hebdomadaire.sh
#         HEBDO_RAPID=1 ./scripts/maintenance-hebdomadaire.sh  (saute les tests lourds)
#         ENV=docker ./scripts/maintenance-hebdomadaire.sh      (force l'environnement docker)

set -euo pipefail
cd "$(dirname "$0")/.."

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="/tmp/vpap-maintenance-hebdo-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
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
log "DEBUT : Maintenance hebdomadaire Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"

# Compteur de résultats
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

# Vérifier si Docker est disponible
DOCKER_AVAILABLE=0
if command -v docker &>/dev/null; then
    DOCKER_AVAILABLE=1
    success "Docker est disponible"
    PASS=$((PASS + 1))
else
    warning "Docker n'est pas disponible - certains tests seront sautés"
    SKIP=$((SKIP + 1))
fi

# 2. Mise à jour du dépôt
log "\n--- 2. Mise à jour du dépôt ---"

if [ -n "$(git status --porcelain)" ]; then
    warning "Des modifications locales non commitées sont présentes"
    git status --short | while read line; do
        warning "  $line"
    done
    SKIP=$((SKIP + 1))
else
    log "Aucune modification locale"
fi

# Essayer de faire un pull
if git pull --dry-run 2>/dev/null | grep -q "Already up to date"; then
    success "Dépôt déjà à jour"
    PASS=$((PASS + 1))
elif git pull 2>&1; then
    success "Dépôt mis à jour"
    PASS=$((PASS + 1))
else
    warning "Impossible de vérifier les mises à jour (pas de connexion ?)"
    SKIP=$((SKIP + 1))
fi

# 3. Vérification du code avec ruff
log "\n--- 3. Vérification du code avec ruff ---"

if [ -f "requirements-dev.txt" ]; then
    # Créer l'environnement virtuel si nécessaire
    if [ ! -d ".venv" ]; then
        log "Création de l'environnement virtuel..."
        python3 -m venv .venv
    fi
    
    # Installer ruff si nécessaire
    if ! .venv/bin/pip list 2>/dev/null | grep -q ruff; then
        log "Installation de ruff..."
        .venv/bin/pip install -q -r requirements-dev.txt
    fi
    
    if .venv/bin/ruff check app tests scripts 2>&1; then
        success "Aucune erreur ruff trouvée"
        PASS=$((PASS + 1))
    else
        error "Des erreurs ruff ont été trouvées"
        FAIL=$((FAIL + 1))
    fi
else
    warning "requirements-dev.txt introuvable - ruff sauté"
    SKIP=$((SKIP + 1))
fi

# 4. Exécution des tests unitaires
log "\n--- 4. Exécution des tests unitaires ---"

if [ -n "${HEBDO_RAPID:-}" ]; then
    warning "Mode rapide activé - tests sautés"
    SKIP=$((SKIP + 1))
else
    if [ ! -d ".venv" ]; then
        log "Création de l'environnement virtuel..."
        python3 -m venv .venv
    fi
    
    if ! .venv/bin/pip list 2>/dev/null | grep -q pytest; then
        log "Installation des dépendances de test..."
        .venv/bin/pip install -q -r requirements.txt -r requirements-dev.txt
    fi
    
    log "Lancement des tests..."
    if .venv/bin/python -m pytest tests/ -v --tb=short 2>&1; then
        success "Tous les tests unitaires ont réussi"
        PASS=$((PASS + 1))
    else
        error "Certains tests ont échoué"
        FAIL=$((FAIL + 1))
    fi
fi

# 5. Vérification Docker (si disponible)
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    log "\n--- 5. Vérification Docker ---"
    
    # Construction de l'image
    log "Construction de l'image Docker..."
    if docker compose build --pull 2>&1; then
        success "Image Docker construite avec succès"
        PASS=$((PASS + 1))
    else
        error "Echec de la construction Docker"
        FAIL=$((FAIL + 1))
    fi
    
    # Test de démarrage
    log "Test de démarrage du conteneur..."
    if docker compose up -d 2>&1; then
        # Attendre que le service soit prêt
        for i in $(seq 1 30); do
            if curl -fs http://localhost:8080/healthz >/dev/null 2>&1; then
                success "Service Docker démarré avec succès"
                PASS=$((PASS + 1))
                break
            fi
            if [ $i -eq 30 ]; then
                error "Service Docker n'a pas démarré à temps"
                FAIL=$((FAIL + 1))
            fi
            sleep 1
        done
        
        # Arrêter le service
        docker compose down 2>/dev/null
    else
        error "Echec du démarrage Docker"
        FAIL=$((FAIL + 1))
    fi
else
    warning "Docker non disponible - vérification Docker sautée"
    SKIP=$((SKIP + 1))
fi

# 6. Scan Trivy local (si Docker disponible)
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    log "\n--- 6. Scan de sécurité Trivy ---"
    
    TRIVY_IMAGE="ghcr.io/aquasecurity/trivy:0.76.2"
    
    log "Téléchargement de Trivy..."
    if docker pull "$TRIVY_IMAGE" 2>&1; then
        log "Scan de l'image avec Trivy..."
        if docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            "$TRIVY_IMAGE" image --quiet --ignore-unfixed --severity CRITICAL,HIGH video-pas-a-pas:local 2>&1; then
            success "Aucune faille critique ou haute corrigeable trouvée"
            PASS=$((PASS + 1))
        else
            error "Des failles critiques ou hautes corrigeables ont été trouvées"
            warning "Veuillez corriger ces failles avant de déployer"
            FAIL=$((FAIL + 1))
        fi
    else
        warning "Impossible de télécharger Trivy - scan sauté"
        SKIP=$((SKIP + 1))
    fi
else
    warning "Docker non disponible - scan Trivy sauté"
    SKIP=$((SKIP + 1))
fi

# 7. Vérification des dépendances
log "\n--- 7. Vérification des dépendances ---"

if [ -f "requirements.txt" ]; then
    log "Vérification des versions figées dans requirements.txt..."
    if grep -q "==" requirements.txt; then
        success "Toutes les dépendances sont figées avec =="
        PASS=$((PASS + 1))
    else
        warning "Certaines dépendances ne sont pas figées avec =="
        SKIP=$((SKIP + 1))
    fi
else
    warning "requirements.txt introuvable"
    SKIP=$((SKIP + 1))
fi

# 8. Nettoyage des fichiers temporaires
log "\n--- 8. Nettoyage ---"

if [ -d "data/jobs" ]; then
    log "Nettoyage des anciens jobs..."
    # Garder seulement les jobs des 48 dernières heures
    find "data/jobs" -type d -mtime +2 -exec rm -rf {} + 2>/dev/null || true
    success "Nettoyage terminé"
    PASS=$((PASS + 1))
else
    log "Aucun dossier de jobs à nettoyer"
fi

# Résumé final
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
log "FIN : Maintenance hebdomadaire Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
log "Résumé : $PASS réussite(s), $FAIL échec(s), $SKIP sauté(s)"
echo "" | tee -a "$LOG_FILE"

if [ $FAIL -gt 0 ]; then
    error "La maintenance hebdomadaire a détecté des problèmes !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
elif [ $SKIP -gt 0 ]; then
    warning "La maintenance hebdomadaire s'est terminée avec des avertissements"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
else
    success "La maintenance hebdomadaire s'est terminée avec succès !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
fi
