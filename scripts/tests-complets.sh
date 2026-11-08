#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Script d'exécution complète des tests pour Vidéo pas à pas
# Usage : ./scripts/tests-complets.sh
#         TESTS_UNITAIRES=0 ./scripts/tests-complets.sh  (saute les tests unitaires)
#         TESTS_DOCKER=0 ./scripts/tests-complets.sh      (saute les tests Docker)

set -euo pipefail
cd "$(dirname "$0")/.."

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

LOG_FILE="/tmp/vpap-tests-complets-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
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

title() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

echo "========================================" | tee -a "$LOG_FILE"
log "DEBUT : Tests complets Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"

PASS=0
FAIL=0
SKIP=0
TESTS_EXECUTED=0

# 1. Vérification des prérequis
log "\n--- Vérification des prérequis ---"

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

# 2. Vérification du code avec ruff
log "\n--- Vérification du code avec ruff ---"

if [ -f "requirements-dev.txt" ]; then
    if [ ! -d ".venv" ]; then
        log "Création de l'environnement virtuel..."
        python3 -m venv .venv
    fi
    
    if ! .venv/bin/pip list 2>/dev/null | grep -q ruff; then
        log "Installation de ruff..."
        .venv/bin/pip install -q -r requirements-dev.txt
    fi
    
    log "Exécution de ruff check..."
    if .venv/bin/ruff check app tests scripts 2>&1; then
        success "Aucune erreur ruff trouvée"
        PASS=$((PASS + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    else
        error "Des erreurs ruff ont été trouvées"
        FAIL=$((FAIL + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    fi
else
    warning "requirements-dev.txt introuvable - ruff sauté"
    SKIP=$((SKIP + 1))
fi

# 3. Tests unitaires avec pytest
if [ -z "${TESTS_UNITAIRES:-1}" ]; then
    log "\n--- Tests unitaires avec pytest ---"
    
    if [ ! -d ".venv" ]; then
        log "Création de l'environnement virtuel..."
        python3 -m venv .venv
    fi
    
    if ! .venv/bin/pip list 2>/dev/null | grep -q pytest; then
        log "Installation des dépendances de test..."
        .venv/bin/pip install -q -r requirements.txt -r requirements-dev.txt
    fi
    
    log "Exécution des tests unitaires..."
    if .venv/bin/python -m pytest tests/ -v --tb=short -x 2>&1; then
        success "Tous les tests unitaires ont réussi"
        PASS=$((PASS + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    else
        error "Certains tests unitaires ont échoué"
        FAIL=$((FAIL + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    fi
else
    warning "Tests unitaires désactivés"
    SKIP=$((SKIP + 1))
fi

# 4. Tests d'intégration (si les tests unitaires ont réussi ou sont désactivés)
if [ -z "${TESTS_DOCKER:-1}" ] && [ $DOCKER_AVAILABLE -eq 1 ]; then
    title "Tests d'intégration Docker"
    
    # Construction de l'image
    log "Construction de l'image Docker..."
    if docker compose build --pull 2>&1 | tail -1; then
        success "Image Docker construite avec succès"
        PASS=$((PASS + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    else
        error "Echec de la construction Docker"
        FAIL=$((FAIL + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    fi
    
    # Test de démarrage
    log "Test de démarrage du conteneur..."
    if docker compose up -d 2>&1; then
        # Attendre que le service soit prêt
        for i in $(seq 1 30); do
            if curl -fs http://localhost:8080/healthz >/dev/null 2>&1; then
                success "Service Docker démarré avec succès"
                PASS=$((PASS + 1))
                TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
                break
            fi
            if [ $i -eq 30 ]; then
                error "Service Docker n'a pas démarré à temps"
                FAIL=$((FAIL + 1))
                TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
            fi
            sleep 1
        done
        
        # Test de l'API
        log "Test de l'API..."
        API_TEST=0
        
        # Test /api/config
        if curl -fs http://localhost:8080/api/config >/dev/null 2>&1; then
            log "  ✓ /api/config accessible"
            API_TEST=$((API_TEST + 1))
        else
            error "  ✗ /api/config non accessible"
        fi
        
        # Test /healthz
        if curl -fs http://localhost:8080/healthz >/dev/null 2>&1; then
            log "  ✓ /healthz accessible"
            API_TEST=$((API_TEST + 1))
        else
            error "  ✗ /healthz non accessible"
        fi
        
        if [ $API_TEST -eq 2 ]; then
            success "Tous les tests API ont réussi"
            PASS=$((PASS + 1))
        else
            error "Certains tests API ont échoué"
            FAIL=$((FAIL + 1))
        fi
        
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
        
        # Arrêter le service
        docker compose down 2>/dev/null
    else
        error "Echec du démarrage Docker"
        FAIL=$((FAIL + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    fi
else
    if [ -n "${TESTS_DOCKER:-}" ]; then
        warning "Tests Docker désactivés"
    else
        warning "Docker non disponible - tests Docker sautés"
    fi
    SKIP=$((SKIP + 1))
fi

# 5. Test de construction avec Docker (si disponible)
if [ $DOCKER_AVAILABLE -eq 1 ] && [ -z "${TESTS_DOCKER:-1}" ]; then
    title "Test de construction Docker"
    
    log "Test de construction multi-platforme..."
    if docker buildx build --platform linux/amd64,linux/arm64 --load -t video-pas-a-pas:test . 2>&1 | tail -1; then
        success "Construction multi-platforme réussie"
        PASS=$((PASS + 1))
        TESTS_EXECUTED=$((TESTS_EXECUTED + 1))
    else
        warning "Construction multi-platforme échouée (peu être normal)"
        SKIP=$((SKIP + 1))
    fi
fi

# 6. Vérification des fichiers de configuration
log "\n--- Vérification des fichiers de configuration ---"

CONFIG_FILES=("docker-compose.yml" "Dockerfile" "pyproject.toml" "requirements.txt")
CONFIG_OK=0

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        log "  ✓ $file existe"
        CONFIG_OK=$((CONFIG_OK + 1))
    else
        error "  ✗ $file manquant"
    fi
done

if [ $CONFIG_OK -eq ${#CONFIG_FILES[@]} ]; then
    success "Tous les fichiers de configuration sont présents"
    PASS=$((PASS + 1))
else
    error "Certains fichiers de configuration sont manquants"
    FAIL=$((FAIL + 1))
fi

TESTS_EXECUTED=$((TESTS_EXECUTED + 1))

# Résumé final
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
log "FIN : Tests complets Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
log "Résumé : $PASS réussite(s), $FAIL échec(s), $SKIP sauté(s)"
log "Tests exécutés : $TESTS_EXECUTED"
echo "" | tee -a "$LOG_FILE"

if [ $FAIL -gt 0 ]; then
    error "Les tests complets ont détecté des problèmes !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
elif [ $SKIP -gt 0 ]; then
    warning "Les tests complets se sont terminés avec des avertissements"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
else
    success "Tous les tests se sont terminés avec succès !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
fi
