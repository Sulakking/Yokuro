#!/bin/bash
# Compile Yokuro, l'installe dans /Applications et le lance.
set -e
cd "$(dirname "$0")"

if ! command -v swift >/dev/null; then
    echo "Swift est introuvable. Installe Xcode, ou lance : xcode-select --install"
    exit 1
fi

swift build -c release

APP="Yokuro.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/fr.lproj" # fr.lproj : app en français
cp .build/release/Yokuro "$APP/Contents/MacOS/Yokuro"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/YokuroIcon.pdf Resources/AppIcon.icns Resources/Pictos/*.pdf "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

pkill -x Yokuro 2>/dev/null || true
# On attend que l'ancienne version ait vraiment quitté : sinon la nouvelle, qui refuse de tourner en double, se referme.
for _ in $(seq 1 50); do pgrep -x Yokuro >/dev/null || break; sleep 0.2; done
# Dossier d'installation : Applications si on a les droits d'administrateur,
# sinon le dossier Applications personnel, qui n'en demande pas.
if [ -w /Applications ] && rm -rf "/Applications/$APP" 2>/dev/null; then
    DEST="/Applications"
    rm -rf "$HOME/Applications/$APP" # pas de doublon dans le dossier personnel
else
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    rm -rf "$DEST/$APP"
    echo ""
    echo "Pas de droits d'administrateur : Yokuro s'installe dans ton dossier Applications personnel ($DEST)."
    if [ -e "/Applications/$APP" ]; then
        echo "L'ancienne version reste dans /Applications : mets-la à la corbeille quand tu auras les droits."
    fi
fi
cp -R "$APP" "$DEST/"
touch "$DEST/$APP" # le Finder relit l'icône
open "$DEST/$APP"
echo "Yokuro est installé et lancé : cherche son picto dans la barre de menus."
