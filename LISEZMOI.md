# Yokuro

Ton dossier Téléchargements se remplit en une journée de captures d'écran, de zips déjà dézippés, de « maquette-v2 (1).html » et de PDF qu'on ne retrouve plus. Yokuro range tout ça à ta place.

C'est une petite app pour Mac qui vit dans la barre de menus, à côté de l'heure. Elle fait trois choses :

- Elle renomme chaque fichier qui arrive avec le nom de son projet, par exemple « BNP PF - brief.pdf ».
- Tous les jours à 17 h, elle propose de faire le ménage : ranger les fichiers dans des dossiers dédiés et supprimer ce qui ne sert plus.
- Elle ne supprime jamais rien sans ton accord, et tout ce qu'elle supprime reste récupérable pendant 7 jours.

Tout se passe sur ton Mac : Yokuro ne se connecte à rien et n'envoie aucune donnée.

## Installer Yokuro

Compte 5 minutes. Il faut un Mac sous macOS 13 Ventura ou plus récent.

1. Si tu n'as jamais compilé de code sur ton Mac, ouvre le Terminal, lance `xcode-select --install` et accepte l'installation. Ce sont les outils d'Apple qui permettent de construire l'app ; une seule fois suffit.
2. Dézippe le dossier Yokuro, et sors-le de Téléchargements et de OneDrive : le Bureau convient très bien.
3. Dans le Terminal, tape `bash ` avec l'espace, glisse le fichier `build.sh` dans la fenêtre, puis appuie sur Entrée.

L'app se construit en une à deux minutes, s'installe dans Applications et se lance. Son picto apparaît dans la barre de menus.

Au premier lancement, macOS demande l'accès au dossier Téléchargements : accepte, sinon Yokuro ne peut rien ranger. Yokuro se relance ensuite tout seul à chaque démarrage du Mac.

Une fois l'app installée, le dossier dézippé ne sert plus : tu peux le supprimer.

## Au quotidien

### Quand un fichier arrive

La pop-in « Quelle catégorie projet ? » s'ouvre sous le picto. Elle ne prend pas le clavier : tu peux continuer à taper dans une autre app.

- Clique une catégorie dans la liste : le fichier reçoit son préfixe, par exemple « LGF - maquette.html ».
- Pas encore de catégorie ? Tape son nom dans « Nouveau Projet » et clique « Ajouter ». Ce champ filtre aussi la liste, pratique quand tu as beaucoup de projets.
- Le nom du fichier est modifiable directement dans la pop-in. Entrée le renomme tout de suite.
- Le « - » à droite d'une catégorie la supprime de la liste. Les fichiers déjà préfixés ne changent pas.
- Fermer la pop-in sans choisir laisse le fichier tel quel.

Tu enchaînes plusieurs fichiers du même projet ? Coche « Renommer avec la même catégorie » : les fichiers suivants sont préfixés automatiquement, sans pop-in, pendant 30 minutes. La durée se règle, et tu peux aussi choisir de renommer jusqu'à ce que tu l'arrêtes.

Besoin de calme ? Le bouton Pause, en haut de la pop-in, la fait taire jusqu'à ce que tu reprennes. Les fichiers qui arrivent entre-temps attendent : leur nombre s'affiche à côté du picto, et un clic sur le picto te les propose.

### Tous les jours à 17 h

La pop-in annonce le rangement du jour, par exemple « 12 à supprimer, 30 à déplacer ».

- « Voir et valider » ouvre la liste complète des changements. Chaque ligne se décoche, chaque nom se modifie, et rien ne bouge avant que tu cliques « Valider ».
- Pas le moment ? Reporte d'1 h, 2 h, 3 h ou à demain.
- Si tu fermes la pop-in sans répondre, elle revient une heure plus tard.

Pas besoin d'attendre 17 h : « Ranger maintenant » lance le rangement à tout moment.

### Les autres raccourcis

Un clic sur le picto ouvre la pop-in de raccourcis :

- « Téléchargements » ouvre le dossier dans le Finder.
- « Trier autre dossier » applique le même rangement, une seule fois, à n'importe quel dossier. Tu choisis où créer les dossiers de rangement et quel préfixe projet appliquer.
- « Renommer les derniers fichiers » donne une catégorie, en un seul clic, à tous les fichiers arrivés ces 30 dernières minutes sans préfixe.

## Ce que Yokuro range et supprime

Yokuro crée ses dossiers de rangement dans Téléchargements, et leur donne une couleur pour que tu les repères d'un coup d'œil.

| Fichiers | Ce que fait Yokuro |
|---|---|
| Images (png, jpg, gif, webp, heic…) | Rangées dans « Images ». Un nom sans intérêt (IMG_1234, suite de chiffres) devient « Image 1126 - 01 » : mois, jour, numéro. |
| Captures d'écran | Rangées dans « Captures d’écran ». |
| pdf, pptx, docx, xlsx, txt, rtf | Rangés dans « Documents de travail ». |
| Vidéos mp4, mov, webm | Rangées dans « Vidéos en cours ». |
| Audios mp3, wav… | Rangés dans « Audios en cours ». |
| svg | Rangés dans « SVG Images ». |
| psd | Rangés dans « PSD Photoshop ». |
| aep | Rangés dans « AEP After Effect ». |
| json | La dernière version est rangée dans « Fichiers JSON », un sous-dossier par projet. Les versions antérieures sont supprimées. |
| html | Seule la dernière version reste (v2, v3…). Les précédentes sont supprimées. |
| zip | Supprimé si son contenu est déjà dézippé à côté, rangé dans « Fichiers ZIP » sinon. |
| Polices (ttf, otf) | Le dossier ou le zip est supprimé s'il ne contient que des polices et leurs notices. |
| Doublons « (1) », « (2) » | Supprimés s'ils sont strictement identiques à l'original. |
| Fichiers dont le nom contient « copie » | Supprimés. |
| md, eps, dmg, exe, pkg, fichiers sans extension | Supprimés. |

Tout le reste ne bouge pas, et Yokuro ne regarde que le premier niveau de Téléchargements : tes propres dossiers ne sont jamais réorganisés.

## Rien n'est perdu

- Rien n'est supprimé sans passer par la liste des changements et le bouton « Valider ».
- Un fichier supprimé part d'abord dans `Téléchargements/Yokuro/Fichiers temporaires`, rangé par date. Il n'est envoyé à la corbeille qu'au bout de 7 jours, et la corbeille le garde encore jusqu'à ce que tu la vides.
- Chaque rangement écrit un rapport daté dans `Téléchargements/Yokuro/Rapport` : ce qui a été supprimé, déplacé, renommé, et les éventuelles erreurs.

## Les réglages

La roue crantée de la pop-in ouvre les réglages :

- L'heure de la routine quotidienne, et le nombre de jours de conservation des fichiers temporaires.
- Le lancement de Yokuro au démarrage du Mac.
- L'ouverture automatique de la pop-in à l'arrivée d'un fichier.
- La durée de « Renommer avec la même catégorie », ou le renommage jusqu'à désactivation.
- Les projets, avec des mots-clés facultatifs. Si le nom d'un fichier contient un mot-clé, il reçoit son préfixe sans même que la pop-in s'ouvre. Exemple : avec le mot-clé « bnp » pour le projet « BNP PF », « maquette-bnp.pdf » devient directement « BNP PF - maquette-bnp.pdf ».
- La couleur des dossiers de Yokuro, parmi les couleurs du Finder ou une couleur libre.
- Chaque règle de rangement, activable ou non. Les captures d'écran, les audios et les svg peuvent être supprimés plutôt que rangés.

## Questions fréquentes

**Je ne vois pas le picto dans la barre de menus.**
Quand la barre est pleine, macOS masque les derniers pictos. Retire quelques icônes de la barre et il réapparaîtra.

**La pop-in s'ouvre pendant mes réunions.**
Clique sur Pause. Tu peux aussi faire respecter le mode Concentration de macOS : active l'option dans les réglages, puis donne à Yokuro l'accès complet au disque (Réglages Système > Confidentialité et sécurité > Accès complet au disque).

**Comment mettre à jour Yokuro ?**
Relance `build.sh` depuis le dossier de la nouvelle version. Tes réglages et tes projets sont conservés.

**Comment désinstaller Yokuro ?**
Quitte l'app avec le bouton marche/arrêt de la pop-in, puis supprime `Yokuro.app` dans Applications et le fichier `com.yokuro.app.plist` dans `~/Library/LaunchAgents`. Tes fichiers rangés restent où ils sont.

**J'ai un message d'erreur pendant l'installation.**
S'il parle de « developer path » ou d'outils introuvables, refais l'étape 1. S'il parle de licence Xcode, ouvre Xcode une fois pour l'accepter. Sinon, envoie une capture du Terminal à Valentin.

## Limites connues

- La détection du mode Concentration s'appuie sur un fichier interne de macOS qu'Apple ne documente pas : elle peut cesser de fonctionner après une mise à jour du système.
- La couleur des dossiers passe par une icône personnalisée. Un dossier qui a déjà sa propre icône n'est pas recoloré.

## Contact

Yokuro est développé par Valentin Stobierski. Une idée, un bug, une règle de rangement qui manque ? Écris-lui.

Version 0.17

---

## Pour les curieux : le code

L'app est écrite en Swift, sans dépendance. Un double-clic sur `Package.swift` ouvre le projet dans Xcode, où Cmd+B le compile. Lancée depuis Xcode, l'app tourne sans son picto ni son lancement au démarrage : pour l'installer, passe toujours par `build.sh`.

- `Model.swift` : réglages, projets, couleurs, chemins, dates.
- `Engine.swift` : toute la logique de tri, sans interface.
- `Store.swift` : réglages enregistrés, mode Concentration, lancement au démarrage.
- `Popover.swift` : la pop-in de la barre de menus.
- `Windows.swift` : la liste des changements et les réglages.
- `AppDelegate.swift` : le chef d'orchestre.
- `Resources/` : l'icône de l'app (`AppIcon.icns`, à partir de `AppIcon.svg`) et le picto de la barre de menus (`YokuroIcon.pdf`, à partir de `YokuroIcon.svg`).
