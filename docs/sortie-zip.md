# Le résultat : PDF (par défaut) ou ZIP

Dans les deux cas, **c'est un dossier de préparation, pas un document fini** : il sert d'entrée
à une IA qui traite du texte et/ou des images pour rédiger un tutoriel, un guide ou une note de
synthèse. Le format se choisit avant de lancer le traitement.

## La consigne pour l'IA

La consigne incluse dans les deux formats a été améliorée pour être plus claire et actionnable.
Elle contient des **placeholders à compléter** avant utilisation :

```
=== REMPLACER PAR : un tutoriel pas à pas | un guide technique | une note de synthèse ===
DESTINE A :
=== REMPLACER PAR : débutants | utilisateurs avancés | experts | [autre public] ===
```

Ces placeholders sont présents dans :
- **PDF** : page de garde, section "Consigne pour l'IA"
- **ZIP** : fichier `CONSIGNE_IA.md`

## Le PDF unique (par défaut)

Le résultat s'appelle `<nom du fichier>_preparation_IA.pdf`. Un seul fichier, à donner en une
fois à l'IA — y compris celles qui n'acceptent pas les ZIP en pièce jointe (ex. Copilot) :

1. **Page de garde** : résumé (durée, langue, nombre de passages/captures) et la **consigne
   pour l'IA** (texte détaillé avec placeholders à compléter, identique à `CONSIGNE_IA.md` du ZIP).
2. **Contenu, dans l'ordre chronologique** : les captures (réencodées en JPEG, largeur max
   1280 px, pour rester léger) et les passages transcrits, intercalés selon leur moment dans
   la vidéo.
3. **Transcription complète** : tous les passages avec leur horodatage, en fin de document —
   pour que l'IA dispose aussi du texte brut, sans avoir à le reconstituer à partir des
   extraits intercalés. La consigne rappelle explicitement d'utiliser cette section pour vérifier les détails.

## Le ZIP de préparation (option avancée)

```
LISEZMOI.md            à quoi sert le ZIP, comment l'utiliser, résumé
CONSIGNE_IA.md         consigne prête à copier-coller dans l'IA (avec placeholders à compléter : type de document, public)
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
| N'accepte pas les fichiers ZIP en pièce jointe (ex. Copilot) | le **PDF** |
| Lit le texte **et** les images (Claude, par exemple) | le PDF, ou le ZIP entier (ou `preparation.md` + le dossier `images/`) |
| Lit seulement le texte | `transcription.txt` du ZIP (ou `preparation.md`, les liens d'images seront ignorés) |

## Cas particuliers

- **Fichier audio seul** : pas de dossier `images/` rempli ; `LISEZMOI.md` le signale.
- **Vidéo sans son** : seules les captures sont produites.
- **Option « Transcrire » décochée** : seules les captures sont produites.
