#!/usr/bin/env bash
# Focused tests for developer tools that are not exercised inside WoW.
set -euo pipefail
cd "$(dirname "$0")/.."

TEMP_DIR="$(mktemp -d /tmp/tempus-tools.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT

python3 tools/gen_changelog.py --output "$TEMP_DIR/Changelog.lua"
python3 tools/gen_changelog.py --output "$TEMP_DIR/Changelog.lua" --check
printf '\n-- stale\n' >> "$TEMP_DIR/Changelog.lua"
before="$(sha256sum "$TEMP_DIR/Changelog.lua" | cut -d' ' -f1)"
if python3 tools/gen_changelog.py --output "$TEMP_DIR/Changelog.lua" --check >/dev/null 2>&1; then
    echo "generated changelog check accepted stale output" >&2
    exit 1
fi
after="$(sha256sum "$TEMP_DIR/Changelog.lua" | cut -d' ' -f1)"
[[ "$before" == "$after" ]] || { echo "generated changelog check changed its output" >&2; exit 1; }
echo "ok    tools/gen_changelog.py --check"
