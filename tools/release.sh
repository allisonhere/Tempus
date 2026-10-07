#!/usr/bin/env bash
# Cuts a release: checks the changelog, sets the version, commits, tags and pushes. A pushed tag
# is what makes CurseForge's packager (and .github/workflows/release.yml) build the release.
#   tools/release.sh 2.2.2            asks before pushing
#   tools/release.sh 2.2.2 --yes      pushes without asking
#   tools/release.sh 2.2.2 --dry-run  checks everything, changes nothing
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"; shift || true
YES=0; DRY=0
for arg in "$@"; do
    case "$arg" in --yes) YES=1 ;; --dry-run) DRY=1 ;; *) echo "unknown option: $arg" >&2; exit 2 ;; esac
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: tools/release.sh X.Y.Z [--yes] [--dry-run]" >&2; exit 2; }
TAG="v$VERSION"
git() { command git -c core.fileMode=false "$@"; }
step() { printf '\n== %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

step "Checks"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "not on main"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"
grep -q "^## $VERSION\$" CHANGELOG.md || die "CHANGELOG.md has no '## $VERSION' section"
[[ "$(grep -m1 '^## ' CHANGELOG.md)" == "## $VERSION" ]] || die "'## $VERSION' must be the first entry in CHANGELOG.md"
step "Changelog and tests"
GENERATED="$(mktemp /tmp/tempus-changelog.XXXXXX)"
trap 'rm -f "$GENERATED"' EXIT
python3 tools/gen_changelog.py --output "$GENERATED"
LUAC="$(command -v luac5.1 || command -v luac5.1.5 || true)"
[[ -n "$LUAC" ]] || die "luac5.1 not found"
"$LUAC" -p "$GENERATED"
if [[ $DRY -eq 1 ]]; then
    # Check the prospective changelog without touching the tracked generated file.
    tools/check.sh --skip-changelog-sync || die "checks failed"
else
    cp "$GENERATED" Core/Changelog.lua
    tools/check.sh || die "checks failed"
fi

if [[ $DRY -eq 1 ]]; then
    echo; echo "dry run: checks passed. Would set Tempus.toc to $VERSION, regenerate Core/Changelog.lua,"
    echo "commit everything pending as 'Release $VERSION', tag $TAG and push main + $TAG."
    git status --short | grep -v '^??' | sed 's/^/  pending: /' || true
    exit 0
fi

step "Version and changelog"
sed -i "s/^## Version: .*/## Version: $VERSION/" Tempus.toc
grep -q "version = \"$VERSION\"" Core/Changelog.lua || die "Core/Changelog.lua did not pick up $VERSION"
echo "Tempus.toc -> $VERSION"

step "Commit"
git add -A -- . ':!rewards.png'
if git diff --cached --quiet; then
    echo "nothing to commit"
else
    git diff --cached --stat | tail -5
    git commit -q -m "Release $VERSION"
fi

step "Tag and push"
git tag -a "$TAG" -m "Tempus $VERSION"
if [[ $YES -ne 1 ]]; then
    read -r -p "Push main and $TAG to origin now? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "not pushed. Push later with: git push origin main $TAG"; exit 0; }
fi
git push origin main "$TAG"
echo "pushed $TAG"
