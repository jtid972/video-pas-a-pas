#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Script d'installation de la maintenance automatisée pour Vidéo pas à pas
# Installe les cron jobs pour les tests hebdomadaires et mensuels
# Usage : ./scripts/INSTALLER_MAINTENANCE.sh
#         DESINSTALLER=1 ./scripts/INSTALLER_MAINTENANCE.sh  (supprime les cron jobs)

set -euo pipefail

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}$1${NC}"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

REPO_DIR="/Users/legiops/Vibecoding/video-pas-a-pas"
CRON_FILE="/tmp/vpap-maintenance.cron"

# Vérifier que le script est exécuté depuis le bon répertoire
if [ ! -d "$REPO_DIR" ]; then
    error "Le répertoire du dépôt est introuvable : $REPO_DIR"
    exit 1
fi

cd "$REPO_DIR"

if [ -n "${DESINSTALLER:-}" ]; then
    log "\n========================================"
    log "DESINSTALLATION de la maintenance automatisée"
    log "========================================"
    
    # Supprimer les cron jobs existants
    if crontab -l 2>/dev/null | grep -q "vpap-maintenance"; then
        log "\nSuppression des cron jobs existants..."
        (crontab -l 2>/dev/null | grep -v "vpap-maintenance" || true) | crontab -
        success "Cron jobs supprimés"
    else
        log "Aucun cron job à supprimer"
    fi
    
    # Supprimer les fichiers de log
    log "\nNettoyage des fichiers de log..."
    find /tmp -name "vpap-maintenance*.log" -delete 2>/dev/null || true
    find /tmp -name "vpap-tests-complets*.log" -delete 2>/dev/null || true
    find /tmp -name "vpap-verification-securite*.log" -delete 2>/dev/null || true
    success "Fichiers de log supprimés"
    
    log "\nLa maintenance automatisée a été désinstallée."
    exit 0
fi

log "\n========================================"
log "INSTALLATION de la maintenance automatisée"
log "========================================"

# Vérifier que les scripts existent
SCRIPTS=("maintenance-hebdomadaire.sh" "maintenance-mensuelle.sh" "verification-securite.sh" "tests-complets.sh")

log "\nVérification des scripts..."
for script in "${SCRIPTS[@]}"; do
    if [ -f "scripts/$script" ]; then
        success "scripts/$script existe"
    else
        error "scripts/$script est introuvable"
        exit 1
    fi
done

# Vérifier les permissions
log "\nVérification des permissions..."
for script in "${SCRIPTS[@]}"; do
    if [ -x "scripts/$script" ]; then
        success "scripts/$script est exécutable"
    else
        log "Rendre scripts/$script exécutable..."
        chmod +x "scripts/$script"
        success "scripts/$script est maintenant exécutable"
    fi
done

# Créer le fichier cron
log "\nCréation des cron jobs..."

# Heure locale : utiliser le fuseau horaire du système
TZ=$(date +%Z)
log "Fuseau horaire détecté : $TZ"

# Déterminer l'heure en fonction du fuseau
# Pour l'Europe (CET/CEST), on utilise 2h/3h du matin
# Pour d'autres fuseaux, ajuster si nécessaire
if [[ "$TZ" == *"CET"* ]] || [[ "$TZ" == *"CEST"* ]] || [[ "$TZ" == *"Europe/Paris"* ]]; then
    HEBDO_HEURE="03:00"
    MENSUEL_HEURE="04:00"
    log "Fuseau horaire Europe - Heures planifiées : hebdo à $HEBDO_HEURE, mensuel à $MENSUEL_HEURE"
elif [[ "$TZ" == *"UTC"* ]]; then
    HEBDO_HEURE="02:00"
    MENSUEL_HEURE="03:00"
    log "Fuseau horaire UTC - Heures planifiées : hebdo à $HEBDO_HEURE, mensuel à $MENSUEL_HEURE"
else
    HEBDO_HEURE="02:00"
    MENSUEL_HEURE="03:00"
    log "Fuseau horaire inconnu - Heures planifiées par défaut : hebdo à $HEBDO_HEURE, mensuel à $MENSUEL_HEURE"
fi

# Créer le fichier cron
cat > "$CRON_FILE" <<EOF
# Maintenance automatisée Vidéo pas à pas
# Généré par INSTALLER_MAINTENANCE.sh

# Logs dans /tmp/vpap-maintenance-*.log

# Test complet chaque dimanche à $HEBDO_HEURE
0 $HEBDO_HEURE * * 0 cd $REPO_DIR && ./scripts/tests-complets.sh >> /tmp/vpap-maintenance-hebdo-$(date +\%Y\%m\%d).log 2>&1

# Vérification de sécurité chaque mercredi à $HEBDO_HEURE
0 $HEBDO_HEURE * * 3 cd $REPO_DIR && ./scripts/verification-securite.sh >> /tmp/vpap-verification-securite-$(date +\%Y\%m\%d).log 2>&1

# Maintenance mensuelle le 1er du mois à $MENSUEL_HEURE
0 $MENSUEL_HEURE 1 * * cd $REPO_DIR && ./scripts/maintenance-mensuelle.sh >> /tmp/vpap-maintenance-mensuelle-$(date +\%Y\%m\%d).log 2>&1

# Maintenance hebdomadaire chaque lundi à $HEBDO_HEURE
0 $HEBDO_HEURE * * 1 cd $REPO_DIR && ./scripts/maintenance-hebdomadaire.sh >> /tmp/vpap-maintenance-hebdomadaire-$(date +\%Y\%m\%d).log 2>&1
EOF

log "Fichier cron créé : $CRON_FILE"

# Afficher le contenu du cron
log "\nContenu du cron :"
cat "$CRON_FILE"

# Installer le cron
log "\nInstallation du cron..."

# Sauvegarder l'ancien crontab
if crontab -l 2>/dev/null > /tmp/vpap-crontab-backup; then
    log "Ancien crontab sauvegardé dans /tmp/vpap-crontab-backup"
fi

# Ajouter les nouveaux cron jobs
(crontab -l 2>/dev/null; cat "$CRON_FILE") | crontab -
success "Cron jobs installés"

# Vérifier que les cron jobs ont été ajoutés
if crontab -l 2>/dev/null | grep -q "vpap-maintenance"; then
    log "\nCron jobs installés avec succès :"
    crontab -l 2>/dev/null | grep "vpap-maintenance"
else
    error "Echec de l'installation des cron jobs"
    exit 1
fi

# Créer un script de vérification
log "\nCréation d'un script de vérification..."
cat > "$REPO_DIR/scripts/verifier-maintenance.sh" << 'EOFVERIF'
#!/usr/bin/env bash
# Vérifie que les cron jobs de maintenance sont installés

echo "Cron jobs de maintenance installés :"
echo "====================================="
crontab -l 2>/dev/null | grep "vpap-maintenance" || echo "Aucun cron job trouvé"
EOFVERIF

chmod +x "$REPO_DIR/scripts/verifier-maintenance.sh"
success "Script de vérification créé"

# Résumé
log "\n========================================"
log "INSTALLATION TERMINEE"
log "========================================"
log ""
log "Les tâches suivantes ont été planifiées :"
log "  - Maintenance hebdomadaire : chaque lundi à $HEBDO_HEURE"
log "  - Tests complets : chaque dimanche à $HEBDO_HEURE"
log "  - Vérification sécurité : chaque mercredi à $HEBDO_HEURE"
log "  - Maintenance mensuelle : le 1er du mois à $MENSUEL_HEURE"
log ""
log "Fichiers de log : /tmp/vpap-*.log"
log ""
log "Pour désinstaller : DESINSTALLER=1 ./scripts/INSTALLER_MAINTENANCE.sh"
log ""
log "Pour vérifier : ./scripts/verifier-maintenance.sh"
