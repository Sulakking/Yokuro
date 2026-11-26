# Yokuro : vérifications

Outillage utilisé par Claude pour contrôler Yokuro sans Mac. Il ne sert pas à faire tourner l'app et n'a pas besoin d'être conservé avec elle.

Pour une prochaine évolution, joindre ce dossier avec le projet : les mêmes contrôles pourront être rejoués après chaque modification.

- `substituts/` : déclarations d'AppKit, SwiftUI et Combine limitées à ce que Yokuro utilise, pour vérifier les types de l'interface.
- `moteur/` : 187 vérifications du moteur de tri sur un dossier Téléchargements simulé.
- `verifier.sh` : lance les deux contrôles. Demande la toolchain Swift pour Linux (testé avec Swift 5.10).

Limite : les substituts reflètent les API d'Apple telles que Claude les connaît. Seule une compilation sur Mac valide l'app pour de bon.
