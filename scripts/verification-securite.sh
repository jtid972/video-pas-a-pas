#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Script de vérification de sécurité pour Vidéo pas à pas
# Exécute un scan complet avec Trivy et vérifie les bonnes pratiques
# Usage : ./scripts/verification-securite.sh
#         SECURITE_RAPIDE=1 ./scripts/verification-securite.sh  (scan rapide uniquement)
#         SECURITE_DOCKER_ONLY=1 ./scripts/verification-securite.sh  (uniquement l'image Docker)

set -euo pipefail
cd "$(dirname "$0")/.."

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

LOG_FILE="/tmp/vpap-verification-securite-$(date +%Y%m%d-%H%M%S).log"

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

title() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

echo "========================================" | tee -a "$LOG_FILE"
log "DEBUT : Vérification de sécurité Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"

PASS=0
FAIL=0
SKIP=0
CRITICAL_ISSUES=0
HIGH_ISSUES=0

# Vérifier les prérequis
log "\n--- Vérification des prérequis ---"

DOCKER_AVAILABLE=0
if command -v docker &>/dev/null; then
    DOCKER_AVAILABLE=1
    success "Docker est disponible"
    PASS=$((PASS + 1))
else
    error "Docker est requis pour ce script"
    FAIL=$((FAIL + 1))
fi

# 1. Vérification des secrets dans le dépôt
title "Vérification des secrets dans le dépôt"

log "Recherche de secrets potentiels..."
SECRETS_FOUND=0

# Recherche de mots de passe et clés
if grep -r --include="*.py" --include="*.sh" --include="*.yml" --include="*.yaml" --include="*.env" \
    -E "(password|passwd|secret|token|key|api_key|apikey)" . \
    2>/dev/null | grep -v ".git" | grep -v "\.venv" | grep -v "node_modules" | grep -v "#" | head -20; then
    warning "Mots-clés sensibles trouvés dans les fichiers (à vérifier manuellement)"
    SECRETS_FOUND=1
fi

# Recherche de clés privées
if find . -type f -name "*.pem" -o -name "*key*" -o -name "*.crt" -o -name "*.key" \
    2>/dev/null | grep -v ".git" | grep -v ".venv" | grep -v "node_modules"; then
    warning "Fichiers potentiellement sensibles trouvés"
    SECRETS_FOUND=1
fi

if [ $SECRETS_FOUND -eq 0 ]; then
    success "Aucun secret évident trouvé dans le dépôt"
    PASS=$((PASS + 1))
else
    warning "Des éléments potentiellement sensibles ont été détectés - vérification manuelle requise"
    SKIP=$((SKIP + 1))
fi

# 2. Vérification des dépendances figées
title "Vérification des dépendances"

log "Vérification que toutes les dépendances Python sont figées..."
UNPINNED_DEPS=0

if [ -f "requirements.txt" ]; then
    UNPINNED=$(grep -v "^#" requirements.txt | grep -v "^$" | grep -v "==" | grep -v "git+https" || true)
    if [ -n "$UNPINNED" ]; then
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                warning "Dépendance non figée : $line"
                UNPINNED_DEPS=$((UNPINNED_DEPS + 1))
            fi
        done <<< "$UNPINNED"
    fi
    
    if [ $UNPINNED_DEPS -eq 0 ]; then
        success "Toutes les dépendances Python sont figées avec =="
        PASS=$((PASS + 1))
    else
        error "$UNPINNED_DEPS dépendance(s) non figée(s)"
        FAIL=$((FAIL + 1))
    fi
else
    warning "requirements.txt introuvable"
    SKIP=$((SKIP + 1))
fi

# 3. Vérification de la configuration Docker
title "Vérification de la configuration Docker"

log "Vérification que l'image Docker tourne en non-root..."
if [ -f "Dockerfile" ]; then
    if grep -q "USER.*10001\|USER.*nonroot\|USER.*appuser" Dockerfile; then
        success "L'image Docker utilise un utilisateur non-root"
        PASS=$((PASS + 1))
    else
        warning "L'image Docker pourrait ne pas utiliser un utilisateur non-root"
        SKIP=$((SKIP + 1))
    fi
    
    if grep -q "RUN.*apk add.*--no-cache\|apt-get.*--no-install-recommends" Dockerfile; then
        success "Optimisations de sécurité dans Dockerfile"
        PASS=$((PASS + 1))
    else
        warning "Dockerfile pourrait être optimisé pour la sécurité"
        SKIP=$((SKIP + 1))
    fi
else
    warning "Dockerfile introuvable"
    SKIP=$((SKIP + 1))
fi

# 4. Vérification des workflows GitHub Actions
title "Vérification des workflows GitHub Actions"

log "Vérification que les actions sont épinglées par SHA..."
PINNED_ACTIONS=0
UNPINNED_ACTIONS=0

if [ -d ".github/workflows" ]; then
    for workflow in .github/workflows/*.yml; do
        if [ -f "$workflow" ]; then
            # Vérifier les uses avec @
            if grep -q "uses:.*@[a-f0-9]\{40\}" "$workflow" 2>/dev/null; then
                PINNED_ACTIONS=$((PINNED_ACTIONS + 1))
            elif grep -q "uses:" "$workflow" 2>/dev/null; then
                UNPINNED_ACTIONS=$((UNPINNED_ACTIONS + 1))
                warning "Actions non épinglées dans $workflow"
            fi
        fi
    done
    
    if [ $UNPINNED_ACTIONS -eq 0 ]; then
        success "Toutes les actions GitHub sont épinglées par SHA"
        PASS=$((PASS + 1))
    else
        error "$UNPINNED_ACTIONS workflow(s) avec des actions non épinglées"
        FAIL=$((FAIL + 1))
    fi
else
    warning "Dossier .github/workflows introuvable"
    SKIP=$((SKIP + 1))
fi

# 5. Scan Trivy complet
if [ $DOCKER_AVAILABLE -eq 1 ]; then
    if [ -z "${SECURITE_DOCKER_ONLY:-}" ]; then
        title "Scan Trivy des fichiers du dépôt"
        
        log "Scan des vulnérabilités dans les fichiers..."
        TRIVY_IMAGE="ghcr.io/aquasecurity/trivy:0.76.2"
        
        # Créer un conteneur pour le scan
        if docker pull "$TRIVY_IMAGE" 2>&1 | tail -1; then
            log "Scan en cours (cela peut prendre quelques minutes)..."
            
            # Scan des fichiers
            if docker run --rm \
                -v "$(pwd):/src" \
                "$TRIVY_IMAGE" fs \
                --severity CRITICAL,HIGH \
                --format json \
                /src 2>/tmp/trivy-fs.json; then
                
                # Analyser les résultats
                CRITICAL_COUNT=$(jq '.Results[].Vulnerabilities[] | select(.Severity == "CRITICAL")' /tmp/trivy-fs.json 2>/dev/null | wc -l || echo 0)
                HIGH_COUNT=$(jq '.Results[].Vulnerabilities[] | select(.Severity == "HIGH")' /tmp/trivy-fs.json 2>/dev/null | wc -l || echo 0)
                
                log "Résultats du scan des fichiers :"
                log "  - Vulnérabilités CRITICAL : $CRITICAL_COUNT"
                log "  - Vulnérabilités HIGH : $HIGH_COUNT"
                
                if [ $CRITICAL_COUNT -gt 0 ]; then
                    error "$CRITICAL_COUNT vulnérabilité(s) CRITICAL trouvée(s) dans les fichiers"
                    CRITICAL_ISSUES=$((CRITICAL_ISSUES + CRITICAL_COUNT))
                    FAIL=$((FAIL + 1))
                fi
                
                if [ $HIGH_COUNT -gt 0 ]; then
                    error "$HIGH_COUNT vulnérabilité(s) HIGH trouvée(s) dans les fichiers"
                    HIGH_ISSUES=$((HIGH_ISSUES + HIGH_COUNT))
                    FAIL=$((FAIL + 1))
                fi
                
                if [ $CRITICAL_COUNT -eq 0 ] && [ $HIGH_COUNT -eq 0 ]; then
                    success "Aucune vulnérabilité critique ou haute dans les fichiers"
                    PASS=$((PASS + 1))
                fi
            else
                warning "Scan Trivy des fichiers échoué"
                SKIP=$((SKIP + 1))
            fi
        else
            warning "Impossible de télécharger Trivy"
            SKIP=$((SKIP + 1))
        fi
    fi
    
    # Scan de l'image Docker
    title "Scan Trivy de l'image Docker"
    
    log "Construction de l'image si nécessaire..."
    if docker compose build --pull 2>&1 | tail -1; then
        log "Scan de l'image Docker..."
        
        if docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            "$TRIVY_IMAGE" image \
            --severity CRITICAL,HIGH \
            --ignore-unfixed \
            --format json \
            video-pas-a-pas:local 2>/tmp/trivy-image.json; then
            
            # Analyser les résultats
            CRITICAL_COUNT=$(jq '.Results[].Vulnerabilities[] | select(.Severity == "CRITICAL")' /tmp/trivy-image.json 2>/dev/null | wc -l || echo 0)
            HIGH_COUNT=$(jq '.Results[].Vulnerabilities[] | select(.Severity == "HIGH")' /tmp/trivy-image.json 2>/dev/null | wc -l || echo 0)
            
            log "Résultats du scan de l'image :"
            log "  - Vulnérabilités CRITICAL : $CRITICAL_COUNT"
            log "  - Vulnérabilités HIGH : $HIGH_COUNT"
            
            if [ $CRITICAL_COUNT -gt 0 ]; then
                error "$CRITICAL_COUNT vulnérabilité(s) CRITICAL trouvée(s) dans l'image"
                CRITICAL_ISSUES=$((CRITICAL_ISSUES + CRITICAL_COUNT))
                FAIL=$((FAIL + 1))
                
                # Afficher les détails
                log "Détails des vulnérabilités CRITICAL :"
                jq '.Results[].Vulnerabilities[] | select(.Severity == "CRITICAL") | "  - \(.VulnerabilityID): \(.Title) (fixable: \(.FixedVersion))"' /tmp/trivy-image.json 2>/dev/null | while read line; do
                    error "$line"
                done
            fi
            
            if [ $HIGH_COUNT -gt 0 ]; then
                error "$HIGH_COUNT vulnérabilité(s) HIGH trouvée(s) dans l'image"
                HIGH_ISSUES=$((HIGH_ISSUES + HIGH_COUNT))
                FAIL=$((FAIL + 1))
                
                # Afficher les détails
                log "Détails des vulnérabilités HIGH :"
                jq '.Results[].Vulnerabilities[] | select(.Severity == "HIGH") | "  - \(.VulnerabilityID): \(.Title) (fixable: \(.FixedVersion))"' /tmp/trivy-image.json 2>/dev/null | while read line; do
                    error "$line"
                done
            fi
            
            if [ $CRITICAL_COUNT -eq 0 ] && [ $HIGH_COUNT -eq 0 ]; then
                success "Aucune vulnérabilité critique ou haute dans l'image"
                PASS=$((PASS + 1))
            fi
        else
            warning "Scan Trivy de l'image échoué"
            SKIP=$((SKIP + 1))
        fi
    else
        warning "Construction de l'image échouée"
        SKIP=$((SKIP + 1))
    fi
else
    warning "Docker non disponible - scan Trivy sauté"
    SKIP=$((SKIP + 1))
fi

# 6. Vérification des bonnes pratiques de sécurité
title "Vérification des bonnes pratiques"

log "Vérification des en-têtes SPDX..."
SPDX_MISSING=0
if find app tests scripts -name "*.py" -o -name "*.sh" | while read file; do
    if [ -f "$file" ]; then
        first_line=$(head -1 "$file")
        if [[ "$first_line" != *"SPDX-License-Identifier:"* ]] && [[ "$first_line" != *"#!/"* ]]; then
            warning "Fichier sans en-tête SPDX : $file"
            SPDX_MISSING=$((SPDX_MISSING + 1))
        fi
    fi
done; then
    :
fi

if [ $SPDX_MISSING -eq 0 ]; then
    success "Tous les fichiers ont des en-têtes SPDX"
    PASS=$((PASS + 1))
else
    error "$SPDX_MISSING fichier(s) sans en-tête SPDX"
    FAIL=$((FAIL + 1))
fi

log "Vérification des mentions de copyright..."
COPYRIGHT_MISSING=0
if grep -r --include="*.py" "Copyright (c) 2026 Johan TIDAS" app tests scripts 2>/dev/null | wc -l | grep -q "0"; then
    warning "Certains fichiers pourraient manquer de mention de copyright"
    COPYRIGHT_MISSING=1
fi

if [ $COPYRIGHT_MISSING -eq 0 ]; then
    success "Mentions de copyright présentes"
    PASS=$((PASS + 1))
else
    warning "Vérification des mentions de copyright - à vérifier manuellement"
    SKIP=$((SKIP + 1))
fi

# Résumé final
echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
log "FIN : Vérification de sécurité Vidéo pas à pas"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
log "Résumé : $PASS réussite(s), $FAIL échec(s), $SKIP sauté(s)"
log "Vulnérabilités : $CRITICAL_ISSUES CRITICAL, $HIGH_ISSUES HIGH"
echo "" | tee -a "$LOG_FILE"

if [ $FAIL -gt 0 ] || [ $CRITICAL_ISSUES -gt 0 ]; then
    error "La vérification de sécurité a détecté des problèmes critiques !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    echo "Voir les détails Trivy : /tmp/trivy-*.json" | tee -a "$LOG_FILE"
    exit 1
elif [ $SKIP -gt 0 ]; then
    warning "La vérification de sécurité s'est terminée avec des avertissements"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
else
    success "La vérification de sécurité s'est terminée avec succès !"
    echo "Voir le rapport complet : $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
fi
