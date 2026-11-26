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
cp Resources/YokuroIcon.pdf Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

pkill -x Yokuro 2>/dev/null || true
rm -rf "/Applications/$APP"
cp -R "$APP" /Applications/
touch "/Applications/$APP" # le Finder relit l'icône
open "/Applications/$APP"
echo "Yokuro est installé et lancé : cherche son picto dans la barre de menus."
