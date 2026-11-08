# Journal des versions

Les versions de maintenance mensuelles (1.0.1, 1.0.2…) sont décrites dans les *Releases* GitHub.

## Non publié

- Le **PDF unique** devient le format de résultat par défaut (consigne, captures et texte dans
  l'ordre chronologique, puis transcription complète) ; le **ZIP** reste disponible en option
  avancée. Certaines IA (ex. Copilot) n'acceptaient pas le ZIP en pièce jointe.

## 1.0.0 — 2026-11-08

Première version publique.

- Page web : dépôt d'une vidéo ou d'un fichier audio, barres de progression (envoi et traitement), téléchargement du résultat.
- Transcription horodatée avec faster-whisper (TXT, SRT, JSON), 5 niveaux de précision.
- Captures aux changements de plan et à intervalle régulier ; pochettes d'album ignorées pour les fichiers audio.
- ZIP de préparation avec `preparation.md` (ordre chronologique), `LISEZMOI.md` et `CONSIGNE_IA.md`.
- Fonctionne sur Windows, macOS, Linux (scripts ou Docker) et Scaleway Serverless Containers.
- Interface adaptée au téléphone, mode sombre, application installable (PWA) et partage de vidéos depuis Android.
- Mot de passe d'accès facultatif (`APP_PASSWORD`), point de santé `/healthz`.
- Licence AGPL-3.0-or-later, licence commerciale possible ; lien « Code source » dans la page.
- Contrôle Trivy bloquant avant publication des images et script local « vérifier puis lancer ».
- Version de maintenance mensuelle automatique et fusion automatique des mises à jour Dependabot testées.
- CI multi-plateforme, analyse Trivy hebdomadaire, Dependabot, publication des images sur ghcr.io.
