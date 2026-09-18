#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="$HOME/Desktop"
DESKTOP_NAME="tModLoader-MP-Fix.desktop"

rm -fv "$BIN_DIR/launch-tmodloader.sh"
rm -fv "$APPS_DIR/$DESKTOP_NAME"
rm -fv "$DESKTOP_DIR/$DESKTOP_NAME"

echo "Removed. Steam's own Play button for tModLoader is unaffected."
