#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="$HOME/Desktop"
DESKTOP_NAME="tModLoader-MP-Fix.desktop"

mkdir -p "$BIN_DIR" "$APPS_DIR"

cp launch-tmodloader.sh "$BIN_DIR/launch-tmodloader.sh"
chmod +x "$BIN_DIR/launch-tmodloader.sh"

sed "s|{{EXEC_PATH}}|$BIN_DIR/launch-tmodloader.sh|" tModLoader-MP-Fix.desktop.template > "$APPS_DIR/$DESKTOP_NAME"
chmod +x "$APPS_DIR/$DESKTOP_NAME"

echo "Installed:"
echo "  Script:       $BIN_DIR/launch-tmodloader.sh"
echo "  App launcher: $APPS_DIR/$DESKTOP_NAME (should now appear in your app menu/launcher)"

if [[ -d "$DESKTOP_DIR" ]]; then
	cp "$APPS_DIR/$DESKTOP_NAME" "$DESKTOP_DIR/$DESKTOP_NAME"
	chmod +x "$DESKTOP_DIR/$DESKTOP_NAME"
	echo "  Desktop icon: $DESKTOP_DIR/$DESKTOP_NAME"
	echo
	echo "Note: on GNOME/Nautilus, you may need to right-click the new desktop icon"
	echo "and choose 'Allow Launching' the first time before it will run."
fi

echo
echo "Done. Use the new shortcut instead of Steam's own Play button for tModLoader."
