# Le ZIP de préparation

Le résultat s'appelle `<nom du fichier>_preparation_IA.zip`. **C'est un dossier de préparation,
pas un document fini** : il sert d'entrée à une IA qui traite du texte et/ou des images pour
rédiger un tutoriel, un guide ou une note de synthèse.

```
LISEZMOI.md            à quoi sert le ZIP, comment l'utiliser, résumé
CONSIGNE_IA.md         consigne prête à copier-coller dans l'IA (à compléter : type de document, public)
preparation.md         FICHIER PRINCIPAL : texte + captures dans l'ordre chronologique
transcription.txt      [mm:ss] texte, une ligne par passage
transcription.srt      sous-titres
transcription.json     données structurées : durée, langue, modèle, passages, captures
images/                img_001_000m01s.jpg, img_002_000m08s.jpg…  (le nom contient le moment)
```

## Extrait de `preparation.md`

```markdown
# Préparation : installation-imprimante.mp4

> Dossier de préparation produit par Vidéo pas à pas v1.0.0, destiné à servir d'entrée à une IA…

- Source : vidéo
- Durée : 06:42
- Langue détectée : fr
- Modèle de transcription : small
- 87 passages transcrits, 24 captures

---

![Capture 00:01](images/img_001_000m01s.jpg)

**[00:03]** Bonjour, aujourd'hui on va installer l'imprimante sur Windows.

**[00:09]** On commence par ouvrir les paramètres.

![Capture 00:12](images/img_002_000m12s.jpg)
```

## Selon l'IA utilisée

| IA | Quoi lui donner |
|---|---|
| Lit le texte **et** les images (Claude, par exemple) | le ZIP entier, ou `preparation.md` + le dossier `images/` |
| Lit seulement le texte | `transcription.txt` (ou `preparation.md`, les liens d'images seront ignorés) |

## Cas particuliers

- **Fichier audio seul** : pas de dossier `images/` rempli ; `LISEZMOI.md` le signale.
- **Vidéo sans son** : seules les captures sont produites.
- **Option « Transcrire » décochée** : seules les captures sont produites.
