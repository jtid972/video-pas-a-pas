# Sécurité

## Signaler une faille

Merci de **ne pas** ouvrir de ticket public. Utilisez le signalement privé de GitHub :
onglet *Security* → *Report a vulnerability*. Une réponse est donnée dès que possible.

## Bonnes pratiques d'utilisation

- Par défaut, l'outil n'est accessible que depuis la machine elle-même.
- Dès qu'il est ouvert au réseau ou à Internet (Scaleway), définissez `APP_PASSWORD`.
- Les fichiers envoyés sont supprimés après traitement ; les ZIP après `KEEP_HOURS` (48 h par défaut).
- Le traitement est local : aucun contenu n'est envoyé à un service tiers. Seuls les modèles
  de transcription sont téléchargés depuis huggingface.co au premier usage.

## Suivi des vulnérabilités

Analyse Trivy chaque semaine, alertes et mises à jour Dependabot : voir [docs/maintenance.md](docs/maintenance.md).
