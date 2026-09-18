#!/usr/bin/env bash
set -euo pipefail

# Launches tModLoader directly (not via Steam's "Play" button), so it never
# sets SteamClientLaunch=1 in its environment. tModLoader only spawns its
# internal "TerrariaSteamClient" helper process -- which claims Steam's
# Terraria app ID (105600) for the whole play session, and is the actual
# cause of Steam showing "Terraria" instead of "tModLoader" to your friends
# on Linux -- when that variable is set. See README.md for the full story.
#
# tModLoader still correctly registers itself with Steam as tModLoader
# (app ID 1281930) when launched this way, via its own steam_appid.txt
# fallback path (used by any game started outside Steam's launcher).

TMOD_APPID=1281930

find_tmod_dir() {
	# Allow an explicit override if auto-detection doesn't find it.
	if [[ -n "${TMOD_INSTALL_DIR:-}" && -x "$TMOD_INSTALL_DIR/start-tModLoader.sh" ]]; then
		echo "$TMOD_INSTALL_DIR"
		return 0
	fi

	local steam_root candidates=()
	for steam_root in "$HOME/.steam/steam" "$HOME/.steam/debian-installation" "$HOME/.local/share/Steam" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
		[[ -d "$steam_root/steamapps" ]] && candidates+=("$steam_root/steamapps")
	done

	# Parse libraryfolders.vdf (in each candidate found so far) for any
	# additional Steam library locations on other drives/paths.
	local vdf path extra=()
	for vdf in "${candidates[@]/%//libraryfolders.vdf}"; do
		[[ -f "$vdf" ]] || continue
		while IFS= read -r path; do
			[[ -d "$path/steamapps" ]] && extra+=("$path/steamapps")
		done < <(grep -oP '"path"\s+"\K[^"]+' "$vdf" 2>/dev/null)
	done
	candidates+=("${extra[@]}")

	local c
	for c in "${candidates[@]}"; do
		if [[ -x "$c/common/tModLoader/start-tModLoader.sh" ]]; then
			echo "$c/common/tModLoader"
			return 0
		fi
	done

	return 1
}

ensure_steam_running() {
	if pgrep -x steam >/dev/null 2>&1 || pgrep -f steamwebhelper >/dev/null 2>&1; then
		return 0
	fi

	echo "Steam doesn't appear to be running. Starting it now..."
	local steam_bin
	steam_bin="$(command -v steam || true)"
	if [[ -z "$steam_bin" ]]; then
		echo "Could not find the 'steam' executable on PATH." >&2
		echo "Please start Steam manually, log in, then run this script again." >&2
		exit 1
	fi

	nohup "$steam_bin" -silent >/dev/null 2>&1 &
	disown

	echo -n "Waiting for Steam to finish starting"
	local waited=0
	until pgrep -f steamwebhelper >/dev/null 2>&1; do
		sleep 1
		echo -n "."
		waited=$((waited + 1))
		if (( waited > 60 )); then
			echo
			echo "Steam is taking too long to start. Please check it manually (make sure you're logged in), then run this script again." >&2
			exit 1
		fi
	done
	echo
	# Give Steam a little extra time to finish logging in / settling before
	# tModLoader tries to talk to it.
	sleep 5
}

main() {
	local tmod_dir
	if ! tmod_dir="$(find_tmod_dir)"; then
		echo "Could not find a tModLoader installation in any known Steam library." >&2
		echo "If it's installed somewhere non-standard, point this script at it directly:" >&2
		echo "  TMOD_INSTALL_DIR=/path/to/steamapps/common/tModLoader $0" >&2
		exit 1
	fi

	ensure_steam_running

	echo "Launching tModLoader directly from: $tmod_dir"
	echo "(bypassing Steam's launcher so it registers itself as tModLoader / app $TMOD_APPID, not Terraria)"
	cd "$tmod_dir"
	exec ./start-tModLoader.sh "$@"
}

main "$@"
