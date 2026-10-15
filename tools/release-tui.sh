#!/usr/bin/env bash
# Interactive release: picks the next version, turns "## Unreleased" in CHANGELOG.md into that
# version, then hands over to tools/release.sh (checks, tests, commit, tag, push). Uses gum for
# the menus when it is installed and plain prompts otherwise.
#   tools/release-tui.sh                 pick the version from a menu
#   tools/release-tui.sh 2.5.0           use this version
#   tools/release-tui.sh --dry-run       run every check, change nothing (files are restored)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=""; DRY=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        [0-9]*.[0-9]*.[0-9]*) VERSION="$arg" ;;
        *) echo "usage: tools/release-tui.sh [X.Y.Z] [--dry-run]" >&2; exit 2 ;;
    esac
done
git() { command git -c core.fileMode=false "$@"; }
HAVE_GUM=0; command -v gum >/dev/null && [[ -t 0 && -t 1 ]] && HAVE_GUM=1

say()  { if [[ $HAVE_GUM -eq 1 ]]; then gum style --foreground 212 --bold "$*"; else printf '\n== %s\n' "$*"; fi; }
note() { if [[ $HAVE_GUM -eq 1 ]]; then gum style --faint "$*"; else echo "$*"; fi; }
die()  { echo "error: $*" >&2; exit 1; }
confirm() {     # confirm "question" -> 0 for yes
    if [[ $HAVE_GUM -eq 1 ]]; then gum confirm "$1"; else read -r -p "$1 [y/N] " a; [[ "$a" =~ ^[Yy]$ ]]; fi
}

CURRENT="$(sed -n 's/^## Version: *//p' Tempus.toc | tr -d '\r')"
[[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "cannot read the version from Tempus.toc"
MAJ="${BASH_REMATCH[1]}"; MIN="${BASH_REMATCH[2]}"; PAT="${BASH_REMATCH[3]}"
PATCH="$MAJ.$MIN.$((PAT + 1))"; MINOR="$MAJ.$((MIN + 1)).0"; MAJOR="$((MAJ + 1)).0.0"

say "Tempus release (current $CURRENT)"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "not on main"
if git fetch -q origin 2>/dev/null; then
    behind="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
    [[ "$behind" == "0" ]] || die "main is $behind commit(s) behind origin; pull first"
else
    note "could not reach origin; skipping the up-to-date check"
fi

# What is going out: the Unreleased section, or the first entry if it is already versioned.
FIRST="$(grep -m1 '^## ' CHANGELOG.md | sed 's/^## //')"
if [[ "$FIRST" == "Unreleased" ]]; then
    NOTES="$(awk '/^## Unreleased/{f=1;next} /^## /{f=0} f' CHANGELOG.md)"
    [[ -n "${NOTES//[[:space:]]/}" ]] || die "the Unreleased section of CHANGELOG.md is empty"
    say "Going out in this release"
    if [[ $HAVE_GUM -eq 1 ]]; then printf '%s\n' "$NOTES" | gum format; else printf '%s\n' "$NOTES"; fi
else
    note "CHANGELOG.md already starts with '## $FIRST' and has no Unreleased section."
fi

# Pending files, so nothing unexpected is swept into the release commit.
PENDING="$(git status --short | grep -v '^??' || true)"
UNTRACKED="$(git status --short | grep '^??' | grep -v 'rewards.png' || true)"
if [[ -n "$PENDING" ]]; then say "Pending changes (committed with the release)"; echo "$PENDING"; fi
if [[ -n "$UNTRACKED" ]]; then
    say "Untracked files (included too; release.sh uses git add -A)"; echo "$UNTRACKED"
fi

# Version.
if [[ -z "$VERSION" ]]; then
    if [[ "$FIRST" != "Unreleased" && "$FIRST" != "$CURRENT" ]]; then
        VERSION="$FIRST"; note "using the version already in CHANGELOG.md: $VERSION"
    elif [[ $HAVE_GUM -eq 1 ]]; then
        choice="$(gum choose --header "Next version" \
            "patch  $PATCH  (fixes only)" "minor  $MINOR  (new features)" "major  $MAJOR  (breaking)" "custom...")" || exit 1
        case "$choice" in
            patch*) VERSION="$PATCH" ;; minor*) VERSION="$MINOR" ;; major*) VERSION="$MAJOR" ;;
            *) VERSION="$(gum input --placeholder "X.Y.Z")" ;;
        esac
    else
        echo "1) patch $PATCH   2) minor $MINOR   3) major $MAJOR   or type a version"
        read -r -p "Next version [2]: " c
        case "${c:-2}" in 1) VERSION="$PATCH" ;; 2) VERSION="$MINOR" ;; 3) VERSION="$MAJOR" ;; *) VERSION="$c" ;; esac
    fi
fi
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "'$VERSION' is not a version like 2.5.0"
[[ "$VERSION" != "$CURRENT" ]] || die "$VERSION is the current version"
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && die "tag v$VERSION already exists"

if [[ $DRY -eq 1 ]]; then
    say "Dry run for $VERSION (files are restored afterwards)"
else
    confirm "Release Tempus $VERSION (from $CURRENT)? It commits, tags and pushes." || { echo "cancelled."; exit 1; }
fi

# Fold Unreleased into the new version; a dry run puts everything back when it ends.
BACKUP="$(mktemp -d)"
cp CHANGELOG.md Core/Changelog.lua Tempus.toc "$BACKUP/"
restore() { cp "$BACKUP/CHANGELOG.md" CHANGELOG.md; cp "$BACKUP/Changelog.lua" Core/Changelog.lua; cp "$BACKUP/Tempus.toc" Tempus.toc; }
cleanup() { [[ $DRY -eq 1 ]] && restore; rm -rf "$BACKUP"; }
trap cleanup EXIT
if [[ "$FIRST" == "Unreleased" ]]; then
    sed -i "0,/^## Unreleased\$/s//## $VERSION/" CHANGELOG.md
    note "CHANGELOG.md: Unreleased -> $VERSION"
fi

args=("$VERSION")
if [[ $DRY -eq 1 ]]; then args+=(--dry-run); else args+=(--yes); fi
say "Running tools/release.sh ${args[*]}"
if ! tools/release.sh "${args[@]}"; then
    # A failed real run leaves the version edit in place so it can be fixed and re-run.
    die "release.sh stopped; CHANGELOG.md now reads '## $VERSION'. Fix the problem and re-run."
fi
[[ $DRY -eq 1 ]] && note "dry run finished; nothing was changed." || say "Released $VERSION"
