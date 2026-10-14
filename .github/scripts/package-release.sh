#!/usr/bin/env bash
# Package one release of the morphing digits: our library and demo sources only, never the HUB75 driver.
#
#   .github/scripts/package-release.sh v2.0.0 [outDir]
#
# Checks that the tag, the library version (MORPH_VERSION and versionString() in the group object) and
# the newest ChangeLog.md release heading name the same version, then writes to outDir (default dist/):
#   <PACKAGE_PREFIX>-v<version>.zip   one folder of the same name: the tracked library and demo .spin2
#                                     files, LICENSE, ChangeLog.md and README.md, to copy over the driver;
#                                     the README is the package's own (README_TEMPLATE), not the repo's
#   release-body.md                   the release page text: this version's whole ChangeLog.md entry
# Run from the repository root. Used by .github/workflows/release.yml and for a local dry run.
#
# The packaged sources are every TRACKED file matching SOURCE_GLOBS (never a hand list). Test programs
# (test_hub75_morph*) never match, and a driver file is never tracked here, so neither can ship; a file on
# disk that matches the globs but is not tracked stops the release.

set -euo pipefail

PACKAGE_PREFIX="p2-obex-morphing-digits"
GROUP_FILE="Src/isp_hub75_morphCounters.spin2"          # holds MORPH_VERSION and versionString()
README_TEMPLATE=".github/release/README-package.md"     # {{VERSION}} is filled in
CHANGELOG="ChangeLog.md"
SOURCE_GLOBS=("Src/isp_hub75_morph*.spin2" "Src/demo_hub75_morph*.spin2")
DOCS=(LICENSE "$CHANGELOG")

fail() { echo "package-release: $*" >&2; exit 1; }

tag="${1:-}"
outDir="${2:-dist}"
[[ "$tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || fail "give a tag of the form v1.2.3 (got '$tag')"
version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
versionNumber=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))

# version lock 1: the library's MORPH_VERSION (MAJOR * 10000 + MINOR * 100 + PATCH) and its version string
sourceNumber=$(sed -nE 's/^[[:space:]]*MORPH_VERSION[[:space:]]*=[[:space:]]*([0-9_]+).*/\1/p' "$GROUP_FILE" | tr -d '_')
[[ "$sourceNumber" == "$versionNumber" ]] || fail "MORPH_VERSION in $GROUP_FILE is '$sourceNumber', tag $tag needs $versionNumber"
sourceString=$(sed -nE 's/.*@"v([0-9]+\.[0-9]+\.[0-9]+)".*MORPH_VERSION_STR.*/\1/p' "$GROUP_FILE")
[[ "$sourceString" == "$version" ]] || fail "versionString() in $GROUP_FILE is 'v$sourceString', tag is $tag"

# version lock 2: the newest release heading of the changelog. Its form is '## vX.Y.Z (date)' (central
# changelog guide); entries that shipped before keep '## [x.y.z] date', so both forms are read.
headingRegex='^## \[?v?([0-9]+\.[0-9]+\.[0-9]+)\]?( |$)'
changelogVersion=$(grep -m1 -E "$headingRegex" "$CHANGELOG" | sed -E "s/$headingRegex.*/\1/")
[[ "$changelogVersion" == "$version" ]] || fail "newest $CHANGELOG entry is 'v$changelogVersion', tag is $tag"

# the release page text: everything under this version's heading up to the next '## ' heading, blank
# lines trimmed at both ends (the whole version token is matched, so v1.0.1 never matches v1.0.10)
escaped="${version//./\\.}"
releaseBody=$(awk -v re="^## \\\\[?v?${escaped}\\\\]?( |$)" '
    $0 ~ re { inEntry = 1; next }
    inEntry && /^## / { exit }
    inEntry && (NF > 0 || started) { started = 1; lines[++n] = $0 }
    END { while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }
' "$CHANGELOG")
[[ -n "$releaseBody" ]] || fail "no entry text under the v$version heading in $CHANGELOG"

# the sources: every tracked file matching the globs; an untracked match (a stray or driver file) stops it
SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(git ls-files -- "${SOURCE_GLOBS[@]}")   # (no mapfile: macOS bash 3.2)
[[ ${#SOURCES[@]} -gt 0 ]] || fail "no tracked file matches ${SOURCE_GLOBS[*]}"
for file in ${SOURCE_GLOBS[@]}; do
    [[ -e "$file" ]] || continue
    git ls-files --error-unmatch "$file" > /dev/null 2>&1 || fail "$file matches the package globs but is not tracked by this repository"
done
for file in "${DOCS[@]}" "$README_TEMPLATE"; do
    [[ -f "$file" ]] || fail "missing $file"
    git ls-files --error-unmatch "$file" > /dev/null 2>&1 || fail "$file is not tracked by this repository"
done

# the package README lists every file it ships: one missing from its table stops the release
for file in "${SOURCES[@]}" "${DOCS[@]}"; do
    grep -q "\*\*$(basename "$file")\*\*" "$README_TEMPLATE" || fail "$(basename "$file") is not in the file table of $README_TEMPLATE"
done

name="${PACKAGE_PREFIX}-v${version}"
mkdir -p "$outDir"
outDir=$(cd "$outDir" && pwd)
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

mkdir "$staging/$name"
cp "${SOURCES[@]}" "${DOCS[@]}" "$staging/$name/"
sed "s/{{VERSION}}/$version/g" "$README_TEMPLATE" > "$staging/$name/README.md"
rm -f "$outDir/$name.zip"
(cd "$staging" && zip -qrX "$outDir/$name.zip" "$name")

printf '%s\n' "$releaseBody" > "$outDir/release-body.md"

echo "package-release: $outDir/$name.zip"
unzip -l "$outDir/$name.zip"
echo "package-release: release body:"
cat "$outDir/release-body.md"
