#!/bin/bash
# Vérifie Yokuro sans Mac, avec la toolchain Swift open source pour Linux.
#   1. types de toute l'app, interface comprise, contre des substituts d'AppKit et de SwiftUI ;
#   2. comportement du moteur de tri sur un dossier Téléchargements simulé.
# Usage : ./verifier.sh "chemin/vers/Yokuro vX/Sources/Yokuro"
set -e
SRC=${1:?Indique le dossier Sources/Yokuro du projet}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT=$(mktemp -d)

echo "1. Types"
mkdir -p "$OUT/modules" "$OUT/copie"
swiftc -emit-module -module-name Combine -parse-as-library "$HERE/substituts/Combine.swift" -emit-module-path "$OUT/modules/Combine.swiftmodule"
swiftc -emit-module -module-name AppKit -parse-as-library "$HERE/substituts/AppKit.swift" -emit-module-path "$OUT/modules/AppKit.swiftmodule"
swiftc -emit-module -module-name SwiftUI -parse-as-library -I "$OUT/modules" "$HERE/substituts/SwiftUI.swift" -emit-module-path "$OUT/modules/SwiftUI.swiftmodule"
# Seule adaptation de la copie vérifiée : @objc et #selector, propres à Objective-C.
python3 - "$SRC" "$OUT/copie" <<'PY'
import os, sys
src, out = sys.argv[1], sys.argv[2]
for name in os.listdir(src):
    if not name.endswith('.swift'): continue
    text = open(os.path.join(src, name)).read().replace('@objc ', '')
    parts, i = [], 0
    while True:
        j = text.find('#selector(', i)
        if j < 0:
            parts.append(text[i:]); break
        k, depth = j + len('#selector('), 1
        while depth:
            depth += {'(': 1, ')': -1}.get(text[k], 0); k += 1
        parts += [text[i:j], 'Selector("' + text[j + len('#selector('):k - 1] + '")']; i = k
    open(os.path.join(out, name), 'w').write(''.join(parts))
PY
swiftc -typecheck -I "$OUT/modules" "$OUT"/copie/*.swift
echo "   aucun problème de types"

echo "2. Moteur de tri"
swiftc "$SRC/Model.swift" "$SRC/Engine.swift" "$HERE/moteur/Shim.swift" "$HERE/moteur/main.swift" -o "$OUT/moteur" 2>&1 | grep -v "warning" || true
"$OUT/moteur" | grep -E "ECHEC|vérifications réussies"
