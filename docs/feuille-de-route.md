# Feuille de route

## Récupérer une vidéo YouTube — fait (08/11/2026)

Un champ « Adresse YouTube » (onglet à côté de « Fichier »), désactivable avec
`ENABLE_YOUTUBE=0`. Implémenté avec [yt-dlp](https://github.com/yt-dlp/yt-dlp) (licence
Unlicense, compatible), restreint à l'extracteur YouTube (`allowed_extractors`) pour qu'une
adresse détournée ne puisse pas faire interroger un autre site.

- **Raccourci sous-titres** : quand la vidéo a des sous-titres (manuels ou automatiques), ils
  sont récupérés directement (`vtt_to_segs`) et servent de transcription — Whisper n'est pas
  appelé, c'est beaucoup plus rapide. Whisper reste le plan B sinon.
- yt-dlp change souvent pour suivre YouTube : sa version est dans `requirements.txt`,
  Dependabot proposera ses mises à jour chaque semaine.
- **Conditions d'utilisation** : rappelées dans l'interface, à côté du champ — réservé à ses
  propres vidéos, aux vidéos sous licence libre (Creative Commons) ou à celles pour lesquelles
  on a une autorisation.
- **Serveurs cloud** : YouTube bloque souvent les adresses IP des hébergeurs (dont Scaleway),
  avec des demandes de connexion ou des captchas — désactiver la fonction (`ENABLE_YOUTUBE=0`)
  sur ce type de déploiement (voir [docs/scaleway.md](scaleway.md)) ; elle marche bien mieux sur
  un poste de travail.

## Pistes ultérieures

- Stockage des ZIP dans un bucket Scaleway Object Storage (S3), pour ne plus les perdre à la
  mise en veille de Serverless Containers, et suivi des travaux partagé entre instances.
- Traitement des longues vidéos via Scaleway **Serverless Jobs** (jusqu'à 24 h d'exécution).
- Choix de l'intervalle et de la sensibilité des captures directement dans la page.
- Suppression automatique des captures en double (écrans presque identiques).
- Diarisation (« qui parle ? ») pour les réunions, utile aux notes de synthèse.
