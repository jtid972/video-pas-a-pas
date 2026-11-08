# Utilisation sur téléphone et tablette

La page s'adapte aux petits écrans, suit le **mode sombre** du téléphone, et peut être **installée
comme une application** (PWA : icône sur l'écran d'accueil, ouverture en plein écran).

## Condition : une adresse sécurisée (https)

Les navigateurs n'autorisent l'installation que sur une adresse **https://** (ou `http://localhost`
sur la machine elle-même). Concrètement :

- **Scaleway Serverless Containers** : l'adresse fournie est en https → tout fonctionne.
- **Sur un PC du réseau local** (`http://192.168.x.x:8080`) : la page marche dans le navigateur du
  téléphone, mais l'installation n'est pas proposée. Pour l'avoir, placer l'outil derrière un
  serveur https (par exemple Caddy, ou Tailscale qui fournit un certificat), ou utiliser Scaleway.

## Installer l'application

- **Android (Chrome, Edge, Samsung Internet)** : bouton **Installer** en haut de la page, ou menu ⋮ →
  *Installer l'application*.
- **iPhone / iPad, avec Safari** : touchez **⋯** à côté de l'adresse (ou le bouton **Partager**) →
  **Partager** → **Sur l'écran d'accueil**. Depuis iOS 26, l'application s'ouvre ensuite en plein écran.
- **iPhone / iPad, avec Chrome** : bouton **Partager** dans la barre d'adresse → **Sur l'écran d'accueil**.
  Sur iPhone et iPad, Chrome utilise le moteur de Safari (règle d'Apple) : mêmes possibilités, mêmes limites.

  La page affiche automatiquement la bonne marche à suivre selon l'appareil et le navigateur.
- **Ordinateur (Chrome, Edge)** : icône d'installation dans la barre d'adresse.

## Envoyer un fichier depuis une autre application (Android)

Une fois l'application installée, elle apparaît dans le menu **Partager** d'Android : depuis la
galerie, le gestionnaire de fichiers ou une messagerie, choisir *Partager* → **Vidéo pas à pas**.
Le fichier arrive dans l'outil : il reste à choisir la langue et la précision, puis à lancer.

Sur iPhone et iPad, aucun navigateur ne permet encore aux applications web de recevoir des partages
(limitation d'Apple, y compris avec Chrome) : utiliser le bouton « Choisir un fichier », qui donne
accès à Photos et à Fichiers.

## Bon à savoir

- Les traitements se font **sur le serveur**, pas sur le téléphone : l'application a besoin du réseau.
  Hors ligne, la page s'ouvre mais ne peut rien traiter.
- Si un mot de passe est configuré (`APP_PASSWORD`), le navigateur le demande à la première ouverture.
