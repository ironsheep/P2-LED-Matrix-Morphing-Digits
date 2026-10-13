#!/usr/bin/env bash
# run.sh -- falsification control for tools/check_style.sh (STYLE_GATE_COMMAND).
#
# Proves that every rule of the style checker still fires, at the right place, and stays quiet on
# clean code. Per case it builds a violating variant (v) and a clean twin (c) in a temp directory
# (tracked base/ files first, the case's files laid over them), runs the real checker on every
# .spin2 file of that directory, and requires:
#   red    exit 1, and the set of findings (rule, file, line) equals the case's expectation in cases.txt
#   green  exit 0 and no findings
# The rule list is read from the checker's own ROSTER, never restated here: every rule id in the
# ROSTER must be asserted red by at least one case, and cases.txt may not name a rule the ROSTER
# lacks. A rule that stops firing therefore fails the cases that assert it, naming the rule.
#
# Also run, from the same files:
#   onefile  a single-file run sees the constants of the project files it includes (rules 2.4, 6.2),
#            from the repo root and from Src/ (commit aadc23f), in a scratch repo root
#   scenario three-part report on a clean, a failing and a zero-file run; driver-named files in
#            Src/ are never listed or reported while a project-named twin is (positive control)
#
# Usage:   bash tools/tests/check_style/run.sh
#          bash tools/tests/check_style/run.sh --observe   authoring aid: print, in cases.txt form,
#                                                          every finding of each case's v/ variant
# Environment:
#   CHECKER   checker to run (default: tools/check_style.sh of this repo). Point it at a scratch
#             copy to prove the suite notices a broken rule.
# Output:  one line per failure, then "N rules, N red, N green" (rules asserted red / red cases that
#          behaved / green cases that behaved) and a scenarios line.
# Exit:    0 = everything behaved; 1 = any case, rule or scenario misbehaved; 2 = could not run.
#
# Layout:  base/        LICENSE and the three base fixture files (a clean object, its child, a test file)
#          cases/cNN/   v/ and c/ (the violating variant and its clean twin) hold the files that
#                       case changes (diff -r base/ cases/cNN/v shows the change); a case directory
#                       with .spin2 files directly in it is a green-only boundary case
#          cases.txt    the expectations (format at its head)
# These fixtures live under tools/tests/, never Src/, so neither the checker's default file list
# nor the release globs ever see them.

set -u
export LC_ALL=C

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
CHK=${CHECKER:-$REPO/tools/check_style.sh}
BASE=$HERE/base
CASES=$HERE/cases
LIST=$HERE/cases.txt
OBSERVE=0
[ "${1:-}" = "--observe" ] && OBSERVE=1

[ -f "$CHK" ] || { echo "run.sh: checker not found: $CHK" >&2; exit 2; }
[ -d "$BASE" ] && [ -d "$CASES" ] && [ -f "$LIST" ] || { echo "run.sh: base/, cases/ or cases.txt missing next to run.sh" >&2; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/check_style_suite.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT

FAILS=0
fail() { printf 'FAIL %s\n' "$1"; FAILS=$((FAILS + 1)); }

# ---- roster, read from the checker
ROSTER_IDS=$(sed -n "/^ROSTER='/,/'\$/p" "$CHK" | sed "s/^ROSTER='//" | awk -F'|' 'NF > 1 { print $1 }')
[ -n "$ROSTER_IDS" ] || { echo "run.sh: no ROSTER found in $CHK" >&2; exit 2; }
NRULES=$(printf '%s\n' "$ROSTER_IDS" | wc -l | tr -d ' ')

# ---- helpers
# build DEST [OVERLAY_DIR]: base files, then the case's files over them
build() {
  rm -rf "$1"; mkdir -p "$1"
  cp "$BASE"/*.spin2 "$BASE/LICENSE" "$1/"
  if [ -n "${2:-}" ]; then for f in "$2"/*.spin2; do [ -f "$f" ] && cp "$f" "$1/"; done; fi   # a case holds only the files it changes
}
# run_dir DIR: the checker on every .spin2 file in DIR, run from inside DIR; sets RC OUT
run_dir() {
  local files=() f
  for f in "$1"/*.spin2; do files+=("$(basename "$f")"); done
  OUT=$(cd "$1" && STYLE_LICENSE="$1/LICENSE" bash "$CHK" "${files[@]}" 2>&1); RC=$?
}
# findings TEXT: "rule file line" per finding (file reduced to its base name), sorted, unique
findings() {
  printf '%s\n' "$1" | awk '
    /^  (PASS|FAIL)  \[/ { r = $0; sub(/^  (PASS|FAIL)  \[/, "", r); sub(/\].*/, "", r); next }
    /^          [^ ]/ {
      s = $0; sub(/^ +/, "", s)
      if (match(s, /:[0-9]+: /)) {
        f = substr(s, 1, RSTART - 1); sub(/^.*\//, "", f)
        print r, f, substr(s, RSTART + 1, RLENGTH - 3)
      }
    }' | sort -u
}
one_line() { printf '%s' "$1" | tr '\n' ';'; }
has_three_parts() {
  printf '%s\n' "$1" | grep -q '^== PART 1: rules checked' &&
  printf '%s\n' "$1" | grep -q '^== PART 2: T2 rules NOT checked' &&
  printf '%s\n' "$1" | grep -q '^== PART 3: assigned-T1 rules NOT implemented' &&
  printf '%s\n' "$1" | grep -q '^RESULT: '
}
expected_for() { awk -v c="$1" '$1 == "red" && $2 == c { print $3, $4, $5 }' "$LIST" | sort -u; }

# ---- authoring aid
if [ "$OBSERVE" -eq 1 ]; then
  for d in $(ls "$CASES" | sed 's/^c//' | sort -n); do
    c=c$d
    if [ -d "$CASES/$c/v" ]; then
      build "$TMP/o" "$CASES/$c/v"; run_dir "$TMP/o"
      findings "$OUT" | while read -r r f l; do echo "red $c $r $f $l"; done
      build "$TMP/o" "$CASES/$c/c"; run_dir "$TMP/o"
      [ "$RC" -ne 0 ] && echo "# $c: clean twin rc=$RC: $(one_line "$(findings "$OUT")")"
    else
      build "$TMP/o" "$CASES/$c"; run_dir "$TMP/o"
      echo "green $c   # rc=$RC"
    fi
  done
  exit 0
fi

# ---- cases
CASE_IDS=$(awk '$1 == "red" || $1 == "green" || $1 == "onefile" { print $2 }' "$LIST" | sort -u)
for d in $(ls "$CASES"); do
  printf '%s\n' "$CASE_IDS" | grep -qxF -- "$d" || fail "case directory $d has no entry in cases.txt"
done

NRED=0; NGREEN=0; REDOK=0; GREENOK=0
COVERED=" "
for c in $(awk '$1 == "red" || $1 == "green" { print $2 }' "$LIST" | sort -u); do
  kind=$(awk -v c="$c" '$2 == c { print $1; exit }' "$LIST")
  if [ "$kind" = "red" ]; then
    NRED=$((NRED + 1)); NGREEN=$((NGREEN + 1))
    if [ ! -d "$CASES/$c/v" ] || [ ! -d "$CASES/$c/c" ]; then fail "case $c: v/ or c/ directory missing"; continue; fi
    want=$(expected_for "$c")
    build "$TMP/w" "$CASES/$c/v"; run_dir "$TMP/w"
    got=$(findings "$OUT")
    rules=$(printf '%s\n' "$want" | awk '{ print $1 }' | sort -u | tr '\n' ' ')
    if [ "$RC" -eq 1 ] && [ "$got" = "$want" ]; then
      REDOK=$((REDOK + 1))
      for r in $rules; do COVERED="$COVERED$r "; done
    else
      fail "case $c [rule ${rules% }]: violating variant rc=$RC; expected {$(one_line "$want")} observed {$(one_line "$got")}"
    fi
    build "$TMP/w" "$CASES/$c/c"; run_dir "$TMP/w"
    if [ "$RC" -eq 0 ] && [ -z "$(findings "$OUT")" ]; then GREENOK=$((GREENOK + 1))
    else fail "case $c [rule ${rules% }]: clean twin rc=$RC, findings {$(one_line "$(findings "$OUT")")}"; fi
  else
    NGREEN=$((NGREEN + 1))
    if [ ! -d "$CASES/$c" ]; then fail "case $c: directory missing"; continue; fi
    build "$TMP/w" "$CASES/$c"; run_dir "$TMP/w"
    if [ "$RC" -eq 0 ] && [ -z "$(findings "$OUT")" ]; then GREENOK=$((GREENOK + 1))
    else fail "boundary case $c: rc=$RC, findings {$(one_line "$(findings "$OUT")")} (must be clean)"; fi
  fi
done

# ---- coverage derived from the checker's ROSTER
RULES_RED=0
for r in $ROSTER_IDS; do
  case "$COVERED" in *" $r "*) RULES_RED=$((RULES_RED + 1)) ;; *) fail "rule $r: no red case in cases.txt asserts it (or its case failed)" ;; esac
done
for r in $(awk '$1 == "red" { print $3 }' "$LIST" | sort -u); do
  printf '%s\n' "$ROSTER_IDS" | grep -qxF -- "$r" || fail "cases.txt asserts rule $r, which the checker's ROSTER does not list"
done

# ---- one-file runs (rules 2.4 and 6.2): the scratch repo root has the checker at tools/ and the
# case files in Src/, so the checker derives the project files from git exactly as in the repo
mkroot() { # DEST: scratch repo root with the checker copy, LICENSE and an empty Src/
  rm -rf "$1"; mkdir -p "$1/tools" "$1/Src"
  cp "$CHK" "$1/tools/check_style.sh"; cp "$BASE/LICENSE" "$1/LICENSE"
  git -C "$1" init -q
}
NONE=0; NONEOK=0
for c in $(awk '$1 == "onefile" { print $2 }' "$LIST" | sort -u); do
  mkroot "$TMP/r"
  for side in v c; do
    rm -f "$TMP/r/Src/"*.spin2
    cp "$BASE"/*.spin2 "$TMP/r/Src/"; for f in "$CASES/$c/$side"/*.spin2; do [ -f "$f" ] && cp "$f" "$TMP/r/Src/"; done
    for line in $(awk -v c="$c" '$1 == "onefile" && $2 == c { print $3 "@" $4 "@" $5 }' "$LIST" | sort -u); do
      rule=${line%%@*}; rest=${line#*@}; file=${rest%%@*}
      want=$(awk -v c="$c" -v r="$rule" -v f="$file" '$1 == "onefile" && $2 == c && $3 == r && $4 == f { print r, f, $5 }' "$LIST" | sort -u)
      for where in root src; do
        NONE=$((NONE + 1))
        if [ "$where" = root ]; then OUT=$(cd "$TMP/r" && bash tools/check_style.sh "Src/$file" 2>&1); RC=$?
        else OUT=$(cd "$TMP/r/Src" && bash ../tools/check_style.sh "$file" 2>&1); RC=$?; fi
        got=$(findings "$OUT")
        if [ "$side" = v ]; then
          if [ "$RC" -eq 1 ] && printf '%s\n' "$got" | grep -qxF -- "$want"; then NONEOK=$((NONEOK + 1))
          else fail "onefile $c [rule $rule] from $where: single-file run of $file rc=$RC; expected {$want} observed {$(one_line "$got")}"; fi
        else
          if [ "$RC" -eq 0 ]; then NONEOK=$((NONEOK + 1))
          else fail "onefile $c [rule $rule] from $where: clean twin $file rc=$RC, findings {$(one_line "$got")}"; fi
        fi
      done
    done
  done
done

# ---- scenarios
NSC=0; NSCOK=0
sc() { NSC=$((NSC + 1)); if [ "$1" = 1 ]; then NSCOK=$((NSCOK + 1)); else fail "scenario: $2"; fi; }

# three-part report: clean, failing, zero-file
build "$TMP/s" ""; rm -f "$TMP/s/test_hub75_morphFix.spin2"; run_dir "$TMP/s"
sc "$([ "$RC" = 0 ] && has_three_parts "$OUT" && echo 1 || echo 0)" "clean run: rc=$RC, want 0 with three parts and a RESULT line"
VCASE=$(awk '$1 == "red" { print $2; exit }' "$LIST")
build "$TMP/s" "$CASES/$VCASE/v"; run_dir "$TMP/s"
sc "$([ "$RC" = 1 ] && has_three_parts "$OUT" && echo 1 || echo 0)" "failing run ($VCASE/v): rc=$RC, want 1 with three parts and a RESULT line"
mkroot "$TMP/e"
OUT=$(cd "$TMP/e" && bash tools/check_style.sh 2>&1); RC=$?
sc "$([ "$RC" = 2 ] && has_three_parts "$OUT" && printf '%s\n' "$OUT" | grep -q '^RESULT: NOT RUN' && echo 1 || echo 0)" "zero-file run: rc=$RC, want 2, three parts, RESULT: NOT RUN"

# driver-named files in Src/ are never listed or reported; the same file under our name is (control)
mkroot "$TMP/d"
cp "$BASE/isp_hub75_morphFix.spin2" "$BASE/isp_hub75_morphChild.spin2" "$TMP/d/Src/"
OUT=$(cd "$TMP/d" && bash tools/check_style.sh 2>&1); BASE_RESULT=$(printf '%s\n' "$OUT" | grep '^RESULT')
for n in isp_hub75_screenUtils isp_hub75_color hub75_driver_thing; do cp "$CASES/$VCASE/v/isp_hub75_morphFix.spin2" "$TMP/d/Src/$n.spin2"; done
OUT=$(cd "$TMP/d" && bash tools/check_style.sh 2>&1); RC=$?
sc "$(printf '%s\n' "$OUT" | grep -q 'screenUtils\|isp_hub75_color\|hub75_driver_thing' && echo 0 || echo 1)" "driver-named violating files must never be listed or reported"
sc "$([ "$(printf '%s\n' "$OUT" | grep '^RESULT')" = "$BASE_RESULT" ] && echo 1 || echo 0)" "driver-named files changed the RESULT line"
cp "$CASES/$VCASE/v/isp_hub75_morphFix.spin2" "$TMP/d/Src/isp_hub75_morphZzControl.spin2"
OUT=$(cd "$TMP/d" && bash tools/check_style.sh 2>&1); RC=$?
sc "$([ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q 'Src/isp_hub75_morphZzControl.spin2:' && echo 1 || echo 0)" "positive control: the same file under our name must be reported (rc=$RC)"

# ---- roll-up
echo "$RULES_RED rules, $REDOK red, $GREENOK green  (of $NRULES rules in the checker's ROSTER, $NRED red cases, $NGREEN green cases)"
echo "onefile runs: $NONEOK of $NONE; scenarios: $NSCOK of $NSC"
if [ "$FAILS" -eq 0 ] && [ "$RULES_RED" -eq "$NRULES" ] && [ "$REDOK" -eq "$NRED" ] && [ "$GREENOK" -eq "$NGREEN" ] &&
   [ "$NONEOK" -eq "$NONE" ] && [ "$NONE" -gt 0 ] && [ "$NSCOK" -eq "$NSC" ]; then
  exit 0
fi
echo "run.sh: $FAILS failure(s)"
exit 1
