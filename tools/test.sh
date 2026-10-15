#!/usr/bin/env bash
# Runs every tests/*.lua under Lua 5.1, the version WoW uses.
cd "$(dirname "$0")/.."
LUA="$(command -v lua5.1 || command -v luajit || true)"
[[ -n "$LUA" ]] || { echo "lua5.1 not found; install it to run the tests" >&2; exit 2; }
fail=0
for f in tests/*.lua; do
    if out="$(timeout 60 "$LUA" "$f" 2>&1)"; then
        echo "ok    $f"
    else
        echo "FAIL  $f"; echo "$out" | tail -5 | sed 's/^/      /'; fail=1
    fi
done
exit $fail
