#!/bin/bash
# Regenerates Packaging/AppIcon.icns from generate_icon.swift.
# Only needs to be re-run if the icon design itself changes.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET=".build/AppIcon.iconset"
rm -rf "$ICONSET"

swift Scripts/generate_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o Packaging/AppIcon.icns

echo "Wrote Packaging/AppIcon.icns"
