# Feuille de route

## v1.1 — Récupérer une vidéo YouTube (prévu)

Objectif : coller l'adresse d'une vidéo au lieu d'envoyer un fichier.

Piste technique :
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) (licence Unlicense, compatible) : un champ
  « Adresse de la vidéo » dans la page, et une étape « Téléchargement » avec sa propre barre de progression.
- **Raccourci intéressant** : beaucoup de vidéos ont déjà des sous-titres (manuels ou
  automatiques). Les récupérer directement évite la transcription Whisper : c'est beaucoup
  plus rapide. Whisper resterait le plan B quand il n'y a pas de sous-titres.
- yt-dlp change souvent pour suivre YouTube : il faudra l'ajouter à `requirements.txt`.
  Dependabot proposera alors ses nouvelles versions chaque semaine.

Points d'attention :
- **Conditions d'utilisation** : celles de YouTube n'autorisent le téléchargement que si
  YouTube le propose ou avec l'accord du titulaire des droits. À réserver à vos propres vidéos,
  aux vidéos sous licence libre (Creative Commons) ou à celles pour lesquelles vous avez une autorisation.
  Le rappeler dans l'interface.
- **Serveurs cloud** : YouTube bloque souvent les adresses IP des hébergeurs (dont Scaleway),
  avec des demandes de connexion ou des captchas. La fonction marchera bien mieux sur un poste de travail.

## Pistes ultérieures

- Stockage des ZIP dans un bucket Scaleway Object Storage (S3), pour ne plus les perdre à la
  mise en veille de Serverless Containers, et suivi des travaux partagé entre instances.
- Traitement des longues vidéos via Scaleway **Serverless Jobs** (jusqu'à 24 h d'exécution).
- Choix de l'intervalle et de la sensibilité des captures directement dans la page.
- Suppression automatique des captures en double (écrans presque identiques).
- Diarisation (« qui parle ? ») pour les réunions, utile aux notes de synthèse.
