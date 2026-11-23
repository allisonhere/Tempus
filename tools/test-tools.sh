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

# Gear Advisor data tools: generated files are current, and pasted game output is read correctly.
python3 tools/gen_gearadvisor.py weights --check
python3 tools/gen_gearadvisor.py signals --check
cat > "$TEMP_DIR/signatures.txt" <<'SIG'
# comment
ROLE=CAT | DRUID 22, 7 points: Ferocity x5, Feral Swiftness x2
ROLE=CAT | DRUID 30, 9 points: Ferocity x5, Predatory Strikes x4
ROLE=RESTO | DRUID 22, 6 points: Genesis x5, Nature's Majesty x1
ROLE=BEAR | DRUID 22, 4 points: Ferocity x4
ROLE=FURY | WARRIOR 20, 3 points: Cruelty x3
SIG
python3 tools/gen_gearadvisor.py signals --input "$TEMP_DIR/signatures.txt" --output "$TEMP_DIR/signals.lua"
grep -q 'CAT = { { "Feral Swiftness", 1 }, { "Predatory Strikes", 1 } }' "$TEMP_DIR/signals.lua" || { echo "signals: cat markers wrong" >&2; cat "$TEMP_DIR/signals.lua" >&2; exit 1; }
grep -q "RESTO = { { \"Genesis\", 1 }, { \"Nature's Majesty\", 1 } }" "$TEMP_DIR/signals.lua" || { echo "signals: resto markers wrong" >&2; cat "$TEMP_DIR/signals.lua" >&2; exit 1; }
if grep -q "WARRIOR" "$TEMP_DIR/signals.lua"; then echo "signals: one build alone marks nothing" >&2; exit 1; fi
if grep -q '"Ferocity"' "$TEMP_DIR/signals.lua"; then echo "signals: a shared talent must not be a marker" >&2; exit 1; fi
echo "ok    tools/gen_gearadvisor.py signals"
mkdir "$TEMP_DIR/samples"
cat > "$TEMP_DIR/samples/a.txt" <<'SAMPLE'
Tempus: 3 items read, 3 stat names
Tempus: ITEM_MOD_AGILITY_SHORT: 3 items, 2 to 12, e.g. Name head
Tempus: NO WEIGHT  ITEM_MOD_WEIRD_THING_SHORT: 1 items, 33, e.g. Robe
|cffaabbccTempus:|r ITEM_MOD_SPELL_POWER_SHORT: 2 items, 5 to 9, e.g. Staff
SAMPLE
report="$(python3 tools/gen_gearadvisor.py stats --input "$TEMP_DIR/samples")"
grep -q "ITEM_MOD_WEIRD_THING_SHORT.*NO WEIGHT" <<<"$report" || { echo "stats: unknown key not flagged" >&2; echo "$report" >&2; exit 1; }
grep -q "ITEM_MOD_AGILITY_SHORT.*Agility (seen)" <<<"$report" || { echo "stats: mapped key not reported" >&2; exit 1; }
grep -q "ITEM_MOD_BLOCK_RATING_SHORT" <<<"$report" || { echo "stats: unseen assumed keys not listed" >&2; exit 1; }
echo "ok    tools/gen_gearadvisor.py stats"
