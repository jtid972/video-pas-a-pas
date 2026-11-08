# Scripts de Maintenance pour Vidéo pas à pas

Ce dossier contient les scripts pour la **maintenance automatisée** locale du projet Vidéo pas à pas.

## Scripts disponibles

### 1. `INSTALLER_MAINTENANCE.sh`
**Installation de la maintenance automatisée via cron**

```bash
# Installer les cron jobs pour les tests réguliers
./scripts/INSTALLER_MAINTENANCE.sh

# Désinstaller
DESINSTALLER=1 ./scripts/INSTALLER_MAINTENANCE.sh

# Vérifier l'installation
./scripts/verifier-maintenance.sh
```

**Planification par défaut (ajustée selon le fuseau horaire) :**
- **Maintenance hebdomadaire** : chaque lundi à 3h00
- **Tests complets** : chaque dimanche à 3h00
- **Vérification de sécurité** : chaque mercredi à 3h00
- **Maintenance mensuelle** : le 1er du mois à 4h00

**Logs** : Stockés dans `/tmp/vpap-*.log`

---

### 2. `maintenance-hebdomadaire.sh`
**Maintenance légère chaque semaine**

```bash
# Exécution normale
./scripts/maintenance-hebdomadaire.sh

# Mode rapide (saute les tests lourds)
HEBDO_RAPID=1 ./scripts/maintenance-hebdomadaire.sh

# Forcer l'environnement Docker
ENV=docker ./scripts/maintenance-hebdomadaire.sh
```

**Ce qu'il fait :**
- ✓ Vérification des prérequis (git, python, ffmpeg, docker)
- ✓ Mise à jour du dépôt
- ✓ Vérification du code avec ruff
- ✓ Exécution des tests unitaires
- ✓ Vérification Docker (si disponible)
- ✓ Scan Trivy (si Docker disponible)
- ✓ Vérification des dépendances
- ✓ Nettoyage des fichiers temporaires

---

### 3. `maintenance-mensuelle.sh`
**Maintenance complète chaque mois**

```bash
# Exécution normale
./scripts/maintenance-mensuelle.sh

# Mode FORCE (ignore les erreurs non critiques)
MENSUEL_FORCE=1 ./scripts/maintenance-mensuelle.sh
```

**Ce qu'il fait :**
- ✓ Tout ce que fait la maintenance hebdomadaire
- ✓ Mise à jour complète des dépendances Python
- ✓ Reconstruction complète de l'image Docker (sans cache)
- ✓ Scan Trivy complet (fichiers + image)
- ✓ Tests de démarrage complets
- ✓ Vérification des versions des outils
- ✓ Nettoyage approfondi (modèles, cache, jobs)

---

### 4. `verification-securite.sh`
**Vérification de sécurité complète**

```bash
# Exécution normale
./scripts/verification-securite.sh

# Scan rapide uniquement
SECURITE_RAPIDE=1 ./scripts/verification-securite.sh

# Uniquement l'image Docker
SECURITE_DOCKER_ONLY=1 ./scripts/verification-securite.sh
```

**Ce qu'il fait :**
- ✓ Recherche de secrets dans le dépôt
- ✓ Vérification des dépendances figées (`==`)
- ✓ Vérification de la configuration Docker (non-root, optimisations)
- ✓ Vérification des workflows GitHub Actions (épinglage SHA)
- ✓ Scan Trivy des fichiers du dépôt
- ✓ Scan Trivy de l'image Docker
- ✓ Vérification des bonnes pratiques (en-têtes SPDX, copyright)

**Sortie :**
- Code 0 : Aucune vulnérabilité critique ou haute
- Code 1 : Vulnérabilités critiques ou hautes détectées

---

### 5. `tests-complets.sh`
**Exécution complète de tous les tests**

```bash
# Exécution normale
./scripts/tests-complets.sh

# Sauter les tests unitaires
TESTS_UNITAIRES=0 ./scripts/tests-complets.sh

# Sauter les tests Docker
TESTS_DOCKER=0 ./scripts/tests-complets.sh
```

**Ce qu'il fait :**
- ✓ Vérification du code avec ruff
- ✓ Tests unitaires avec pytest
- ✓ Tests d'intégration Docker
- ✓ Tests de construction multi-platforme
- ✓ Vérification des fichiers de configuration

---

## Exécution manuelle recommandée

### Avant chaque commit
```bash
# Vérification rapide
./scripts/tests-complets.sh
```

### Avant un déploiement
```bash
# Vérification complète
./scripts/maintenance-mensuelle.sh
```

### Après une mise à jour des dépendances
```bash
# Vérification de sécurité
./scripts/verification-securite.sh
```

---

## Variables d'environnement utiles

| Variable | Effet | Scripts concernés |
|----------|-------|-------------------|
| `HEBDO_RAPID` | Saute les tests lourds | `maintenance-hebdomadaire.sh` |
| `MENSUEL_FORCE` | Ignore les erreurs non critiques | `maintenance-mensuelle.sh` |
| `SECURITE_RAPIDE` | Scan rapide uniquement | `verification-securite.sh` |
| `SECURITE_DOCKER_ONLY` | Uniquement l'image Docker | `verification-securite.sh` |
| `TESTS_UNITAIRES` | Désactive les tests unitaires | `tests-complets.sh` |
| `TESTS_DOCKER` | Désactive les tests Docker | `tests-complets.sh` |

---

## Configuration requise

### Prérequis
- **git** : Pour la mise à jour du dépôt
- **python3** (>= 3.10) : Pour l'exécution des tests
- **ffmpeg** : Pour la manipulation vidéo/audio
- **docker** : Pour les tests Docker et Trivy (optionnel)

### Installation des dépendances
```bash
# Créer l'environnement virtuel
python3 -m venv .venv

# Installer les dépendances
.venv/bin/pip install -r requirements.txt -r requirements-dev.txt
```

---

## Intégration CI/CD locale

Ces scripts peuvent être intégrés à votre propre CI/CD locale :

```yaml
# Exemple pour GitHub Actions local
- name: Maintenance hebdomadaire
  run: ./scripts/maintenance-hebdomadaire.sh

- name: Vérification de sécurité
  run: ./scripts/verification-securite.sh
```

---

## Bonnes pratiques

1. **Exécutez régulièrement** la maintenance hebdomadaire
2. **Avant chaque déploiement**, exécutez la vérification de sécurité
3. **Surveillez les logs** dans `/tmp/vpap-*.log`
4. **Corrigez immédiatement** les vulnérabilités CRITICAL et HIGH
5. **Maintenez les dépendances** à jour via Dependabot

---

## Dépannage

### Problème : Docker non disponible
```bash
# Installer Docker selon votre système
# macOS: brew install docker
# Ubuntu: sudo apt install docker.io docker-compose
# Windows: Installer Docker Desktop
```

### Problème : Permission denied
```bash
# Rendre les scripts exécutables
chmod +x scripts/*.sh
```

### Problème : Trivy non disponible
```bash
# Les scripts téléchargent automatiquement Trivy via Docker
# Assurez-vous que Docker est en cours d'exécution
```

### Problème : Tests échouent
```bash
# Voir les logs détaillés
cat /tmp/vpap-*.log
```

---

## Licence

Tous les scripts sont sous licence **AGPL-3.0-or-later**, comme le reste du projet.

Copyright (c) 2026 Johan TIDAS
Code réalisé avec l'assistance de Mistral Vibe (IA de Mistral AI)
