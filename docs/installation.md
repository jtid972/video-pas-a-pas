# Installation

Deux façons de faire, sur toutes les plateformes :

- **Sans Docker** : Python + ffmpeg, et un script qui s'occupe du reste. Le plus simple sur un poste de travail.
- **Avec Docker** : rien à installer à part Docker. Pratique pour un serveur ou un PC partagé.

Au **premier lancement** d'un modèle de transcription, la machine doit avoir accès à Internet
(huggingface.co) pour le télécharger. Il est ensuite gardé en cache.

---

## Windows

### Sans Docker

1. Ouvrir un terminal (PowerShell) et installer les prérequis :
   ```powershell
   winget install Python.Python.3.13
   winget install Gyan.FFmpeg
   ```
2. **Fermer puis rouvrir** le terminal (pour que `ffmpeg` soit reconnu).
3. Double-cliquer sur `scripts\lancer.bat`. Le premier lancement installe les dépendances
   (quelques minutes), puis le navigateur s'ouvre sur http://localhost:8080.

### Avec Docker

1. Installer [Docker Desktop](https://www.docker.com/products/docker-desktop/) (il active WSL 2).
2. Dans le dossier du projet : `docker compose up -d --build`
3. Ouvrir http://localhost:8080.

Carte graphique NVIDIA : avec un pilote récent, Docker Desktop gère le GPU via WSL 2 →
voir [Carte graphique NVIDIA](#carte-graphique-nvidia).

## macOS

Fonctionne sur Mac Intel et Apple Silicon (M1 à M4…). La transcription utilise le processeur
(le moteur CTranslate2 n'utilise pas le GPU du Mac), ce qui reste rapide sur Apple Silicon.

### Sans Docker

```bash
brew install python ffmpeg          # Homebrew : https://brew.sh
./scripts/lancer.sh
```

### Avec Docker

Installer Docker Desktop pour Mac, puis `docker compose up -d --build`.
L'image publiée `ghcr.io/<compte>/video-pas-a-pas:latest` existe en version arm64 (Apple Silicon).

## Linux

### Sans Docker

```bash
sudo apt install python3 python3-venv ffmpeg      # Debian / Ubuntu
# sudo dnf install python3 ffmpeg                 # Fedora (dépôt RPM Fusion pour ffmpeg)
./scripts/lancer.sh
```

### Avec Docker

```bash
docker compose up -d --build        # arrêt : docker compose down
```

Les modèles téléchargés sont conservés dans le volume Docker `vpap-data`.

---

## Accès depuis un autre poste du réseau

Par défaut, l'outil n'écoute que sur la machine elle-même (`127.0.0.1`).

- Sans Docker : `HOST=0.0.0.0 ./scripts/lancer.sh` (Windows : `$env:HOST="0.0.0.0"` avant `lancer.ps1`).
- Docker : dans `docker-compose.yml`, remplacer `"127.0.0.1:8080:8000"` par `"8080:8000"`.

**Activez alors un mot de passe** avec la variable `APP_PASSWORD` : le navigateur le
demandera (le nom d'utilisateur est libre).

## Carte graphique NVIDIA

Beaucoup plus rapide, et permet le modèle `large-v3`. Il faut le pilote NVIDIA et, sous Linux,
le *NVIDIA Container Toolkit*.

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d --build
```

Sans Docker, la carte est utilisée automatiquement si CUDA 12 et cuDNN 9 sont installés
(`WHISPER_DEVICE=auto`).

## Quel modèle choisir ?

| Modèle | Téléchargement | Sans carte graphique, pour 10 min d'audio* | Qualité |
|---|---|---|---|
| tiny | ~75 Mo | ~1 min | approximative |
| base | ~150 Mo | ~2 min | correcte |
| **small** (défaut) | ~500 Mo | ~4 à 6 min | bonne, conseillée |
| medium | ~1,5 Go | ~12 à 20 min | très bonne |
| large-v3 | ~3 Go | très long → carte graphique conseillée | la meilleure |

\* Ordres de grandeur sur un processeur récent de 4 à 8 cœurs. Prévoir au moins 4 Go de RAM
pour `small`, 8 Go pour `medium`.

## Réglages

Variables d'environnement (dans `docker-compose.yml`, ou avant de lancer le script) :

| Variable | Défaut | Rôle |
|---|---|---|
| `WHISPER_MODEL` | `small` | modèle proposé par défaut |
| `WHISPER_DEVICE` | `auto` (`cpu` dans l'image Docker) | `cpu`, `cuda` ou `auto` |
| `WHISPER_COMPUTE` | `auto` (`int8` dans l'image Docker) | précision de calcul (`int8`, `float16`…) |
| `SCENE_THRESHOLD` | `0.3` | sensibilité aux changements de plan (0.2 = plus de captures) |
| `FRAME_INTERVAL` | `30` | au moins une capture toutes les N secondes |
| `FRAME_MIN_GAP` | `4` | écart minimal entre deux captures (secondes) |
| `MAX_FRAMES` | `300` | nombre maximal de captures |
| `MAX_UPLOAD_MB` | `4096` | taille maximale d'un fichier envoyé |
| `ENABLE_YOUTUBE` | `1` | `0` désactive la récupération par adresse YouTube (champ masqué dans la page) ; utile sur un déploiement cloud public, où YouTube bloque souvent ces adresses |
| `KEEP_HOURS` | `48` | les PDF/ZIP sont supprimés après ce délai |
| `APP_PASSWORD` | *(vide)* | mot de passe d'accès ; vide = pas de mot de passe |
| `SOURCE_URL` | adresse du dépôt | lien « Code source » du pied de page (obligation de l'AGPL) ; à faire pointer vers votre version si vous la modifiez |
| `DATA_DIR` / `MODELS_DIR` | `./data` / `./data/models` | dossiers de travail et des modèles |
| `HOST` / `PORT` | `127.0.0.1` / `8080` (scripts) | adresse et port d'écoute |

Le fichier envoyé est supprimé dès la fin du traitement ; seul le ZIP est conservé jusqu'à `KEEP_HOURS`.
