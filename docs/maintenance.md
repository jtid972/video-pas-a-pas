# Maintenance du dépôt

Tout est automatisé avec GitHub Actions (gratuit sur un dépôt public). Il n'y a rien à
installer : les analyses tournent sur les serveurs de GitHub.

## Ce qui tourne automatiquement

| Quand | Workflow | Ce qu'il fait |
|---|---|---|
| Chaque modification / demande de fusion | `CI` | tests sous Linux (dont une **vraie transcription** d'une voix de synthèse avec le modèle `tiny`), macOS et Windows ; construction et démarrage de l'image Docker |
| **Chaque lundi** 06:17 UTC (+ si dépendances ou Dockerfile changent) | `Trivy (hebdomadaire)` | analyse de sécurité **Trivy** des dépendances Python, du Dockerfile, des secrets oubliés et de l'image complète |
| Chaque lundi 03:41 UTC, à chaque modification et à chaque version | `Image Docker` | reconstruit et publie les images sur `ghcr.io` (avec les derniers correctifs Debian) |
| **Le 1er de chaque mois** 04:23 UTC | `Version mensuelle` | reconstruit l'image sans cache, **contrôle Trivy bloquant**, puis publie automatiquement une **version corrigée** (1.0.1, 1.0.2…) avec sa Release et ses images |
| Après chaque CI réussie sur une demande Dependabot | `Dependabot — fusion automatique` | fusionne seule les mises à jour mineures et correctives, **uniquement après la réussite de tous les tests** ; les mises à jour majeures attendent votre validation |
| Chaque lundi | **Dependabot** | propose des demandes de fusion pour les nouvelles versions des dépendances Python, de l'image de base Python et des actions GitHub |

### Trivy

- Les résultats détaillés arrivent dans l'onglet **Security → Code scanning** du dépôt.
  C'est gratuit pour un dépôt public ; pour un dépôt privé, il faut l'option payante GitHub
  Code Security. Sans elle, le rapport reste lisible dans le résumé de l'exécution.
- Le workflow **échoue** s'il trouve dans l'image une faille **critique ou haute** pour
  laquelle un correctif existe. GitHub vous envoie alors un e-mail.
- Lancer une analyse à la main : onglet *Actions* → *Trivy (hebdomadaire)* → *Run workflow*.
- Sécurité de la chaîne d'outils : en mars 2026, l'action `trivy-action` a été compromise
  (CVE-2026-33634). Ici, les actions sont **épinglées par empreinte SHA** et la version de
  Trivy est figée (`TRIVY_VERSION`). Dependabot met à jour ces empreintes ; vérifiez la page
  des versions de Trivy avant d'accepter une montée de version.

### Accepter une mise à jour Dependabot

1. Ouvrir la demande de fusion proposée par Dependabot.
2. Attendre que la CI soit verte (tests Linux, macOS, Windows et Docker).
3. Fusionner. L'image `latest` est republiée automatiquement.

## Le cycle « vérifier avant usage »

```
Chaque lundi   Dependabot propose les mises à jour
                 → CI : tests Linux / macOS / Windows + Docker
                 → mineure ou corrective et tests verts : fusion automatique
                   (majeure : à valider à la main)

Chaque lundi   Trivy réanalyse l'image publiée → onglet Security (+ e-mail si faille)

Le 1er du mois Version mensuelle :
                 reconstruction sans cache (derniers correctifs Debian / Python / dépendances)
                 → CONTRÔLE TRIVY (bloquant : faille critique/haute corrigeable = arrêt + e-mail)
                 → version +1, Release GitHub, publication des images ghcr.io

Sur un poste   scripts/verifier-et-lancer.sh (.ps1 sous Windows)
                 construction → CONTRÔLE TRIVY (bloquant) → lancement
```

Trivy ne corrige rien lui-même : il **vérifie**. Les corrections viennent des mises à jour
(Dependabot, image de base Debian reconstruite) ; Trivy garantit qu'aucune version n'est
publiée ou lancée avec une faille grave connue et corrigeable.

Sur un poste, utilisez de préférence `./scripts/verifier-et-lancer.sh` (macOS, Linux) ou
`.\scripts\verifier-et-lancer.ps1` (Windows) plutôt que `docker compose up` directement :
l'image est reconstruite avec les dernières mises à jour, analysée, et lancée seulement si elle est saine.

## À activer une fois sur GitHub

- *Settings → Code security* : activer **Dependabot alerts** et **Dependabot security updates**.
- *Settings → Actions → General* : *Workflow permissions* → **Read and write** (nécessaire
  pour publier l'image sur ghcr.io).
- *Settings → Rules → Rulesets* (ou *Branches*) : créer une règle sur `main` qui **exige la
  réussite des tests** (protection supplémentaire : la fusion automatique attend déjà la fin de la CI) : `Linux (avec vraie transcription)`, `macos-latest`, `windows-latest`,
  `Construction de l'image Docker`. Sans cette règle, la fusion automatique n'attendrait pas les tests.
- Après la première publication : rendre public le paquet `video-pas-a-pas` (onglet *Packages*)
  si Scaleway doit le lire directement.

## Publier une nouvelle version

Les **versions correctives** (1.0.1, 1.0.2…) sont publiées automatiquement chaque mois. On
peut aussi en déclencher une à tout moment : onglet *Actions* → *Version mensuelle* → *Run workflow*.

Le numéro de version vient de l'**étiquette Git** et il est intégré à l'image à la construction ;
aucun fichier n'est modifié dans le dépôt, ce qui fonctionne même avec une branche protégée.

Pour une **nouvelle fonction** (ex. YouTube → 1.1.0) :
1. Compléter `CHANGELOG.md`, et mettre `1.1.0` comme valeur par défaut dans `app/__init__.py`
   et `pyproject.toml`.
2. Créer l'étiquette : `git tag v1.1.0 && git push origin v1.1.0`
   (ou *Releases* → *Draft a new release* sur GitHub).
3. Les images `1.1.0`, `1.1` et `latest` (et leurs variantes `-small`) sont publiées après le contrôle Trivy.
   Les versions mensuelles suivantes seront 1.1.1, 1.1.2…

Numérotation : `MAJEUR.MINEUR.CORRECTIF` (1.1.0 = nouvelle fonction, 1.0.1 = correction).
