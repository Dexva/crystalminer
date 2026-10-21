#!/bin/sh
# Starts a real Luanti server with the crystalminer game, runs mods/crystalminer/selftest.lua
# inside it, and prints the results.
#
# Usage: tests/run_server_test.sh [path-to-luanti-binary]
# Without an argument it looks for luantiserver, minetestserver, luanti, minetest, or a macOS
# Luanti.app in /Applications.
set -e
cd "$(dirname "$0")/.."
REPO="$(pwd)"

find_binary() {
	for b in luantiserver minetestserver luanti minetest; do
		if command -v "$b" >/dev/null 2>&1; then command -v "$b"; return; fi
	done
	for app in /Applications/luanti.app /Applications/Luanti.app /Applications/minetest.app; do
		if [ -d "$app/Contents/MacOS" ]; then
			for f in "$app"/Contents/MacOS/*; do
				if [ -f "$f" ] && [ -x "$f" ]; then echo "$f"; return; fi
			done
		fi
	done
	[ -x /usr/games/minetestserver ] && echo /usr/games/minetestserver
}

SERVER="${1:-$(find_binary)}"
if [ -z "$SERVER" ]; then
	echo "No Luanti binary found. Pass its path, e.g. tests/run_server_test.sh /Applications/luanti.app/Contents/MacOS/luanti"
	exit 1
fi
# A client binary (luanti, minetest) runs as a dedicated server with --server.
case "$(basename "$SERVER")" in
	*server) MODE="" ;;
	*) MODE="--server" ;;
esac
echo "Using $SERVER $MODE"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Make the game findable wherever this version of Luanti looks for games.
mkdir -p "$TMP/games" "$TMP/world"
ln -s "$REPO" "$TMP/games/crystalminer"
for d in "$TMP/home/.minetest" "$TMP/home/.luanti" \
	"$TMP/home/Library/Application Support/minetest" "$TMP/home/Library/Application Support/luanti"; do
	mkdir -p "$d/games"
	ln -s "$REPO" "$d/games/crystalminer"
done
printf 'gameid = crystalminer\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n' > "$TMP/world/world.mt"
printf 'crystalminer.selftest = true\nserver_announce = false\n' > "$TMP/minetest.conf"

# timeout is not installed on macOS by default; use it only if present.
TIMEOUT=""
command -v timeout >/dev/null 2>&1 && TIMEOUT="timeout 180"

HOME="$TMP/home" MINETEST_GAME_PATH="$TMP/games" LUANTI_GAME_PATH="$TMP/games" $TIMEOUT "$SERVER" $MODE \
	--world "$TMP/world" --config "$TMP/minetest.conf" --port 30199 > "$TMP/server.log" 2>&1 || true

grep -E 'Luanti|Minetest' "$TMP/server.log" | head -1 || true
if [ ! -f "$TMP/world/crystalminer_selftest.txt" ]; then
	echo "Self-test did not run. Server log:"
	tail -40 "$TMP/server.log"
	exit 1
fi
grep -iE 'WARNING|ERROR' "$TMP/server.log" | grep -v 'mod storage' | head -10 || true
cat "$TMP/world/crystalminer_selftest.txt"
grep -q '^PASS$' "$TMP/world/crystalminer_selftest.txt"
