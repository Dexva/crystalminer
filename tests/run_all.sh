#!/bin/sh
# Runs every test: the pure-Lua unit tests, then the in-server self-test.
set -e
cd "$(dirname "$0")/.."
LUA="$(command -v luajit || command -v lua5.1)"
for t in tests/test_*.lua; do "$LUA" "$t"; done
tests/run_server_test.sh "$@"
