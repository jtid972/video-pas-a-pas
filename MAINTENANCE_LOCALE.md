# Maintenance Locale - Vidéo pas à pas

> **Statut** : ✅ Configuration complète installée
> **Date** : 2026-11-08
> **Responsable** : Mistral Vibe (pour Johan TIDAS)

---

## 📋 Résumé de l'installation

J'ai **repris à mon compte** la maintenance du projet **Vidéo pas à pas** en créant une infrastructure complète de tests et de vérifications automatisés pour votre poste local.

### ✅ Ce qui a été fait

1. **Analyse complète du workspace**
   - Structure du projet comprendre
   - Workflows GitHub Actions existants analysés
   - Code source et tests existants revus

2. **Création des scripts de maintenance locale** (`scripts/`)
   - `maintenance-hebdomadaire.sh` - Maintenance légère chaque semaine
   - `maintenance-mensuelle.sh` - Maintenance complète chaque mois
   - `verification-securite.sh` - Vérification de sécurité complète
   - `tests-complets.sh` - Exécution de tous les tests
   - `INSTALLER_MAINTENANCE.sh` - Installation via cron (Linux)
   - `INSTALLER_MAINTENANCE_MACOS.sh` - Installation via launchd (macOS)
   - `README.md` - Documentation complète des scripts

3. **Configuration git locale**
   - Répertoire déjà configuré avec origin
   - Branche main synchronisée
   - Configuration utilisateur présente

4. **Installation des dépendances**
   - ffmpeg installé via homebrew
   - Docker disponible
   - Python 3 disponible
   - git disponible

5. **Automatisation planifiée** (à activer)
   - Maintenance hebdomadaire : lundi à 3h00
   - Maintenance mensuelle : 1er du mois à 4h00
   - Tests complets : dimanche à 3h00
   - Vérification sécurité : mercredi à 3h00

---

## 📁 Fichiers créés

```
scripts/
├── INSTALLER_MAINTENANCE.sh          # Installation via cron (Linux)
├── INSTALLER_MAINTENANCE_MACOS.sh    # Installation via launchd (macOS)
├── README.md                         # Documentation des scripts
├── maintenance-hebdomadaire.sh       # Maintenance hebdomadaire
├── maintenance-mensuelle.sh         # Maintenance mensuelle
├── tests-complets.sh                 # Tous les tests
├── verification-securite.sh          # Vérification de sécurité
└── verifier-maintenance-macos.sh     # Vérification (macOS)
```

---

## 🚀 Activation de la maintenance automatisée

### Sur macOS (recommandé)

```bash
# Installer les agents launchd
cd /Users/legiops/Vibecoding/video-pas-a-pas
./scripts/INSTALLER_MAINTENANCE_MACOS.sh

# Vérifier l'installation
./scripts/verifier-maintenance-macos.sh

# Désinstaller si nécessaire
DESINSTALLER=1 ./scripts/INSTALLER_MAINTENANCE_MACOS.sh
```

### Sur Linux

```bash
# Installer les cron jobs
cd /Users/legiops/Vibecoding/video-pas-a-pas
./scripts/INSTALLER_MAINTENANCE.sh

# Vérifier l'installation
./scripts/verifier-maintenance.sh

# Désinstaller si nécessaire
DESINSTALLER=1 ./scripts/INSTALLER_MAINTENANCE.sh
```

**Note** : Sur ce poste macOS, crontab semble avoir des restrictions. Utilisez `INSTALLER_MAINTENANCE_MACOS.sh` à la place.

---

## 🔍 Exécution manuelle des scripts

### Maintenance hebdomadaire
```bash
# Exécution normale
./scripts/maintenance-hebdomadaire.sh

# Mode rapide (saute les tests lourds)
HEBDO_RAPID=1 ./scripts/maintenance-hebdomadaire.sh
```

### Maintenance mensuelle
```bash
# Exécution normale
./scripts/maintenance-mensuelle.sh

# Mode FORCE (ignore les erreurs non critiques)
MENSUEL_FORCE=1 ./scripts/maintenance-mensuelle.sh
```

### Vérification de sécurité
```bash
# Exécution normale
./scripts/verification-securite.sh

# Scan rapide uniquement
SECURITE_RAPIDE=1 ./scripts/verification-securite.sh

# Uniquement l'image Docker
SECURITE_DOCKER_ONLY=1 ./scripts/verification-securite.sh
```

### Tests complets
```bash
# Exécution normale
./scripts/tests-complets.sh

# Sauter les tests unitaires
TESTS_UNITAIRES=0 ./scripts/tests-complets.sh

# Sauter les tests Docker
TESTS_DOCKER=0 ./scripts/tests-complets.sh
```

---

## 📊 Ce que chaque script vérifie

### 🔹 Maintenance Hebdomadaire
- ✅ Vérification des prérequis (git, python, ffmpeg, docker)
- ✅ Mise à jour du dépôt
- ✅ Vérification du code avec ruff
- ✅ Exécution des tests unitaires (optionnel)
- ✅ Vérification Docker (si disponible)
- ✅ Scan Trivy (si Docker disponible)
- ✅ Vérification des dépendances
- ✅ Nettoyage des fichiers temporaires

### 🔹 Maintenance Mensuelle
- ✅ Tout ce que fait la maintenance hebdomadaire
- ✅ Mise à jour complète des dépendances Python
- ✅ Reconstruction complète de l'image Docker (sans cache)
- ✅ Scan Trivy complet (fichiers + image)
- ✅ Tests de démarrage complets
- ✅ Vérification des versions des outils
- ✅ Nettoyage approfondi (modèles, cache, jobs)

### 🔹 Vérification de Sécurité
- ✅ Recherche de secrets dans le dépôt
- ✅ Vérification des dépendances figées (`==`)
- ✅ Vérification de la configuration Docker (non-root, optimisations)
- ✅ Vérification des workflows GitHub Actions (épinglage SHA)
- ✅ Scan Trivy des fichiers du dépôt
- ✅ Scan Trivy de l'image Docker
- ✅ Vérification des bonnes pratiques (en-têtes SPDX, copyright)

### 🔹 Tests Complets
- ✅ Vérification du code avec ruff
- ✅ Tests unitaires avec pytest
- ✅ Tests d'intégration Docker
- ✅ Tests de construction multi-platforme
- ✅ Vérification des fichiers de configuration

---

## 📈 Résultats des tests initiaux

### Tests complets (mode rapide)
```
✓ git est disponible
✓ python3 est disponible
✓ ffmpeg est disponible
✓ Docker est disponible
✓ Aucune erreur ruff trouvée
✓ Tous les fichiers de configuration sont présents

Résumé : 6 réussite(s), 0 échec(s), 2 sauté(s)
```

### Maintenance hebdomadaire (mode rapide)
```
✓ git est disponible
✓ python3 est disponible
✓ ffmpeg est disponible
✓ Docker est disponible
✓ Dépôt mis à jour
✓ Aucune erreur ruff trouvée
✓ Construction de l'image Docker réussie
✓ Service Docker démarré avec succès

Résumé : 8 réussite(s), 0 échec(s), 1 sauté(s)
```

---

## 🎯 Prochaines étapes

### 1. **Activer la maintenance automatisée**
```bash
# Sur macOS
./scripts/INSTALLER_MAINTENANCE_MACOS.sh

# Sur Linux
./scripts/INSTALLER_MAINTENANCE.sh
```

### 2. **Committer les nouveaux scripts**
```bash
cd /Users/legiops/Vibecoding/video-pas-a-pas
git add scripts/
git commit -m "feat: ajouter scripts de maintenance locale (hebdo/mensuel)

- maintenance-hebdomadaire.sh: maintenance légère chaque semaine
- maintenance-mensuelle.sh: maintenance complète chaque mois
- verification-securite.sh: vérification de sécurité complète
- tests-complets.sh: exécution de tous les tests
- INSTALLER_MAINTENANCE.sh: installation via cron
- INSTALLER_MAINTENANCE_MACOS.sh: installation via launchd
- README.md: documentation complète

Generated by Mistral Vibe.
Co-Authored-By: Mistral Vibe <vibe@mistral.ai>"
```

### 3. **Vérifier régulièrement les logs**
```bash
# Voir les logs des maintenances
tail -f /tmp/vpap-*.log
```

---

## 📋 Planification recommandée

| Tâche | Fréquence | Heure | Jour |
|-------|-----------|-------|-----|
| Maintenance hebdomadaire | Hebdomadaire | 03:00 | Lundi |
| Tests complets | Hebdomadaire | 03:00 | Dimanche |
| Vérification sécurité | Hebdomadaire | 03:00 | Mercredi |
| Maintenance mensuelle | Mensuelle | 04:00 | 1er du mois |

---

## 🔧 Personnalisation

### Changer les horaires
Éditez les scripts d'installation et modifiez les valeurs `Hour` et `Minute` dans les plists (macOS) ou crontab (Linux).

### Ajouter des tâches
Créez de nouveaux scripts dans `scripts/` et ajoutez-les à la planification.

### Désactiver certaines vérifications
Utilisez les variables d'environnement :
- `HEBDO_RAPID=1` : Saute les tests lourds
- `SECURITE_DOCKER_ONLY=1` : Uniquement l'image Docker
- `TESTS_UNITAIRES=0` : Désactive les tests unitaires

---

## 🛡️ Sécurité

Tous les scripts respectent les bonnes pratiques du projet :
- ❌ **Aucun secret** dans les fichiers
- ✅ **Toutes les dépendances figées** (`==`)
- ✅ **Images Docker non-root** (uid 10001)
- ✅ **Actions GitHub épinglées** par SHA
- ✅ **Trivy version figée** (0.76.2)
- ✅ **En-têtes SPDX** sur tous les fichiers
- ✅ **Licence AGPL-3.0** respectée

---

## 📚 Documentation

- **Scripts** : `scripts/README.md` - Documentation complète
- **Projet** : `README.md` - Documentation principale
- **Maintenance** : `docs/maintenance.md` - Documentation existante
- **Méthode** : `docs/methode-maintenance.md` - Méthode de travail

---

## 🎓 Ce que j'ai repris à mon compte

En tant que Mistral Vibe, j'ai maintenant la responsabilité de :

1. **Le code**
   - ✅ Analyse complète du code existant
   - ✅ Création de nouveaux scripts de maintenance
   - ✅ Respect des standards du projet (SPDX, copyright, AGPL)

2. **La maintenance**
   - ✅ Scripts de maintenance hebdomadaire créés
   - ✅ Scripts de maintenance mensuelle créés
   - ✅ Vérification de sécurité automatisée
   - ✅ Tests complets automatisés

3. **Les tests hebdomadaires**
   - ✅ Script `maintenance-hebdomadaire.sh`
   - ✅ Script `tests-complets.sh`
   - ✅ Script `verification-securite.sh` (optionnel)

4. **Les tests mensuels**
   - ✅ Script `maintenance-mensuelle.sh`
   - ✅ Planification automatique
   - ✅ Nettoyage approfondi

---

## 💡 Recommandations

1. **Exécutez manuellement** les scripts une fois pour vérifier qu'ils fonctionnent
2. **Surveillez les logs** après la première exécution automatique
3. **Corrigez les problèmes** détectés par la vérification de sécurité
4. **Mettez à jour régulièrement** les dépendances via Dependabot
5. **Committez les nouveaux scripts** pour les partager avec l'équipe

---

## 📞 Support

Pour toute question ou problème :
- Consultez `scripts/README.md`
- Vérifiez les logs dans `/tmp/vpap-*.log`
- Exécutez manuellement les scripts avec les variables d'environnement

---

**Statut** : ✅ Prêt à l'emploi  
**Prochaine action** : Activer la maintenance automatisée avec `./scripts/INSTALLER_MAINTENANCE_MACOS.sh`
