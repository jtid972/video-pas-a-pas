#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Script d'installation de la maintenance automatisée pour macOS (via launchd)
# Alternative à cron pour macOS où crontab peut être restreint
# Usage : ./scripts/INSTALLER_MAINTENANCE_MACOS.sh
#         DESINSTALLER=1 ./scripts/INSTALLER_MAINTENANCE_MACOS.sh

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
PLIST_DIR="$HOME/Library/LaunchAgents"

# Vérifier que le script est exécuté depuis le bon répertoire
if [ ! -d "$REPO_DIR" ]; then
    error "Le répertoire du dépôt est introuvable : $REPO_DIR"
    exit 1
fi

cd "$REPO_DIR"

# Créer le dossier LaunchAgents si nécessaire
mkdir -p "$PLIST_DIR"

if [ -n "${DESINSTALLER:-}" ]; then
    log "\n========================================"
    log "DESINSTALLATION de la maintenance automatisée (macOS)"
    log "========================================"
    
    # Désinstaller les agents launchd
    PLISTS=(
        "com.vpap.maintenance-hebdomadaire.plist"
        "com.vpap.maintenance-mensuelle.plist"
        "com.vpap.tests-complets.plist"
        "com.vpap.verification-securite.plist"
    )
    
    for plist in "${PLISTS[@]}"; do
        PLIST_FILE="$PLIST_DIR/$plist"
        if [ -f "$PLIST_FILE" ]; then
            log "Déchargement de $plist..."
            launchctl unload "$PLIST_FILE" 2>/dev/null || true
            rm -f "$PLIST_FILE"
            success "$plist supprimé"
        else
            log "$plist non trouvé"
        fi
    done
    
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
log "INSTALLATION de la maintenance automatisée (macOS)"
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

# Créer les plists pour launchd
log "\nCréation des agents launchd..."

# 1. Maintenance hebdomadaire (lundi à 3h00)
cat > "$PLIST_DIR/com.vpap.maintenance-hebdomadaire.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vpap.maintenance-hebdomadaire</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>cd /Users/legiops/Vibecoding/video-pas-a-pas && ./scripts/maintenance-hebdomadaire.sh >> /tmp/vpap-maintenance-hebdomadaire-$(date +\%Y\%m\%d).log 2>&1</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
        <key>Weekday</key>
        <integer>1</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/vpap-maintenance-hebdomadaire.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/vpap-maintenance-hebdomadaire-error.log</string>
</dict>
</plist>
EOF

success "com.vpap.maintenance-hebdomadaire.plist créé"

# 2. Maintenance mensuelle (1er du mois à 4h00)
cat > "$PLIST_DIR/com.vpap.maintenance-mensuelle.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vpap.maintenance-mensuelle</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>cd /Users/legiops/Vibecoding/video-pas-a-pas && ./scripts/maintenance-mensuelle.sh >> /tmp/vpap-maintenance-mensuelle-$(date +\%Y\%m\%d).log 2>&1</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
        <key>Day</key>
        <integer>1</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/vpap-maintenance-mensuelle.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/vpap-maintenance-mensuelle-error.log</string>
</dict>
</plist>
EOF

success "com.vpap.maintenance-mensuelle.plist créé"

# 3. Tests complets (dimanche à 3h00)
cat > "$PLIST_DIR/com.vpap.tests-complets.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vpap.tests-complets</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>cd /Users/legiops/Vibecoding/video-pas-a-pas && ./scripts/tests-complets.sh >> /tmp/vpap-tests-complets-$(date +\%Y\%m\%d).log 2>&1</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
        <key>Weekday</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/vpap-tests-complets.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/vpap-tests-complets-error.log</string>
</dict>
</plist>
EOF

success "com.vpap.tests-complets.plist créé"

# 4. Vérification de sécurité (mercredi à 3h00)
cat > "$PLIST_DIR/com.vpap.verification-securite.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vpap.verification-securite</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>cd /Users/legiops/Vibecoding/video-pas-a-pas && ./scripts/verification-securite.sh >> /tmp/vpap-verification-securite-$(date +\%Y\%m\%d).log 2>&1</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
        <key>Weekday</key>
        <integer>3</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/vpap-verification-securite.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/vpap-verification-securite-error.log</string>
</dict>
</plist>
EOF

success "com.vpap.verification-securite.plist créé"

# Charger les agents
log "\nChargement des agents launchd..."

PLISTS=(
    "com.vpap.maintenance-hebdomadaire.plist"
    "com.vpap.maintenance-mensuelle.plist"
    "com.vpap.tests-complets.plist"
    "com.vpap.verification-securite.plist"
)

for plist in "${PLISTS[@]}"; do
    PLIST_FILE="$PLIST_DIR/$plist"
    log "Chargement de $plist..."
    launchctl load "$PLIST_FILE" 2>/dev/null || true
    success "$plist chargé"
done

# Vérifier que les agents sont chargés
log "\nVérification des agents chargés..."
launchctl list | grep com.vpap || warning "Certains agents pourraient ne pas être chargés"

# Créer un script de vérification
cat > "$REPO_DIR/scripts/verifier-maintenance-macos.sh" << 'EOFVERIF'
#!/usr/bin/env bash
# Vérifie que les agents launchd de maintenance sont installés

echo "Agents launchd de maintenance installés :"
echo "========================================"
launchctl list | grep com.vpap || echo "Aucun agent trouvé"
echo ""
echo "Fichiers plist :"
ls -la "$HOME/Library/LaunchAgents/com.vpap.*.plist" 2>/dev/null || echo "Aucun fichier plist trouvé"
EOFVERIF

chmod +x "$REPO_DIR/scripts/verifier-maintenance-macos.sh"
success "Script de vérification créé"

# Résumé
log "\n========================================"
log "INSTALLATION TERMINEE (macOS)"
log "========================================"
log ""
log "Les tâches suivantes ont été planifiées :"
log "  - Maintenance hebdomadaire : chaque lundi à 03:00"
log "  - Maintenance mensuelle : le 1er du mois à 04:00"
log "  - Tests complets : chaque dimanche à 03:00"
log "  - Vérification sécurité : chaque mercredi à 03:00"
log ""
log "Fichiers de configuration : $PLIST_DIR/com.vpap.*.plist"
log "Fichiers de log : /tmp/vpap-*.log"
log ""
log "Pour désinstaller : DESINSTALLER=1 ./scripts/INSTALLER_MAINTENANCE_MACOS.sh"
log ""
log "Pour vérifier : ./scripts/verifier-maintenance-macos.sh"
log ""
log "Note : Les agents launchd ne s'exécutent que lorsque l'utilisateur est connecté."
log "       Pour les exécuter même sans connexion, utilisez launchd système."
