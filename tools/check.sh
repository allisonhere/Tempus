#!/usr/bin/env bash
# Read-only verification used locally, in CI and before releases.
set -euo pipefail
cd "$(dirname "$0")/.."

SKIP_CHANGELOG=0
for arg in "$@"; do
    case "$arg" in
        --skip-changelog-sync) SKIP_CHANGELOG=1 ;;
        *) echo "usage: tools/check.sh [--skip-changelog-sync]" >&2; exit 2 ;;
    esac
done

LUA="$(command -v lua5.1 || command -v luajit || true)"
[[ -n "$LUA" ]] || { echo "lua5.1 not found; install it to run the checks" >&2; exit 2; }
LUAC="$(command -v luac5.1 || command -v luac5.1.5 || true)"
[[ -n "$LUAC" ]] || { echo "luac5.1 not found; install it to run the checks" >&2; exit 2; }

echo "== Lua 5.1 syntax"
find Core Config Modules -name '*.lua' -print0 | sort -z | xargs -0 -n1 "$LUAC" -p
echo "ok"

if [[ $SKIP_CHANGELOG -eq 0 ]]; then
    echo "== Generated changelog"
    python3 tools/gen_changelog.py --check
    echo "ok"
fi

echo "== Tool regressions"
tools/test-tools.sh

echo "== Lua tests"
tools/test.sh
