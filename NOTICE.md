# Mentions — Vidéo pas à pas

## Droit d'auteur

Copyright (c) 2026 Johan TIDAS.

L'auteur conserve l'intégralité de ses droits d'auteur sur le projet (code, documentation,
visuels). La licence accorde des droits d'utilisation ; elle ne transfère aucun droit.

## Licence

L'ensemble du projet (code, documentation, visuels) est distribué sous la
**GNU Affero General Public License, version 3 ou ultérieure** (AGPL-3.0-or-later). Le texte
officiel complet est dans [`LICENSE`](LICENSE).

```
Vidéo pas à pas
Copyright (c) 2026 Johan TIDAS

This program is free software: you can redistribute it and/or modify it under the terms of
the GNU Affero General Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU Affero General Public License for more details.
```

### En résumé (non contractuel ; seul le texte de `LICENSE` fait foi)

- **Vous pouvez** utiliser, étudier, modifier et redistribuer le logiciel, y compris dans un
  cadre professionnel.
- **À condition de** fournir le code source complet, sous AGPL-3.0, de toute version que vous
  distribuez **ou que vous faites utiliser à distance** (réseau, service en ligne) ; de conserver
  les mentions de droit d'auteur et d'attribution ci-dessous ; et d'indiquer vos modifications.
- **Aucune garantie** : le logiciel est fourni « tel quel ».

## Conditions supplémentaires (article 7 de l'AGPL-3.0)

Conformément à l'article 7, paragraphes b) et e), de la licence :

1. **Attributions à conserver.** Toute copie ou version modifiée doit conserver, dans sa
   documentation et dans le pied de page de son interface web, les mentions suivantes :
   - « Vidéo pas à pas — Copyright (c) 2026 Johan TIDAS » ;
   - « Code réalisé avec l'assistance de Claude, l'IA d'Anthropic ».
2. **Nom.** La licence n'accorde aucun droit d'utiliser le nom « Vidéo pas à pas » pour
   désigner une version modifiée ou un service dérivé, sauf pour indiquer honnêtement l'origine
   du logiciel (« basé sur Vidéo pas à pas »).

## Licence commerciale

L'auteur, seul titulaire des droits, peut accorder une **licence commerciale séparée** à ceux
qui souhaitent utiliser ou intégrer Vidéo pas à pas **sans les obligations de l'AGPL**
(par exemple, garder leurs modifications fermées, ou l'intégrer dans un produit propriétaire).
**Contact** : ouvrir un ticket **« Demande de licence commerciale »** sur le dépôt GitHub
(onglet *Issues* → *New issue*). Les tickets sont publics : n'y indiquez rien de confidentiel.
L'auteur vous répondra pour poursuivre l'échange en privé.

## Assistance par intelligence artificielle

Le code et la documentation de ce projet ont été réalisés **avec l'assistance de Claude,
l'IA d'Anthropic**, pour la génération de code. La conception, les choix fonctionnels, la
relecture, les tests et la maintenance sont assurés par l'auteur.

## Composants tiers

Vidéo pas à pas **utilise** les logiciels suivants, chacun sous sa propre licence, toutes
compatibles avec l'AGPL-3.0.

| Composant | Rôle | Licence |
|---|---|---|
| [FFmpeg](https://ffmpeg.org/) | lecture audio/vidéo, captures | LGPL 2.1+ / GPL 2+ selon la compilation ; appelé comme programme séparé |
| [faster-whisper](https://github.com/SYSTRAN/faster-whisper) | transcription | MIT |
| [CTranslate2](https://github.com/OpenNMT/CTranslate2) | moteur d'inférence | MIT |
| Modèles [Whisper](https://github.com/openai/whisper) (OpenAI), convertis par Systran | reconnaissance vocale | MIT |
| Silero VAD (inclus dans faster-whisper) | détection de la parole | MIT |
| [PyAV](https://github.com/PyAV-Org/PyAV) | décodage audio | BSD-3-Clause |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime) | exécution du VAD | MIT |
| [FastAPI](https://github.com/fastapi/fastapi) | serveur web | MIT |
| [Uvicorn](https://github.com/encode/uvicorn) | serveur HTTP | BSD-3-Clause |
| [python-multipart](https://github.com/Kludex/python-multipart) | réception des fichiers | Apache-2.0 |

**Images Docker** : elles contiennent Debian (ou Ubuntu pour la variante GPU), Python et le
paquet `ffmpeg` de la distribution, sous licence GPL. Leur code source correspondant est
disponible auprès de la distribution : <https://sources.debian.org/src/ffmpeg/> (Debian) et
<https://launchpad.net/ubuntu/+source/ffmpeg> (Ubuntu).
