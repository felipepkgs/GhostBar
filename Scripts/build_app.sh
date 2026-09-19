#!/bin/bash
# Builds GhostBar.app — a real, double-clickable app bundle instead of a
# `swift run` terminal invocation. Needed for a proper Dock/menu-bar icon and
# for "Launch at Login" (SMAppService.mainApp expects a bundled app).
#
# ponytail: ad-hoc signed only (`codesign -s -`), no Developer ID — that
# costs money the user doesn't want to spend yet. Gatekeeper will still warn
# on first open; right-click > Open clears it, same as any unsigned app.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="GhostBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/GhostBar "$APP/Contents/MacOS/"
cp Packaging/Info.plist "$APP/Contents/"
cp Packaging/AppIcon.icns "$APP/Contents/Resources/"
cp -R .build/release/GhostBar_GhostBar.bundle "$APP/Contents/Resources/"

codesign --force --deep -s - "$APP"

echo "Built $APP"
echo "Move it to /Applications, then right-click > Open the first time (unsigned build)."
