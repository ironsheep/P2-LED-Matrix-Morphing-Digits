#!/usr/bin/env bash
# stamp_version.sh -- write the release version into every library file, or check that they agree.
#
# Usage:
#   bash tools/stamp_version.sh [VERSION]           stamp VERSION (x.y.z or vx.y.z); with no VERSION,
#                                                   the newest '## [x.y.z] <date>' heading of
#                                                   ChangeLog.md ('## [Unreleased]' is never taken)
#   bash tools/stamp_version.sh --check [VERSION]   change nothing; report every file:line that
#                                                   disagrees with VERSION (or the ChangeLog version)
#                                                   and exit 1; exit 0 when all agree
#
# What it stamps (the "library files" are `git ls-files 'Src/isp_hub75_morph*.spin2'`; the gitignored
# HUB75 driver files in Src/ never match and are never touched):
#   - the banner line   ''   Version.... vX.Y.Z   in the header block of every library file
#   - in Src/isp_hub75_morphCounters.spin2 (the topmost group object):
#       MORPH_VERSION = N      N = MAJOR * 10000 + MINOR * 100 + PATCH   (v1.2.3 -> 10203)
#       the line carrying  @"vX.Y.Z"  and the marker  MORPH_VERSION_STR   (returned by versionString())
# A library file with no banner line is an error in both modes (stamping never invents one).
# Exit: 0 = ok; 1 = disagreement or missing line; 2 = usage error / cannot run.

set -u
export LC_ALL=C

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SELF_DIR/.." && pwd)
TOP_FILE="Src/isp_hub75_morphCounters.spin2"

MODE=stamp
VERSION=""
for arg in "$@"; do
    case "$arg" in
        --check) MODE=check ;;
        -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
        -*) echo "stamp_version: unknown option $arg" >&2; exit 2 ;;
        *) if [ -n "$VERSION" ]; then echo "stamp_version: more than one version given" >&2; exit 2; fi
           VERSION="$arg" ;;
    esac
done

if [ -z "$VERSION" ]; then
    # newest (first) release heading; '## [Unreleased]' has no digits so it never matches
    VERSION=$(awk '/^## \[[0-9]+\.[0-9]+\.[0-9]+\]/ { v = $2; gsub(/[\[\]]/, "", v); print v; exit }' "$ROOT/ChangeLog.md")
    if [ -z "$VERSION" ]; then
        echo "stamp_version: no '## [x.y.z]' heading found in ChangeLog.md and no version argument" >&2
        exit 2
    fi
fi
VERSION=${VERSION#v}
if ! printf '%s\n' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "stamp_version: '$VERSION' is not MAJOR.MINOR.PATCH" >&2
    exit 2
fi
NUM=$(printf '%s\n' "$VERSION" | awk -F. '{ if ($2 > 99 || $3 > 99) print -1; else print $1 * 10000 + $2 * 100 + $3 }')
if [ "$NUM" = "-1" ]; then
    echo "stamp_version: MINOR and PATCH must be 0..99 for the MORPH_VERSION encoding" >&2
    exit 2
fi

FILES=$(git -C "$ROOT" ls-files 'Src/isp_hub75_morph*.spin2')
if [ -z "$FILES" ]; then
    echo "stamp_version: git ls-files lists no Src/isp_hub75_morph*.spin2" >&2
    exit 2
fi

# One awk program for both modes. check: messages on stdout, nothing rewritten.
# stamp: rewritten file on stdout, messages on stderr.
AWK_PROG='
function differ(line, msg) { if (mode == "check") say(line, msg) }
function say(line, msg) {
    if (mode == "check") print FILENAME ":" line ": " msg
    else print FILENAME ":" line ": " msg > "/dev/stderr"
    bad = 1
}
{
    out = $0
    if (substr($0, 1, 2) == QQ && $0 ~ /^.. +Version\.\.\.\. /) {
        nbanner++
        cur = $0
        sub(/^.. +Version\.\.\.\. +/, "", cur)
        if (cur != "v" ver) differ(NR, "Version banner is \"" cur "\", expected \"v" ver "\"")
        out = QQ "   Version.... v" ver
    } else if (isTop && $0 ~ /^[ \t]+MORPH_VERSION[ \t]*=/) {
        nconst++
        cur = $0
        sub(/^[ \t]+MORPH_VERSION[ \t]*=[ \t]*/, "", cur)
        sub(/[^0-9].*$/, "", cur)
        if (cur != num) differ(NR, "MORPH_VERSION is " cur ", expected " num)
        sub(/MORPH_VERSION[ \t]*=[ \t]*[0-9]+/, "MORPH_VERSION = " num, out)
    } else if (isTop && index($0, "MORPH_VERSION_STR") && $0 ~ /@"v[0-9]+\.[0-9]+\.[0-9]+"/) {
        nstr++
        match($0, /@"v[0-9]+\.[0-9]+\.[0-9]+"/)
        cur = substr($0, RSTART + 2, RLENGTH - 3)
        if (cur != "v" ver) differ(NR, "version string is \"" cur "\", expected \"v" ver "\"")
        sub(/@"v[0-9]+\.[0-9]+\.[0-9]+"/, "@\"v" ver "\"", out)
    }
    if (mode == "stamp") print out
}
END {
    if (nbanner == 0) say(1, "no Version banner line in the header block")
    if (nbanner > 1) say(1, nbanner " Version banner lines, expected 1")
    if (isTop && nconst != 1) say(1, "expected exactly 1 MORPH_VERSION = line, found " nconst + 0)
    if (isTop && nstr != 1) say(1, "expected exactly 1 MORPH_VERSION_STR line with @\"vX.Y.Z\", found " nstr + 0)
    exit bad ? 1 : 0
}'

SCRATCH=$(mktemp -d "${TMPDIR:-/private/tmp}/stamp_version.XXXXXX") || exit 2
trap 'rm -rf "$SCRATCH"' EXIT

STATUS=0
SEEN_TOP=0
for f in $FILES; do
    isTop=0
    if [ "$f" = "$TOP_FILE" ]; then isTop=1; SEEN_TOP=1; fi
    if [ "$MODE" = check ]; then
        awk -v mode=check -v ver="$VERSION" -v num="$NUM" -v isTop=$isTop -v QQ="''" "$AWK_PROG" "$ROOT/$f" | sed "s#^$ROOT/##"
        [ "${PIPESTATUS[0]}" -eq 0 ] || STATUS=1
    else
        if awk -v mode=stamp -v ver="$VERSION" -v num="$NUM" -v isTop=$isTop -v QQ="''" "$AWK_PROG" "$ROOT/$f" > "$SCRATCH/out" 2> "$SCRATCH/err"; then
            if ! cmp -s "$SCRATCH/out" "$ROOT/$f"; then
                cat "$SCRATCH/out" > "$ROOT/$f"
                echo "stamped $f"
            fi
        else
            sed "s#^$ROOT/##" "$SCRATCH/err" >&2
            STATUS=1
        fi
    fi
done
if [ "$SEEN_TOP" -eq 0 ]; then
    echo "$TOP_FILE: not among the library files (git ls-files); MORPH_VERSION cannot be handled" >&2
    STATUS=1
fi

if [ "$STATUS" -eq 0 ]; then
    if [ "$MODE" = check ]; then echo "stamp_version --check: all library files agree on v$VERSION (MORPH_VERSION = $NUM)"
    else echo "stamp_version: library files carry v$VERSION (MORPH_VERSION = $NUM)"; fi
else
    echo "stamp_version: FAILED for v$VERSION (see file:line above)" >&2
fi
exit $STATUS
