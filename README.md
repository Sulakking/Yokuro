# Yokuro

Le dossier Téléchargements qui se range tout seul. Une app Mac de barre de menus, native, écrite en Swift.

## La problématique

En tant que designers, on télécharge toute la journée : exports, captures d'écran, maquettes HTML en v1, v2, v3, zips de polices, PDF clients, rushes vidéo, fichiers JSON. En quelques jours, le dossier Téléchargements devient un fourre-tout de centaines de fichiers.

- On perd du temps à chercher le bon fichier, et on ne sait plus à quel projet il appartient.
- On ne sait plus quelle version d'une maquette est la bonne.
- Les doublons « (1) », « (2) », les zips déjà dézippés et les installeurs s'accumulent et remplissent le disque.
- Ranger à la main, personne ne le fait : l'effort est immédiat, le gain arrive plus tard.

## La réponse

Yokuro vit dans la barre de menus. Il range au fil de l'eau, fait le ménage chaque soir, et ne supprime jamais rien sans validation.

## Les fonctionnalités

### Chaque fichier rattaché à son projet

- Dès qu'un fichier arrive, une pop-in demande sa catégorie projet, et le fichier est renommé avec un préfixe : « BNP PF - brief.pdf ».
- Une nouvelle catégorie se crée en une saisie, et la liste se filtre en tapant.
- Le nom du fichier se corrige directement dans la pop-in.
- « Renommer avec la même catégorie » préfixe automatiquement toute une série de téléchargements.
- Avec des mots-clés par projet, les fichiers se classent seuls.
- « Renommer les derniers fichiers » rattrape d'un clic la dernière demi-heure.

### Le ménage du soir

- Chaque jour à 17 h, Yokuro propose le rangement du jour, ou le reporte d'une heure, de trois ou au lendemain.
- Chaque type de fichier rejoint son dossier : Images, Captures d’écran, Documents de travail, Vidéos en cours, Audios en cours, SVG Images, PSD Photoshop, AEP After Effect, Fichiers JSON par projet, Fichiers ZIP.
- Le superflu disparaît : anciennes versions des HTML et des JSON, doublons, copies, zips déjà dézippés, dossiers de polices, installeurs.
- Les images au nom illisible, comme « IMG_4521 », deviennent « Image 1126 - 01 ».
- « Trier autre dossier » applique le même rangement à n'importe quel dossier.

### Aucun risque de perdre un fichier

- Avant chaque rangement, la liste complète des changements s'affiche : chaque ligne se décoche, chaque nom se modifie.
- Un fichier supprimé reste 7 jours dans « Fichiers temporaires » avant de partir à la corbeille.
- Chaque passage écrit un rapport daté.

### Discret par conception

- La pop-in ne prend jamais le clavier.
- Un bouton Pause la fait taire jusqu'à la reprise, et elle peut respecter le mode Concentration de macOS.
- Les dossiers créés par Yokuro prennent une couleur au choix.
- Chaque règle s'active ou se désactive dans les réglages.

## Installer

macOS 13 ou plus récent, avec les outils d'Apple (`xcode-select --install`). Puis, dans le Terminal, depuis ce dossier :

```bash
bash build.sh
```

Le pas-à-pas complet, les règles de tri et la FAQ sont dans [LISEZMOI.md](LISEZMOI.md).

## Sous le capot

App native en Swift, sans dépendance. Tout se passe sur le Mac : aucune connexion, aucune donnée envoyée.

- `Sources/Yokuro/` : le code de l'app.
- `Resources/` : l'icône et le picto de la barre de menus.
- `Outils/verifications/` : contrôles du code sans Mac (types de l'interface et plus de 200 vérifications du moteur de tri), avec la toolchain Swift pour Linux.

## Contact

Conçu par Valentin Stobierski. Une idée, un bug, une règle qui manque : ouvrez une issue.
# Yokuro
