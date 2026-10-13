#!/usr/bin/env bash
# run.sh -- falsification control for tools/check_docs.sh (DOC_AUDIT_COMMAND).
#
# Proves that every detection of the documentation-drift checker still fires. For each detection
# it builds a violating variant (red) and a clean twin (green) from the tracked base mini-repo
# base/ inside a temp directory, runs the real checker on each, and requires:
#   red   exit code as expected (normally 1) AND the output names the expected finding at its file:line
#   green exit code 0
# The base mini-repo itself must also run clean (exit 0). Nothing is written into the repo tree.
#
# Usage:   bash tools/tests/check_docs/run.sh
# Environment:
#   CHECKER   checker to run (default: tools/check_docs.sh of this repo). Point it at a scratch
#             copy to prove the suite notices a broken detection.
# Output:  one line per detection pair, then "N detections, N red, N green (base twin rc=R)".
# Exit:    0 = every pair behaved and the detection types of the checker are all covered;
#          1 = any pair misbehaved, or the checker has a detection type no pair exercises;
#          2 = could not run.
#
# The fixtures use the checker's DOCS_ROOT / DOCS_DRIVER_DIR overrides. driver/ is a one-file
# stand-in for the driver, which is never versioned here, so the suite runs on a fresh clone.
# This directory is a named working area of the checker (tools/tests/): its fixture documents
# are never audited as project documents.

set -u
export LC_ALL=C

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
CHK=${CHECKER:-$REPO/tools/check_docs.sh}
BASE=$HERE/base
DRV=$HERE/driver
[ -f "$CHK" ] || { echo "run.sh: checker not found: $CHK" >&2; exit 2; }
[ -d "$BASE" ] && [ -d "$DRV" ] || { echo "run.sh: base/ or driver/ missing next to run.sh" >&2; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/check_docs_suite.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT
WORK=$TMP/work
mkdir -p "$WORK"
NODRV=$TMP/no-such-driver-dir
N=0; RED=0; GREEN=0
COVERED=" "

mk() { rm -rf "$WORK/$1"; cp -R "$BASE" "$WORK/$1"; git -C "$WORK/$1" init -q; }
run() { OUT=$(DOCS_ROOT="$WORK/$1" DOCS_DRIVER_DIR="$2" bash "$CHK" 2>&1); RC=$?; }

# pair ID REDFN GREENFN NEEDLE [REDRC [DRIVER_RED [DRIVER_GREEN]]]
pair() {
  local id=$1 redfn=$2 greenfn=$3 needle=$4 redrc=${5:-1} drvred=${6:-$DRV} drvgreen=${7:-$DRV} r g
  N=$((N + 1))
  COVERED="$COVERED${id%%-*} "
  mk "$id-red"; $redfn "$WORK/$id-red"; run "$id-red" "$drvred"; local rrc=$RC rout=$OUT
  mk "$id-green"; $greenfn "$WORK/$id-green"; run "$id-green" "$drvgreen"; local grc=$RC gout=$OUT
  r=FAIL; g=FAIL
  if [ "$rrc" -eq "$redrc" ] && printf '%s\n' "$rout" | grep -qF -- "$needle"; then r=red-ok; RED=$((RED + 1)); fi
  if [ "$grc" -eq 0 ]; then g=green-ok; GREEN=$((GREEN + 1)); fi
  printf '%-22s red: rc=%s %-7s green: rc=%s %-8s needle: %s\n' "$id" "$rrc" "$r" "$grc" "$g" "$needle"
  [ "$r" = FAIL ] && { echo "---- red output ($id)"; printf '%s\n' "$rout"; }
  [ "$g" = FAIL ] && { echo "---- green output ($id)"; printf '%s\n' "$gout"; }
}

none() { :; }
sedit() { sed -e "$1" "$2" > "$2.new" && mv "$2.new" "$2"; }

# 1 ORPHAN file in README
r_file() { sedit 's/Generator\/pymorph\.py -o/Generator\/pymorph_missing.py -o/' "$1/README.md"; }
# 2 ORPHAN method name in README
r_pub() { sedit 's/isAnimationComplete()/isAnimationCompletee()/' "$1/README.md"; }
# 3 ORPHAN file named in a PUB '' doc comment
r_src() { sedit 's/isp_hub75_morph7seg\.spin2/ghost_helper.spin2/' "$1/Src/isp_hub75_morphSegment.spin2"; }
# 4 ORPHAN local link target
r_link() { sedit 's/(LICENSE)/(LICENSE-missing)/' "$1/README.md"; }
# 5 DUPLICATE fenced block
r_dupblk() { sedit 's/echo unique-block-one/.\/Generator\/pymorph.py -o animationTable.out/' "$1/.github/release/README-package.md"; }
# 6 DUPLICATE table row (green twin: same row, different description)
r_duprow() { printf '\n| Name | Info |\n| --- | --- |\n| Src/ | the fixture source directory is described here |\n| Generator/ | gen text for the package |\n' >> "$1/.github/release/README-package.md"; }
g_duprow() { printf '\n| Name | Info |\n| --- | --- |\n| Src/ | a differently worded description lives only in this file |\n| Generator/ | gen text for the package |\n' >> "$1/.github/release/README-package.md"; }
# 7-9 COUNT
r_cfiles() { sedit 's/five `.spin2` files/four `.spin2` files/' "$1/README.md"; }
r_csnake() { sedit 's/4 snake types/5 snake types/' "$1/README.md"; }
r_cseg() { sedit 's/7 morphing segments/8 morphing segments/' "$1/README.md"; }
# 10 OMITTED tracked file missing from the file table
r_omit() { sedit '/morphExtra/d' "$1/README.md"; }
# 11 driver-name exemption (green) and control (red)
g_drv() { printf 'Uses isp_hub75_screenUtils.spin2 from the driver.\n' >> "$1/README.md"; }
r_bogus() { printf 'Uses isp_hub75_bogus.spin2 from the driver.\n' >> "$1/README.md"; }
# 12 -o output-name exemption control
r_other() { printf 'See other.out for details.\n' >> "$1/README.md"; }
# 14 OMITTED top-level directory (green twin lists it); 15 ORPHAN directory named in the table
r_dir() { mkdir "$1/tools"; printf 'echo hi\n' > "$1/tools/x.sh"; }
g_dir() {
  r_dir "$1"
  sed -e '/^| Src\/ |/a\
| tools/ | the tools directory |
' "$1/README.md" > "$1/README.md.new" && mv "$1/README.md.new" "$1/README.md"
}
r_ghostdir() {
  sed -e '/^| Src\/ |/a\
| Ghost/ | not in the tree |
' "$1/README.md" > "$1/README.md.new" && mv "$1/README.md.new" "$1/README.md"
}
# 13 driver directory absent: an unclassifiable name is reported, never silently passed

echo "== base twin, no mutation =="
mk base; run base "$DRV"; echo "base rc=$RC (want 0)"; BASERC=$RC
[ "$RC" -ne 0 ] && printf '%s\n' "$OUT"
echo "== pairs =="
pair ORPHAN-file r_file none "README.md:3: file 'Generator/pymorph_missing.py' is named here"
pair ORPHAN-method r_pub none "README.md:17: method 'isAnimationCompletee()'"
pair ORPHAN-src-comment r_src none "Src/isp_hub75_morphSegment.spin2:3: file 'ghost_helper.spin2'"
pair ORPHAN-link r_link none "README.md:23: link target 'LICENSE-missing'"
pair DUPLICATE-block r_dupblk none "README.md:20: fenced block (1 line(s)) also kept in .github/release/README-package.md:6"
pair DUPLICATE-row r_duprow g_duprow "README.md:27: table row also kept in .github/release/README-package.md"
pair COUNT-files r_cfiles none "README.md:5: says 'four \`.spin2\` files' but the number of tracked Src/(isp|demo)_hub75_morph*.spin2 files is 5"
pair COUNT-snake r_csnake none "README.md:15: says '5 snake' but the snake CMD_ count in isp_hub75_morphSegment.spin2 is 4"
pair COUNT-segments r_cseg none "README.md:15: says '8 morphing segments' but the SEG_ count in isp_hub75_morphSegment.spin2 is 7"
pair OMITTED-file r_omit none "README.md:7: file table lists 4 file(s) of Src/ but omits tracked file Src/demo_hub75_morphExtra.spin2"
pair DRIVER-exempt r_bogus g_drv "README.md:29: file 'isp_hub75_bogus.spin2' is named here"
pair OUTPUT-name-exempt r_other none "README.md:29: file 'other.out' is named here"
pair UNCLASSIFIED-no-driver g_drv none "README.md:29: cannot classify 'isp_hub75_screenUtils.spin2'" 2 "$NODRV" "$NODRV"
pair OMITTED-dir r_dir g_dir "README.md:25: directory table omits top-level directory tools/"
pair ORPHAN-dir r_ghostdir none "README.md:25: directory table names Ghost/ which does not exist in the tree"

# 16 driver directory choice: the checker is copied into a scratch root whose REF-NO-COMMIT holds
# two driver dirs (red: exit 2 with the message) or one driver dir (green: normal run, exit 0)
ID=D-driver-dir
N=$((N + 1))
NEEDLE="could not run: more than one driver directory under REF-NO-COMMIT:"
DR=$WORK/$ID-red-root
mkdir -p "$DR/tools" "$DR/REF-NO-COMMIT/p2-obex-driver-v4.0.0" "$DR/REF-NO-COMMIT/p2-obex-driver-v4.1.0"
cp "$CHK" "$DR/tools/check_docs.sh"
mk "$ID-red"; OUT=$(DOCS_ROOT="$WORK/$ID-red" bash "$DR/tools/check_docs.sh" 2>&1); RC=$?
drrc=$RC; drout=$OUT
DG=$WORK/$ID-green-root
mkdir -p "$DG/tools" "$DG/REF-NO-COMMIT"
cp "$CHK" "$DG/tools/check_docs.sh"; cp -R "$DRV" "$DG/REF-NO-COMMIT/p2-obex-driver-v4.0.0"
mk "$ID-green"; OUT=$(DOCS_ROOT="$WORK/$ID-green" bash "$DG/tools/check_docs.sh" 2>&1); RC=$?
dgrc=$RC; dgout=$OUT
r=FAIL; g=FAIL
if [ "$drrc" -eq 2 ] && printf '%s\n' "$drout" | grep -qF -- "$NEEDLE"; then r=red-ok; RED=$((RED + 1)); fi
if [ "$dgrc" -eq 0 ]; then g=green-ok; GREEN=$((GREEN + 1)); fi
printf '%-22s red: rc=%s %-7s green: rc=%s %-8s needle: %s\n' "$ID" "$drrc" "$r" "$dgrc" "$g" "$NEEDLE"
[ "$r" = FAIL ] && { echo "---- red output ($ID)"; printf '%s\n' "$drout"; }
[ "$g" = FAIL ] && { echo "---- green output ($ID)"; printf '%s\n' "$dgout"; }

# coverage derived from the checker: every detection type it reports needs at least one pair
UNCOVERED=""
TYPES=$(sed -n 's/^for ty in \(.*\); do$/\1/p' "$CHK")
for ty in $TYPES; do
  case "$COVERED" in *" $ty "*) ;; *) UNCOVERED="$UNCOVERED $ty" ;; esac
done
if [ -z "$TYPES" ]; then UNCOVERED=" (no 'for ty in ...' detection-type line found in the checker)"; fi

echo "== result =="
echo "$N detections, $RED red, $GREEN green (base twin rc=$BASERC)"
[ -n "$UNCOVERED" ] && echo "UNCOVERED detection type(s) of the checker:$UNCOVERED"
[ "$RED" -eq "$N" ] && [ "$GREEN" -eq "$N" ] && [ "$BASERC" -eq 0 ] && [ -z "$UNCOVERED" ] && exit 0
exit 1
