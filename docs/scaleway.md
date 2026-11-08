# Déploiement sur Scaleway Serverless Containers

Vidéo pas à pas peut tourner sur [Scaleway Serverless Containers](https://www.scaleway.com/fr/serverless-containers/) :
l'instance démarre à la première visite et s'éteint quand elle ne sert plus (facturation à l'usage).

## Ce qu'il faut savoir avant

Contraintes de Scaleway (vérifiées en novembre 2026, à recontrôler dans la
[page des limites](https://www.scaleway.com/en/docs/serverless-containers/reference-content/containers-limitations/)) :

- **Architecture amd64 uniquement** : utiliser l'image `latest-small` (amd64), ou construire
  avec `--platform linux/amd64` depuis un Mac Apple Silicon.
- **Mémoire** : jusqu'à environ 12 Go par conteneur. Compter **4 Go** pour le modèle `small`.
- **Durée d'une requête** : de 10 s à 60 min. Mettre le maximum pour permettre l'envoi de gros fichiers.
- **Mise en veille** : l'instance s'arrête après 15 min sans requête. Le **ZIP est alors perdu** :
  il faut le télécharger dès la fin du traitement.
- **Stockage temporaire** : le disque disparaît à l'arrêt de l'instance. Les modèles doivent
  donc être **intégrés à l'image**, ce que fait l'image `latest-small`.

Conséquences pour Vidéo pas à pas :

- **Mettre `max-scale` à 1.** Le suivi des travaux est gardé en mémoire dans l'instance ;
  avec plusieurs instances, la page pourrait interroger une instance qui ne connaît pas le travail.
- **Garder l'onglet ouvert pendant le traitement** : la page interroge le serveur chaque
  seconde, ce qui maintient l'instance active.
- Pour de très longues vidéos (plus d'une heure de traitement), préférer un poste de travail
  (voir la piste « Serverless Jobs » dans la [feuille de route](feuille-de-route.md)).
- **Récupération par adresse YouTube** : à désactiver ici (`ENABLE_YOUTUBE=0`), YouTube bloquant
  souvent les adresses IP des hébergeurs cloud (demandes de connexion, captchas). Elle marche
  bien mieux sur un poste de travail.

## 1. Disposer de l'image

Le workflow GitHub `Image Docker` publie automatiquement
`ghcr.io/<compte>/video-pas-a-pas:latest-small` (amd64, modèle `small` intégré).

Scaleway ne sait lire que les images **publiques** des registres externes. Deux options :

- **Option A, la plus simple** : rendre le paquet public (GitHub → *Packages* →
  `video-pas-a-pas` → *Package settings* → *Change visibility* → *Public*), puis utiliser
  directement `ghcr.io/<compte>/video-pas-a-pas:latest-small`.
- **Option B, recommandée par Scaleway** (pas de limite de débit des registres externes) :
  copier l'image dans votre Scaleway Container Registry :
  ```bash
  docker login rg.fr-par.scw.cloud/<namespace> -u nologin --password-stdin <<< "$SCW_SECRET_KEY"
  docker pull --platform linux/amd64 ghcr.io/<compte>/video-pas-a-pas:latest-small
  docker tag ghcr.io/<compte>/video-pas-a-pas:latest-small rg.fr-par.scw.cloud/<namespace>/video-pas-a-pas:latest-small
  docker push rg.fr-par.scw.cloud/<namespace>/video-pas-a-pas:latest-small
  ```

Construire soi-même (depuis n'importe quelle machine) :

```bash
docker build --platform linux/amd64 --build-arg PRELOAD_MODEL=small \
  -t rg.fr-par.scw.cloud/<namespace>/video-pas-a-pas:latest-small .
```

## 2. Créer le conteneur (console Scaleway)

*Serverless* → *Containers* → créer un namespace (région `fr-par`, par exemple) → *Deploy container* :

| Paramètre | Valeur |
|---|---|
| Image | celle de l'étape 1 |
| Port | `8000` (l'application lit aussi la variable `PORT` fournie par Scaleway) |
| Mémoire | **4096 Mo** pour `small` (le vCPU associé est fixé par Scaleway) |
| Min scale / Max scale | **0 / 1** |
| Timeout | le maximum (3600 s) |
| Stockage éphémère | au moins 2 à 3 fois la taille des vidéos traitées |
| Variable d'environnement | `WHISPER_MODEL=small` |
| Variable d'environnement | `SOURCE_URL=https://github.com/<compte>/video-pas-a-pas` (lien « Code source » exigé par l'AGPL) |
| Variable d'environnement | `ENABLE_YOUTUBE=0` (YouTube bloque souvent les adresses IP de Scaleway ; voir plus bas) |
| **Secret** | `APP_PASSWORD` = un mot de passe solide |
| Health check (HTTP) | chemin `/healthz` |

L'adresse publique du conteneur est accessible à tout Internet : **le mot de passe est indispensable**.

## 3. Mise à jour

À chaque nouvelle image (version publiée, ou reconstruction hebdomadaire avec les correctifs
de sécurité), relancer *Deploy* sur le conteneur pour qu'il récupère la dernière image.
