# Vidéo pas à pas

**Transforme une vidéo ou un enregistrement audio en dossier de préparation pour une IA.**

Vidéo pas à pas est un petit outil web à installer sur sa machine (ou sur un serveur). On y
dépose une vidéo (ou un simple fichier audio) et on récupère un **ZIP de préparation**
contenant :

- la **transcription** de ce qui est dit, horodatée (texte, sous-titres SRT, JSON) ;
- des **captures d'écran** prises à chaque changement de plan et à intervalle régulier ;
- un fichier `preparation.md` qui mélange texte et captures **dans l'ordre chronologique** ;
- un `LISEZMOI.md` qui explique le contenu et une **consigne prête à coller** dans l'IA.

Ce ZIP sert d'entrée à une IA capable de traiter **des images et/ou du texte** (par exemple
Claude) pour produire un **tutoriel**, un **guide pas à pas** ou une **note de synthèse**.

> Fichier audio seul (MP3, M4A, WAV, OGG…) : seule la transcription est produite, sans
> captures. Une pochette d'album intégrée au fichier est ignorée.

L'outil s'utilise **sur ordinateur et sur téléphone** : on peut l'**installer comme une application**
et lui **partager une vidéo** depuis la galerie (voir [docs/mobile.md](docs/mobile.md)).

Tout est traité **localement** : la vidéo n'est envoyée à aucun service extérieur. Seul le
modèle de reconnaissance vocale est téléchargé une fois, au premier usage.

---

## Installation rapide

| Plateforme | Méthode conseillée | Détails |
|---|---|---|
| **Windows 10/11** | double-clic sur `scripts\lancer.bat`, ou Docker Desktop | [docs/installation.md](docs/installation.md#windows) |
| **macOS** (Intel et Apple Silicon) | `./scripts/lancer.sh`, ou Docker Desktop | [docs/installation.md](docs/installation.md#macos) |
| **Linux** (poste de travail) | `./scripts/lancer.sh`, ou `docker compose up -d` | [docs/installation.md](docs/installation.md#linux) |
| **Scaleway Serverless Containers** | image `ghcr.io/<compte>/video-pas-a-pas:latest-small` | [docs/scaleway.md](docs/scaleway.md) |

Avec Docker, sur n'importe quelle plateforme :

```bash
docker compose up -d --build
```

puis ouvrir **http://localhost:8080**.

Pour **vérifier la sécurité avant chaque lancement** (construction, analyse Trivy, puis
lancement seulement si l'image est saine) : `./scripts/verifier-et-lancer.sh`
(Windows : `.\scripts\verifier-et-lancer.ps1`). Voir [docs/maintenance.md](docs/maintenance.md).

Sans Docker : installer **Python 3.10 à 3.13** et **ffmpeg**, puis lancer le script
correspondant à son système (il crée l'environnement et ouvre le navigateur).

## Utilisation

1. Glisser une vidéo ou un fichier audio dans la page.
2. Choisir la langue et la précision de la transcription (« Équilibré » conseillé sans carte graphique).
3. Suivre les barres de progression (envoi, puis traitement).
4. Télécharger le ZIP et le donner à l'IA, avec la consigne fournie dans `CONSIGNE_IA.md`.

Le contenu du ZIP est détaillé dans [docs/sortie-zip.md](docs/sortie-zip.md).

## Documentation

- [Installation sur Windows, macOS et Linux](docs/installation.md)
- [Déploiement sur Scaleway Serverless Containers](docs/scaleway.md)
- [Contenu du ZIP de préparation](docs/sortie-zip.md)
- [Utilisation sur téléphone : application installable et partage](docs/mobile.md)
- [Réglages](docs/installation.md#réglages)
- [Maintenance : analyse Trivy hebdomadaire, mises à jour, versions](docs/maintenance.md)
- [Feuille de route (dont la récupération de vidéos YouTube)](docs/feuille-de-route.md)
- [Sécurité](SECURITY.md) · [Journal des versions](CHANGELOG.md)

## Licence et droit d'auteur

Copyright (c) 2026 Johan TIDAS. L'auteur conserve l'intégralité de ses droits d'auteur.

Logiciel libre sous licence **[GNU AGPL-3.0](LICENSE)** (version 3 ou ultérieure), pour le code
comme pour la documentation. Vous pouvez l'utiliser, le modifier et le partager, à condition de
publier sous la même licence le code de toute version que vous distribuez **ou que vous
proposez en service en ligne**, et de conserver les mentions d'auteur.

Une **licence commerciale** est disponible auprès de l'auteur pour un usage sans ces
obligations. Détails, conditions supplémentaires et composants tiers : [NOTICE.md](NOTICE.md).
Contributions : [CONTRIBUTING.md](CONTRIBUTING.md).

**Code réalisé avec l'assistance de Claude, l'IA d'Anthropic**, pour la génération de code.
