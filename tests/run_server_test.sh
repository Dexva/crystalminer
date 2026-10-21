#!/bin/sh
# Starts a real Luanti server with the crystalminer game, runs mods/crystalminer/selftest.lua
# inside it, and prints the results. Usage: tests/run_server_test.sh [path-to-luantiserver]
set -e
cd "$(dirname "$0")/.."
SERVER="${1:-$(command -v luantiserver || command -v minetestserver || echo /usr/games/minetestserver)}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Make the game findable: MINETEST_GAME_PATH (5.x) and the per-user games folder.
mkdir -p "$TMP/games" "$TMP/home/.minetest/games" "$TMP/world"
ln -s "$(pwd)" "$TMP/games/crystalminer"
ln -s "$(pwd)" "$TMP/home/.minetest/games/crystalminer"
printf 'gameid = crystalminer\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n' > "$TMP/world/world.mt"
printf 'crystalminer.selftest = true\nserver_announce = false\n' > "$TMP/minetest.conf"

HOME="$TMP/home" MINETEST_GAME_PATH="$TMP/games" timeout 180 "$SERVER" \
	--world "$TMP/world" --config "$TMP/minetest.conf" --port 30199 --quiet > "$TMP/server.log" 2>&1 || true

if [ ! -f "$TMP/world/crystalminer_selftest.txt" ]; then
	echo "Self-test did not run. Server log:"
	tail -40 "$TMP/server.log"
	exit 1
fi
cat "$TMP/world/crystalminer_selftest.txt"
grep -q '^PASS$' "$TMP/world/crystalminer_selftest.txt"
