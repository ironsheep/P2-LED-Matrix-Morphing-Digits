#!/usr/bin/env bash
# check_docs.sh -- documentation-drift instrument (DOC_AUDIT_COMMAND).
#
# ADVISORY. This script reports drift between the documents and the tree; it is raw material
# for the plan's Documentation Blast Radius, NOT a build gate. Never wire it into a build or CI
# as a hard gate. Callers read its exit status, not its log.
#
# Specified by ~/.claude/skills/sprint-plan/references/doc-audit-instruments.md (Part 1 detections,
# Part 2 derivation). The detections:
#   ORPHAN       a document names something the tree does not have: a file (or a local link
#                target) that is neither tracked nor a driver file, or a PUB/PRI method name
#                (name followed by "(") that no source file defines
#   DUPLICATE    the same quoted material kept in more than one document: an identical fenced
#                block, or an identical table row, in two files (fix: one canonical copy, the
#                others link to it)
#   COUNT        a number asserted in prose, recomputed from its source: "N .spin2 files" against
#                the tracked Src/(isp|demo)_hub75_morph*.spin2 files; "N snake" / "N column" against
#                the CMD_ enum, "N segments" against the SEG_ enum, both in isp_hub75_morphSegment.spin2
#   OMITTED      a tracked file missing from a README file table (a table whose first column names
#                files): checked against the tracked files of the directory the table mostly lists
#   UNCLASSIFIED a name that is not in the tree and could not be classified as a driver name
#                because the driver directory is absent (never passed or failed silently)
# LIMITS       method names are checked only when camelCase, or written name() in a .md file.
#              A one-word name with arguments, such as start(x), and a one-word name in a source
#              comment are NOT checked. The report header prints this limit on every run.
#
# Scope is derived, never listed: every *.md file git knows of (tracked, plus untracked-not-ignored),
# minus the named working areas below, plus the '' doc comments of Src/isp_hub75_morph*.spin2.
# So .github/release/README-package.md is covered the moment it exists. ChangeLog.md is read for
# ORPHAN and DUPLICATE but not COUNT (a changelog counts things in the past).
# Working areas excluded (intent documents are never evidence): Docs/plans/ Docs/analysis/
# Docs/SPECIFICATION.md tasks/ .claude/ .todo-mcp/ REF-NO-COMMIT/ CLAUDE.md.
#
# Driver file and method names are derived from the driver directory (default: the one
# REF-NO-COMMIT/p2-obex-driver-* directory; more than one is a could-not-run error, exit 2); a
# README may name driver files and methods, that is not drift. File names given as the argument
# of "-o" are output files the user creates.
#
# Usage:   bash tools/check_docs.sh
# Environment (used to point the real script at scratch fixtures):
#   DOCS_ROOT        tree to audit (default: this repo); must be a git work tree
#   DOCS_DRIVER_DIR  driver directory (default: the only REF-NO-COMMIT/p2-obex-driver-* directory)
# Exit: 0 = no findings; 1 = findings; 2 = could not run, or nothing found but some names
#       could not be classified (driver directory absent).
# Only bash/awk/sed/sort/git are used.

set -u
export LC_ALL=C

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SELF_ROOT=$(cd "$SELF_DIR/.." && pwd)
ROOT=${DOCS_ROOT:-$SELF_ROOT}
TAB=$(printf '\t')

die() { printf 'check_docs.sh: %s\n' "$1" >&2; exit 2; }
# PUB/PRI method names (lowercased), one per line, for the .spin2 files given as arguments
pubNames() { awk '/^(PUB|PRI)[ \t]+[A-Za-z_]/ { s = $0; sub(/^(PUB|PRI)[ \t]+/, "", s); match(s, /^[A-Za-z_][A-Za-z0-9_]*/); print tolower(substr(s, 1, RLENGTH)) }' "$@"; }

cd "$ROOT" || die "cannot cd to $ROOT"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/check_docs.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT

git ls-files --cached --others --exclude-standard | sort -u > "$WORK/tracked" 2>/dev/null
[ -s "$WORK/tracked" ] || die "git ls-files lists nothing in $ROOT (not a git work tree?)"

# ---------------------------------------------------------------- driver directory
DRIVER=${DOCS_DRIVER_DIR:-}
if [ -z "$DRIVER" ]; then
  DRVDIRS=""; NDRV=0
  for d in "$SELF_ROOT"/REF-NO-COMMIT/p2-obex-driver-*; do
    if [ -d "$d" ]; then DRVDIRS="${DRVDIRS:+$DRVDIRS, }$d"; NDRV=$((NDRV + 1)); DRIVER=$d; fi
  done
  [ "$NDRV" -gt 1 ] && die "could not run: more than one driver directory under REF-NO-COMMIT: $DRVDIRS"
fi
DRIVER_OK=0
: > "$WORK/drvfiles"; : > "$WORK/drvpubs"
if [ -n "$DRIVER" ] && [ -d "$DRIVER" ]; then
  for f in "$DRIVER"/*; do [ -f "$f" ] && basename "$f" >> "$WORK/drvfiles"; done
  set -- "$DRIVER"/*.spin2
  if [ -f "$1" ]; then
    DRIVER_OK=1
    pubNames "$@" > "$WORK/drvpubs"
  fi
fi

# ---------------------------------------------------------------- our methods and counts
SPIN_FILES=()
while IFS= read -r f; do
  case "$f" in *.spin2) SPIN_FILES+=("$f") ;; esac
done < "$WORK/tracked"
: > "$WORK/pubs"
[ "${#SPIN_FILES[@]}" -gt 0 ] && pubNames "${SPIN_FILES[@]}" >> "$WORK/pubs"
cat "$WORK/drvpubs" >> "$WORK/pubs"

NDIST=$(awk '/^Src\/(isp|demo)_hub75_morph[^\/]*\.spin2$/ { n++ } END { print n + 0 }' "$WORK/tracked")
COUNTS="-1 -1 -1"
if [ -f Src/isp_hub75_morphSegment.spin2 ]; then
  COUNTS=$(awk '
    /^#/ {
      s = $0
      while (match(s, /(SEG|CMD)_[A-Z_]+/)) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        if (t ~ /^SEG_/ && t != "SEG_UNKNOWN") seg[t] = 1
        else if (t ~ /^CMD_COL_/) col[t] = 1
        else if (t ~ /^CMD_/ && t != "CMD_UNKNOWN" && t != "CMD_IMMEDIATE" && t !~ /^CMD_TURN_/) snake[t] = 1
      }
    }
    END { ns = 0; nk = 0; nc = 0; for (k in seg) ns++; for (k in snake) nk++; for (k in col) nc++; print ns, nk, nc }' Src/isp_hub75_morphSegment.spin2)
fi
set -- $COUNTS
NSEG=$1; NSNAKE=$2; NCOL=$3

# ---------------------------------------------------------------- document set (derived)
: > "$WORK/docs"
while IFS= read -r f; do
  case "$f" in
    Docs/plans/*|Docs/analysis/*|Docs/SPECIFICATION.md|tasks/*|.claude/*|.todo-mcp/*|REF-NO-COMMIT/*|CLAUDE.md) continue ;;
    *.md) printf '%s\n' "$f" >> "$WORK/docs" ;;
    Src/isp_hub75_morph*.spin2) printf '%s\n' "$f" >> "$WORK/docs" ;;
  esac
done < "$WORK/tracked"
DOCARR=()
while IFS= read -r f; do DOCARR+=("$f"); done < "$WORK/docs"
NDOCS=${#DOCARR[@]}
[ "$NDOCS" -gt 0 ] || die "no documents found in $ROOT"

# ---------------------------------------------------------------- awk program
read -r -d '' AWKPROG <<'AWKEOF'
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function dirOf(p) { if (p !~ /\//) return "."; sub(/\/[^\/]*$/, "", p); return p }
function baseOf(p) { sub(/^.*\//, "", p); return p }
function numval(w) { if (w ~ /^[0-9]+$/) return w + 0; return (w in NW) ? NW[w] : -1 }
function report(type, ln, msg,   key) {
  key = type SUBSEP CURDOC SUBSEP ln SUBSEP msg
  if (key in seen) return
  seen[key] = 1
  printf "%s\t%s\t%d\t%s\n", type, CURDOC, ln, msg
}
function resolve(name, ddir,   k, c) {
  if (name in TRK) return name
  if (ddir != "." && (ddir "/" name) in TRK) return ddir "/" name
  if (index(name, "/") > 0) {
    c = "/" name
    for (k = 1; k <= nTrk; k++)
      if (length(TL[k]) > length(c) && substr(TL[k], length(TL[k]) - length(c) + 1) == c) return TL[k]
    return ""
  }
  return (name in BM) ? BM[name] : ""
}
function dupcheck(key, ln, what,   a) {
  if (key in DFIRST) {
    split(DFIRST[key], a, "\t")
    if (a[1] != CURDOC) report("DUPLICATE", ln, what " also kept in " a[1] ":" a[2])
  } else DFIRST[key] = CURDOC "\t" ln
}
function norm(s) { s = trim(s); gsub(/[ \t]+/, " ", s); return s }

function checkName(nm, i, ddir,   key, b) {
  key = nm; sub(/^(\.\/)+/, "", key)
  if (resolve(key, ddir) != "") return
  b = baseOf(key)
  if ((key in OUTN) || (b in OUTN)) return
  if (b in DRV) return
  if (!DRIVER_OK && (b ~ /\.spin2$/ || b ~ /^isp_hub75_/)) {
    report("UNCLASSIFIED", i, "cannot classify '" nm "': not in the tree and the driver directory is absent")
    return
  }
  report("ORPHAN", i, "file '" nm "' is named here but is not a tracked file or a driver file")
}

function claimScan(t, re, actual, what, ln, label,   rest, s, p, v) {
  rest = t
  while (match(rest, re)) {
    s = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
    sub(/^[^a-z0-9]+/, "", s); split(s, p, /[ ]+/); v = numval(p[1])
    if (v < 0) continue
    if (actual < 0) { report("UNCLASSIFIED", ln, "count claim '" s "' cannot be checked: " label " source is missing"); continue }
    if (v != actual) report("COUNT", ln, "says '" s "' but " what " is " actual)
  }
}

function flushTable(   k, d, best, bestN, p, c, cnt, found) {
  if (tDN > 0) {
    split("", topd)
    for (k = 1; k <= nTrk; k++) if (index(TL[k], "/") > 0) { d = TL[k]; sub(/\/.*$/, "", d); if (d !~ /^\./) topd[d] = 1 }
    for (d in topd) if (!(d in tDir)) report("OMITTED", tStart, "directory table omits top-level directory " d "/")
    for (d in tDir) if (!(d in topd)) {
      found = 0
      for (k = 1; k <= nTrk; k++) if (index(TL[k], d "/") == 1) { found = 1; break }
      if (!found) report("ORPHAN", tStart, "directory table names " d "/ which does not exist in the tree")
    }
  }
  split("", tDir); tDN = 0
  if (tN == 0) { tStart = 0; return }
  split("", cnt)
  for (p in tIn) { d = dirOf(p); cnt[d]++ }
  best = ""; bestN = 0
  for (d in cnt) if (cnt[d] > bestN || (cnt[d] == bestN && d < best)) { best = d; bestN = cnt[d] }
  if (bestN > 0) {
    for (k = 1; k <= nTrk; k++) {
      if (dirOf(TL[k]) == best && !(TL[k] in tIn))
        report("OMITTED", tStart, "file table lists " bestN " file(s) of " best "/ but omits tracked file " TL[k])
    }
  }
  split("", tIn); tN = 0; tStart = 0
}

function flush(   i, t, tl, raw, kind, ddir, fence, rest, nm, nxt, s, name, c, e, n, ff, cell, tgt, k, q, found, bkey, bn, bstart, rowkey, inTbl) {
  if (nL == 0) return
  kind = (CURDOC ~ /\.spin2$/) ? "src" : "md"
  ddir = dirOf(CURDOC)
  fence = 0
  split("", OUTN)
  for (i = 1; i <= nL; i++) {
    raw = RAW[i]; MK[i] = 0
    if (kind == "md") {
      if (raw ~ /^[ \t]*(```|~~~)/) { MK[i] = 1; fence = !fence }
      F[i] = fence
      t = raw
    } else {
      F[i] = 0
      if (index(raw, "''") > 0) { t = substr(raw, index(raw, "''") + 2) } else t = ""
    }
    gsub(/\\/, "", t)
    gsub(/https?:\/\/[^] )>]*/, "", t)
    T[i] = t
    if (match(t, /(^|[ \t])-o[ \t]+[^ \t]+/)) {
      s = substr(t, RSTART, RLENGTH); n = split(s, ff, /[ \t]+/); name = ff[n]
      gsub(/[`"']/, "", name); OUTN[name] = 1
    }
  }
  bn = 0; fence = 0; bkey = ""; inTbl = 0; tN = 0; tStart = 0; split("", tIn)
  for (i = 1; i <= nL; i++) {
    t = T[i]
    # ---- DUPLICATE: fenced blocks (md)
    if (kind == "md") {
      if (MK[i]) {
        if (F[i]) { bn = 0; bkey = ""; bstart = i + 1 }
        else if (bn > 0) { dupcheck("B" bkey, bstart, "fenced block (" bn " line(s))") }
      } else if (F[i]) {
        e = norm(RAW[i]); if (e != "") { bkey = bkey e "\n"; bn++ }
      }
    }
    # ---- tables (md, outside fences)
    if (kind == "md" && !F[i] && !MK[i] && trim(RAW[i]) ~ /^\|/) {
      e = trim(RAW[i])
      if (e !~ /^\|[ :|-]+\|?$/) {
        rowkey = tolower(norm(T[i]))
        if (length(rowkey) >= 24) dupcheck("R" rowkey, i, "table row")
        if (tStart == 0) tStart = i
        cell = e; sub(/^\|/, "", cell); c = index(cell, "|"); if (c > 0) cell = substr(cell, 1, c - 1)
        gsub(/[`* \t]/, "", cell); gsub(/\\/, "", cell)
        if (cell ~ /^[A-Za-z0-9_.-]+\/$/) { sub(/\/$/, "", cell); tDir[cell] = 1; tDN++ }
        else if (cell ~ /^[A-Za-z0-9_.\/-]+\.[A-Za-z0-9]+$/) {
          sub(/^(\.\/)+/, "", cell)
          nm = resolve(cell, ddir)
          if (nm != "") { tIn[nm] = 1; tN++ }
        }
      }
      inTbl = 1
    } else if (inTbl) { flushTable(); inTbl = 0 }
    if (kind == "md" && MK[i]) continue
    # ---- ORPHAN: markdown link targets without a file extension
    rest = t
    while (match(rest, /\]\([^)]*\)/)) {
      tgt = substr(rest, RSTART + 2, RLENGTH - 3); rest = substr(rest, RSTART + RLENGTH)
      sub(/[ \t].*$/, "", tgt)
      if (tgt == "" || tgt ~ /^#/ || tgt ~ /^[A-Za-z][A-Za-z0-9+.-]*:/) continue
      sub(/#.*$/, "", tgt); sub(/^(\.\/)+/, "", tgt); sub(/\/$/, "", tgt)
      if (tgt == "" || tgt ~ /\.(spin2|py|md|sh|out|txt|yml|png|bin|zip)$/) continue
      if (resolve(tgt, ddir) != "") continue
      found = 0
      for (k = 1; k <= nTrk; k++) if (index(TL[k], tgt "/") == 1) { found = 1; break }
      if (!found) report("ORPHAN", i, "link target '" tgt "' does not exist in the tree")
    }
    # ---- ORPHAN: file names
    rest = t
    while (match(rest, /[A-Za-z0-9_][A-Za-z0-9_.\/-]*\.(spin2|py|md|sh|out|txt|yml|png|bin|zip)/)) {
      nm = substr(rest, RSTART, RLENGTH); nxt = substr(rest, RSTART + RLENGTH, 1)
      rest = substr(rest, RSTART + RLENGTH)
      if (nxt ~ /[A-Za-z0-9_]/) continue
      checkName(nm, i, ddir)
    }
    # ---- ORPHAN: method names
    rest = t
    while (match(rest, /[A-Za-z_][A-Za-z0-9_]*\(/)) {
      name = substr(rest, RSTART, RLENGTH - 1); c = substr(rest, RSTART + RLENGTH, 1)
      rest = substr(rest, RSTART + RLENGTH)
      if (!((kind == "md" && c == ")") || name ~ /[a-z0-9_][A-Z]/)) continue
      if (tolower(name) in PUBSET) continue
      if (!DRIVER_OK) report("UNCLASSIFIED", i, "cannot classify method '" name "()': not defined here and the driver directory is absent")
      else report("ORPHAN", i, "method '" name "()' is named here but no source file defines a PUB or PRI of that name")
    }
    # ---- COUNT (md except the changelog)
    if (kind == "md" && CURDOC != "ChangeLog.md") {
      tl = tolower(t)
      for (q = 1; q <= nClaim; q++) claimScan(tl, CL_RE[q], CL_ACT[q], CL_WHAT[q], i, CL_LABEL[q])
    }
  }
  if (inTbl) flushTable()
  nL = 0
}

BEGIN {
  FS = "\n"
  while ((getline line < TRACKED) > 0) { TRK[line] = 1; TL[++nTrk] = line; if (!(baseOf(line) in BM)) BM[baseOf(line)] = line }
  while ((getline line < DRVFILES) > 0) DRV[line] = 1
  while ((getline line < PUBS) > 0) PUBSET[line] = 1
  split("zero one two three four five six seven eight nine ten eleven twelve", w, " ")
  for (k = 1; k <= 13; k++) NW[w[k]] = k - 1
  NUMRE = "(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+)"
  # COUNT claims: noun regex, the tree's actual value, what it is, and the source named in "cannot be checked"
  nClaim = 4
  CL_RE[1] = "(^|[^a-z0-9_.])" NUMRE "[ ]+(`?[.]spin2`?[ ]+|spin2[ ]+)?files"
  CL_ACT[1] = NDIST; CL_WHAT[1] = "the number of tracked Src/(isp|demo)_hub75_morph*.spin2 files"; CL_LABEL[1] = "tracked file list"
  CL_RE[2] = "(^|[^a-z0-9_.])" NUMRE "[ ]+snake"
  CL_ACT[2] = NSNAKE; CL_WHAT[2] = "the snake CMD_ count in isp_hub75_morphSegment.spin2"; CL_LABEL[2] = "isp_hub75_morphSegment.spin2"
  CL_RE[3] = "(^|[^a-z0-9_.])" NUMRE "[ ]+column"
  CL_ACT[3] = NCOL; CL_WHAT[3] = "the column CMD_COL_ count in isp_hub75_morphSegment.spin2"; CL_LABEL[3] = "isp_hub75_morphSegment.spin2"
  CL_RE[4] = "(^|[^a-z0-9_.])" NUMRE "[ ]+(morphing[ ]+)?segments"
  CL_ACT[4] = NSEG; CL_WHAT[4] = "the SEG_ count in isp_hub75_morphSegment.spin2"; CL_LABEL[4] = "isp_hub75_morphSegment.spin2"
}
FNR == 1 { flush(); CURDOC = FILENAME }
{ RAW[++nL] = $0 }
END { flush() }
AWKEOF

awk -v TRACKED="$WORK/tracked" -v DRVFILES="$WORK/drvfiles" -v PUBS="$WORK/pubs" \
    -v DRIVER_OK="$DRIVER_OK" -v NDIST="$NDIST" -v NSEG="$NSEG" -v NSNAKE="$NSNAKE" -v NCOL="$NCOL" \
    "$AWKPROG" "${DOCARR[@]}" > "$WORK/found" 2>"$WORK/awk.err" \
  || { cat "$WORK/awk.err" >&2; die "internal awk failure"; }
[ -s "$WORK/awk.err" ] && { cat "$WORK/awk.err" >&2; die "internal awk error"; }
sort -s -t "$TAB" -k2,2 -k3,3n "$WORK/found" > "$WORK/found.s"

# ---------------------------------------------------------------- report
echo "Documentation-drift check (ADVISORY: not a build gate) -- $NDOCS document(s)"
sed 's/^/  /' "$WORK/docs"
if [ "$DRIVER_OK" -eq 1 ]; then echo "driver names from: $DRIVER"; else echo "driver directory: ABSENT or has no .spin2 (driver names cannot be classified)"; fi
echo "counts derived: tracked Src files=$NDIST  snake=$NSNAKE  column=$NCOL  segments=$NSEG"
echo "limits: method names checked only when camelCase, or written name() in a .md file; one-word names with arguments such as start(x), and one-word names in source comments, are not checked"
echo
TOTAL=0; UNCL=0
for ty in ORPHAN DUPLICATE COUNT OMITTED UNCLASSIFIED; do
  cnt=$(awk -F"$TAB" -v t="$ty" '$1 == t' "$WORK/found.s" | wc -l | tr -d ' ')
  echo "== $ty: $cnt =="
  awk -F"$TAB" -v t="$ty" '$1 == t { printf "  %s:%s: %s\n", $2, $3, $4 }' "$WORK/found.s"
  if [ "$ty" = UNCLASSIFIED ]; then UNCL=$cnt; else TOTAL=$((TOTAL + cnt)); fi
done
echo
if [ "$TOTAL" -gt 0 ]; then
  echo "RESULT: $TOTAL finding(s), $UNCL unclassified (advisory)"
  exit 1
fi
if [ "$UNCL" -gt 0 ]; then
  echo "RESULT: 0 findings but $UNCL name(s) could not be classified (advisory)"
  exit 2
fi
echo "RESULT: 0 findings (advisory)"
exit 0
