#!/usr/bin/env bash
# check_style.sh -- Spin2 style gate for the morphing-digit files (STYLE_GATE_COMMAND).
#
# Enforces central:spin2-authoring-guide (~/.claude/skills-docs/guides/spin2-authoring-guide.md):
# every rule that guide tags T1, plus the detection half of every T1+T2 rule, plus the PNut
# portability rule (spec R-14.3; p2kb key p2kbSpin2PreprocessorOverview).
#
# Usage:
#   bash tools/check_style.sh              check the files git knows of under Src/ named
#                                          isp_hub75_morph*.spin2, demo_hub75_morph*.spin2,
#                                          test_hub75_morph*.spin2 (git ls-files, never a hand
#                                          list; driver files in Src/ never match)
#   bash tools/check_style.sh FILE...      check exactly these files (used to prove the checker
#                                          against fixtures)
#   bash tools/check_style.sh -s [FILE...] summary: per-rule PASS/FAIL counts without the
#                                          file:line findings (same findings, same exit code)
# Environment:
#   STYLE_LICENSE   path of the LICENSE file the 4.2.1 footer is compared with (default: repo LICENSE)
#
# Every run prints three parts: (1) the rules checked, each PASS or with its findings at
# file:line; (2) the T2 rules it does NOT check; (3) the assigned-T1 rules it has NOT implemented.
# Exit: 0 = no findings; 1 = findings; 2 = could not run (no files, missing LICENSE, bad file).
#
# Only awk/sed/sort/git are used. Findings are tab-separated "F rule file line message" inside
# the script; the report groups them per rule.

set -u
export LC_ALL=C

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SELF_DIR/.." && pwd)
TAB=$(printf '\t')

# ---------------------------------------------------------------- rule roster
# id|tier|title|approximation note (empty = exact as the rule is worded)
ROSTER='1.1|T1|ASCII only; non-ASCII outside U+2500-U+259F is a FAIL everywhere|
1.3|T1|Identifier does not collide with a built-in / PASM2 name|APPROX: checks the guide hazard table only (cogId bool string send wc step neg skip skipf pa pb ptra ptrb dira) against params, returns, locals, method names, OBJ aliases
1.4|T1|No method overloading (method names unique, case-insensitive)|
1.5|T1|Param/return/local does not shadow a PUB or PRI method name|
1.8|T1|No empty string literal @""|
1.9|T1|OBJ override name not also defined by a CON in the same file|
2.1|T1|No single-letter variable names (params, returns, locals, VAR names, DAT labels)|
2.1.4|T1+T2|Detect letter-plus-digit names (h1, h2); same-purpose-vs-role judgement is T2|APPROX: detection half only
2.4|T1|Local CON does not copy a constant of an OBJ object|APPROX: only objects whose file is also being checked are read (driver objects are never read)
2.5|T1+T2|Same @param name carries an identical description everywhere|APPROX: detection half only; verbatim compare after whitespace folding
3.1|T1|File layout order (version directive on line 1; first CON, OBJ, DAT, VAR in that order ahead of the first method)|APPROX: blocks first appearing after the first PUB/PRI are not order-checked (rule 3.4 allows them)
3.2|T1|All PUB methods before all PRI methods|
4.1|T1|Doc-comment rule: no ~~ outside file header and PUB doc block; {{ }} only in the license footer; @local never with ~~|APPROX: PUB doc block = ~~ lines before the first code line of the method
4.2|T1|File header: ~~ block with File/Purpose/Authors/E-mail/Started/Updated; File names this file|APPROX: dates are not validated
4.2.1|T1|License footer: last content, a {{ }} block, copyright matches LICENSE; inside a CON block (project convention, CLAUDE.md -- not the guide)|
4.5|T1|Block declaration comment is single-apostrophe, labelled, no directive|APPROX: strict reading, a { } comment on a CON/DAT/VAR/OBJ/PUB/PRI line is reported (the rule says MUST use the apostrophe)
4.6|T1+T2|Detect trailing { } comments on CON/VAR/DAT declarations (rule: apostrophe comments)|APPROX: detection half only
4.9|T1|No horizontal separator lines inside CON blocks|APPROX: a comment-only line of 5 or more of = - _ * # ~ (or box-drawing characters); the license footer is exempt
5.0|T1|No unused parameter, return variable or local|APPROX: unused = the name never appears as a token in the method body (comments/strings ignored); a name that is only written is not caught
5.1|T1|Every return variable is explicitly assigned|APPROX: assignment forms recognised by pattern (:=, op=, ++, --, ~, repeat name from, list targets)
5.2|T1|Single exit point: no return except as the last statement of a method|APPROX: abort is not counted
5.3|T1|No return inside a repeat loop|APPROX: loop extent taken from indentation
5.4|T1|PUB returning TRUE/FALSE is named is*/has*|APPROX: catches only a literal TRUE/FALSE assigned to a return variable or returned
5.4.1|T1|Booleans are TRUE/FALSE: no 1 assigned to, and no ==/<> 0/1 against, a bName or is*/has* return|APPROX: boolean identified by name prefix b[A-Z] or by being the return of an is*/has* PUB
5.7|T1+T2|Detect numeric literals in method bodies other than 0, -1, 4 (needs a named CON unless the meaning is obvious)|APPROX: detection half only; every hit needs the agent judgement
6.1|T1+T2|Detect raw numeric literals in utils.evaluate*() assertions (test_ files)|APPROX: detection half only; single-line calls
6.2|T1|Test file does not redefine an OBJ object constant locally (test_ files)|APPROX: same scope limit as 2.4
6.4|T1|Test buffer sizes are named constants (test_ files)|APPROX: literal other than 0/1 as a [size] in VAR/DAT or the count argument of byte/word/longfill/move
14.3a|PNUT|PNut portability: ERROR/WARN/INCLUDE/PRAGMA and #DEFINE-with-text only inside a PNut-TS-only branch|
14.3b|PNUT|PNut portability: conditional nesting no deeper than 8|'

NOT_T2='1.7   Pointer semantics differ from C
2.1.1 Vowel-removal shortening recognisable
2.1.2 Naming register (globals spelled out, locals shortened)
2.1.3 Consistent base names across methods
2.2   No generic container names (result, value, temp, data, ret, buf, info)
2.3   Return variables named for the data
3.3   Conditional-compilation discipline (gated vs ungated methods)
3.5   CON block organisation (related constants grouped)
3.6   DAT vs VAR semantics (singleton vs per-instance)
4.3   PUB method documentation structure and content
4.4   PRI method documentation structure and content
4.7   Enumerated constant groups documented
4.8   STRUCT declarations documented
4.10  Internal block comments use { } never {{ }} (content-level)
5.4.2 Named constants communicate intent
5.5   Multiple return values over pointer out-parameters
5.6   Error propagation (never overwrite a specific error)
6.3   Assertion method selection
6.5   Test lifecycle pattern
6.6   Expected errors commented
and the judgement half of every T1+T2 rule above (2.1.4, 2.5, 4.6, 5.7, 6.1): a finding listed in part 1 still needs the agent to judge it'

NOT_IMPL='3.1.1  {Spin2_v##} directive correctness: needs the feature-to-version authority (p2kb); the rule forbids a local feature table, so a script cannot derive it
3.4    DAT/VAR block placement: the rule forbids nothing mechanical (any number and placement of blocks is allowed); only locality, a judgement
6.7    Tests MUST pass: needs a running regression harness and hardware; none exists in this project (TEST_COMMAND: none yet)'

NOT_OTHER='Also outside this script: T0 rules 1.2 and 1.6 (the compiler rejects them); T3 rules 5.8 and 5.9 (Stephen decides).'

# ---------------------------------------------------------------- awk program
read -r -d '' AWKPROG <<'AWKEOF'
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function emit(rule, ln, msg) { printf "F\t%s\t%s\t%d\t%s\n", rule, FILE_NAME, ln, msg }
function indentOf(s) { match(s, /^[ \t]*/); return RLENGTH }

function splitTop(str, arr,   ni, cur, d, i, ch) {
  split("", arr)
  ni = 0; cur = ""; d = 0
  for (i = 1; i <= length(str); i++) {
    ch = substr(str, i, 1)
    if (ch == "(" || ch == "[") d++
    else if (ch == ")" || ch == "]") d--
    if (ch == "," && d == 0) { arr[++ni] = cur; cur = "" } else cur = cur ch
  }
  arr[++ni] = cur
  return ni
}

function argsAfter(s, p,   d, i, ch) {
  d = 0
  for (i = p; i <= length(s); i++) {
    ch = substr(s, i, 1)
    if (ch == "(") d++
    else if (ch == ")") { d--; if (d == 0) return substr(s, p + 1, i - p - 1) }
  }
  return substr(s, p + 1)
}

function identOf(item,   parts, np, nm) {
  item = trim(item)
  gsub(/\[[^]]*\]/, "", item)
  sub(/=.*/, "", item)
  item = trim(item)
  np = split(item, parts, /[ \t]+/)
  nm = parts[np]
  sub(/^\^/, "", nm)
  if (nm !~ /^[A-Za-z_][A-Za-z0-9_]*$/) return ""
  return nm
}

# ---- lexer: strips comments, blanks string contents -------------------------------------
function lexAll(   i, s, len, k, c, out, outN, lct, lcm, depth, instr, curDbl) {
  depth = 0; curDbl = 0; lastDbl = 0; dblEnd = 0
  for (i = 1; i <= n; i++) {
    s = raw[i]; len = length(s)
    inBC[i] = (depth > 0); hasBC[i] = 0; bcdbl[i] = 0; bcOpenCol[i] = 0; bcAfterCode[i] = 0
    out = ""; outN = ""; lct = ""; lcm = ""; instr = 0
    for (k = 1; k <= len; k++) {
      c = substr(s, k, 1)
      if (depth > 0) {
        hasBC[i] = 1
        if (c == "{") depth++
        else if (c == "}") { depth--; if (depth == 0 && curDbl) { dblEnd = i; curDbl = 0 } }
        continue
      }
      if (instr) { out = out c; outN = outN (c == "\"" ? c : " "); if (c == "\"") instr = 0; continue }
      if (c == "\"") { instr = 1; out = out c; outN = outN c; continue }
      if (c == "'") { lct = (substr(s, k + 1, 1) == "'") ? "''" : "'"; lcm = substr(s, k); break }
      if (c == "{") {
        depth = 1; hasBC[i] = 1
        if (bcOpenCol[i] == 0) { bcOpenCol[i] = k; bcAfterCode[i] = (trim(out) != "") }
        if (substr(s, k + 1, 1) == "{") { bcdbl[i] = 1; curDbl = 1; lastDbl = i }
        out = out " "; outN = outN " "
        continue
      }
      out = out c; outN = outN c
    }
    codeS[i] = out; codeN[i] = outN; lc[i] = lct; lcText[i] = lcm
  }
}

# ---- block sections -------------------------------------------------------------------
function sections(   i, u, k, cur) {
  cur = "HDR"
  for (i = 1; i <= n; i++) {
    decl[i] = ""
    if (!inBC[i]) {
      u = toupper(codeS[i])
      if (match(u, /^(CON|VAR|OBJ|DAT|PUB|PRI)([^A-Z0-9_]|$)/)) {
        k = substr(u, 1, 3); cur = k; decl[i] = k
        if (!(k in firstDecl)) firstDecl[k] = i
      }
    }
    sec[i] = cur
  }
}

# ---- methods ----------------------------------------------------------------------------
function addDecls(m, str, kind,   items, ni, i, id, k) {
  ni = splitTop(str, items)
  for (i = 1; i <= ni; i++) {
    id = identOf(items[i])
    if (id != "") { k = ++mDeclN[m]; mDecl[m, k] = id; mDeclKind[m, k] = kind }
  }
}

function parseSig(sig, m,   rest, p, d, i, ch, params, rets, locs) {
  rest = trim(sig); rest = trim(substr(rest, 4))
  mName[m] = ""
  if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) { mName[m] = substr(rest, 1, RLENGTH); rest = trim(substr(rest, RLENGTH + 1)) }
  params = ""; rets = ""; locs = ""
  if (substr(rest, 1, 1) == "(") {
    d = 0
    for (i = 1; i <= length(rest); i++) {
      ch = substr(rest, i, 1)
      if (ch == "(") d++
      else if (ch == ")") { d--; if (d == 0) break }
    }
    params = substr(rest, 2, i - 2); rest = trim(substr(rest, i + 1))
  }
  if (substr(rest, 1, 1) == ":") {
    rest = substr(rest, 2)
    p = index(rest, "|")
    if (p > 0) { rets = substr(rest, 1, p - 1); locs = substr(rest, p + 1) } else rets = rest
  } else if (substr(rest, 1, 1) == "|") locs = substr(rest, 2)
  mDeclN[m] = 0
  addDecls(m, params, "parameter"); addDecls(m, rets, "return variable"); addDecls(m, locs, "local")
}

function findMethods(   i, j, k, s, t, m) {
  nM = 0
  for (i = 1; i <= n; i++) {
    if (decl[i] != "PUB" && decl[i] != "PRI") continue
    m = ++nM; mKind[m] = decl[i]; mLine[m] = i
    s = codeS[i]; j = i
    while (1) {
      t = trim(s)
      if (t !~ /\.\.\.$/ || j >= n) break
      sub(/\.\.\.$/, "", t); j++; s = t " " codeS[j]
    }
    mSigEnd[m] = j
    k = j + 1
    while (k <= n && decl[k] == "") k++
    mEnd[m] = k - 1
    parseSig(s, m)
  }
}

function countTokens(m, cnt,   i, s, tok, before, lastc) {
  for (i = mSigEnd[m] + 1; i <= mEnd[m]; i++) {
    s = tolower(codeN[i]); lastc = ""
    while (match(s, /[a-z_][a-z0-9_]*/)) {
      tok = substr(s, RSTART, RLENGTH)
      before = (RSTART > 1) ? substr(s, RSTART - 1, 1) : lastc
      if (before !~ /[.$%0-9]/) cnt[tok]++
      lastc = substr(s, RSTART + RLENGTH - 1, 1)
      s = substr(s, RSTART + RLENGTH)
    }
  }
}

function bodyMatch(m, re,   i, t) {
  for (i = mSigEnd[m] + 1; i <= mEnd[m]; i++) {
    t = tolower(codeN[i])
    if (t ~ re) return i
  }
  return 0
}

function assignedIn(m, lid,   re1, re2, ln) {
  re1 = "(^|[^a-z0-9_.$%])" lid "([ \t]*\\[[^]]*\\])?[ \t]*(,[ \t]*[a-z_][a-z0-9_.]*([ \t]*\\[[^]]*\\])?[ \t]*)*(" AOPS ")"
  re2 = "(^|[^a-z0-9_.])repeat[ \t]+" lid "[ \t]+from"
  ln = bodyMatch(m, re1)
  return ln ? ln : bodyMatch(m, re2)
}

function unaryMinus(pre,   t, c) {
  t = pre; sub(/[ \t]+$/, "", t)
  if (substr(t, length(t), 1) != "-") return 0
  t = substr(t, 1, length(t) - 1); sub(/[ \t]+$/, "", t)
  c = substr(t, length(t), 1)
  if (c ~ /[A-Za-z0-9_)\]]/) return 0
  return 1
}

function magicLits(s,   out, tok, v, pre, consumed, rest, ok) {
  out = ""; consumed = ""; rest = s
  while (match(rest, /[A-Za-z_][A-Za-z0-9_]*|\$[0-9A-Fa-f_]+|%%?[0-9_]+|[0-9][0-9_]*(\.[0-9_]+)?/)) {
    tok = substr(rest, RSTART, RLENGTH)
    pre = consumed substr(rest, 1, RSTART - 1)
    if (tok ~ /^[0-9$%]/) {
      v = tok; gsub(/_/, "", v); ok = 0
      if (v ~ /^[0-9]+$/) {
        if (v + 0 == 0 || v + 0 == 4) ok = 1
        else if (v + 0 == 1 && unaryMinus(pre)) ok = 1
      }
      if (!ok) out = out (out == "" ? "" : ", ") tok
    }
    consumed = pre tok
    rest = substr(rest, RSTART + RLENGTH)
  }
  return out
}

# ---- 1.1 --------------------------------------------------------------------------------
function chk_ascii(   i, t) {
  for (i = 1; i <= n; i++) {
    t = raw[i]
    gsub(BOX, "", t)
    if (match(t, "[\200-\377]+")) emit("1.1", i, "non-ASCII character " substr(t, RSTART, RLENGTH) " (only U+2500-U+259F is allowed)")
  }
}

# ---- 14.3 -------------------------------------------------------------------------------
function chk_pnut(   i, t, w, rest, sym, nm, after, depth, d, eff, lvG, lvTS) {
  depth = 0
  for (i = 1; i <= n; i++) {
    if (inBC[i]) continue
    t = trim(codeS[i])
    if (t !~ /^#[A-Za-z]/) continue
    match(t, /^#[A-Za-z]+/)
    w = toupper(substr(t, 2, RLENGTH - 1)); rest = trim(substr(t, RLENGTH + 1))
    sym = ""
    if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) sym = toupper(substr(rest, 1, RLENGTH))
    if (w == "IFDEF" || w == "IFNDEF") {
      depth++
      if (depth > 8) emit("14.3b", i, "conditional nesting depth " depth " exceeds 8 (PNut limit)")
      lvG[depth] = (sym == "__PNUT_TS__") ? w : ""
      lvTS[depth] = (sym == "__PNUT_TS__" && w == "IFDEF") ? 1 : 0
      continue
    }
    if (w == "ELSE" || w == "ELSEIFDEF" || w == "ELSEIFNDEF") {
      if (depth > 0) {
        if (lvG[depth] == "IFDEF") lvTS[depth] = 0
        else if (lvG[depth] == "IFNDEF") lvTS[depth] = 1
      }
      continue
    }
    if (w == "ENDIF") { if (depth > 0) { lvG[depth] = ""; lvTS[depth] = 0; depth-- } ; continue }
    eff = 0
    for (d = 1; d <= depth; d++) if (lvTS[d]) eff = 1
    if (w == "ERROR" || w == "WARN" || w == "INCLUDE" || w == "PRAGMA") {
      if (!eff) emit("14.3a", i, "#" w " outside a PNut-TS-only (#IFDEF __PNUT_TS__) branch; PNut cannot compile it")
    } else if (w == "DEFINE") {
      nm = ""; after = ""
      if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) { nm = substr(rest, 1, RLENGTH); after = trim(substr(rest, RLENGTH + 1)) }
      if (after != "" && !eff) emit("14.3a", i, "#DEFINE " nm " carries substitution text outside a PNut-TS-only branch (PNut symbols are presence-only)")
    }
  }
}

# ---- 1.3 1.4 1.5 2.1 2.1.4 -----------------------------------------------------------------
function chkIdent(id, ln, where) {
  if (length(id) == 1) emit("2.1", ln, "single-letter name '" id "' (" where ")")
  else if (id ~ /^[A-Za-z][0-9]+$/) emit("2.1.4", ln, "letter-plus-digit name '" id "' (" where ")")
}

function chk_names(   m, k, id, lid, nm, i, nh, harr, s, w, a, items, ni, rest, label) {
  nh = split("cogid bool string send wc step neg skip skipf pa pb ptra ptrb dira", harr, " ")
  for (i = 1; i <= nh; i++) hz[harr[i]] = 1
  for (m = 1; m <= nM; m++) {
    nm = tolower(mName[m])
    if (nm in methFirst) emit("1.4", mLine[m], mKind[m] " " mName[m] "() repeats the method name at line " methFirst[nm] " (no overloading in Spin2)")
    else methFirst[nm] = mLine[m]
  }
  for (m = 1; m <= nM; m++) {
    nm = tolower(mName[m])
    if (nm in hz) emit("1.3", mLine[m], "method name '" mName[m] "' collides case-insensitively with a built-in/PASM2 name")
    for (k = 1; k <= mDeclN[m]; k++) {
      id = mDecl[m, k]; lid = tolower(id)
      w = mDeclKind[m, k] " in " mName[m] "()"
      if (lid in hz) emit("1.3", mLine[m], w " '" id "' collides case-insensitively with a built-in/PASM2 name")
      if (lid in methFirst) emit("1.5", mLine[m], w " '" id "' shadows the method of that name at line " methFirst[lid])
      chkIdent(id, mLine[m], w)
    }
  }
  for (i = 1; i <= n; i++) {
    if (decl[i] != "") continue
    s = trim(codeS[i])
    if (s == "" || s ~ /^#[A-Za-z]/) continue
    if (sec[i] == "OBJ") {
      if (match(s, /^[A-Za-z_][A-Za-z0-9_]*/)) { id = substr(s, 1, RLENGTH); if (tolower(id) in hz) emit("1.3", i, "OBJ alias '" id "' collides case-insensitively with a built-in/PASM2 name") }
    } else if (sec[i] == "VAR") {
      if (match(s, /^[^ \t]+/)) {
        rest = trim(substr(s, RLENGTH + 1))
        if (rest != "") {
          ni = splitTop(rest, items)
          for (a = 1; a <= ni; a++) { id = identOf(items[a]); if (id != "") chkIdent(id, i, "VAR") }
        }
      }
    } else if (sec[i] == "DAT") {
      if (substr(codeS[i], 1, 1) !~ /[ \t]/ && match(s, /^[A-Za-z_][A-Za-z0-9_]*/)) {
        label = substr(s, 1, RLENGTH)
        if (tolower(label) !~ /^(org|orgh|orgf|end|fit|alignl|alignw|res|byte|word|long|file)$/) chkIdent(label, i, "DAT label")
      }
    }
  }
}

# ---- 1.8 1.9 2.4 6.2 ------------------------------------------------------------------------
function collectCon(   i, s, items, ni, j, it, nm, rest) {
  conCnt = 0
  for (i = 1; i <= n; i++) {
    if (sec[i] != "CON" || decl[i] != "") continue
    s = trim(codeS[i])
    if (s == "" || s ~ /^#[A-Za-z]/) continue
    ni = splitTop(s, items)
    for (j = 1; j <= ni; j++) {
      it = trim(items[j])
      if (it ~ /^#/) continue
      if (match(it, /^[A-Za-z_][A-Za-z0-9_]*/)) {
        nm = substr(it, 1, RLENGTH); rest = trim(substr(it, RLENGTH + 1))
        if (rest == "" || rest ~ /^=/ || rest ~ /^\[/) { conCnt++; conN[conCnt] = nm; conL[conCnt] = i }
      }
    }
  }
}

function chk_misc(   i, s, k, q, fname, path, line, a, rest, items, ni, j, nm) {
  for (i = 1; i <= n; i++) if (index(codeS[i], "@\"\"") > 0) emit("1.8", i, "empty string literal @\"\" is invalid")
  for (k = 1; k <= conCnt; k++) myCon[tolower(conN[k])] = conL[k]
  conLoaded = 0
  for (i = 1; i <= n; i++) {
    if (sec[i] != "OBJ" || decl[i] != "") continue
    s = codeS[i]
    if (!match(s, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?[ \t]*:[ \t]*"[^"]*"/)) continue
    q = substr(s, RSTART, RLENGTH); rest = substr(s, RSTART + RLENGTH)
    fname = q; sub(/^[^"]*"/, "", fname); sub(/"$/, "", fname)
    if (fname !~ /\.spin2$/) fname = fname ".spin2"
    path = DIRPFX fname
    # 1.9: overrides after the quoted file name
    if (rest ~ /\|/) {
      rest = substr(rest, index(rest, "|") + 1)
      ni = splitTop(rest, items)
      for (j = 1; j <= ni; j++) {
        nm = trim(items[j]); sub(/[ \t]*=.*/, "", nm)
        if (nm != "" && (tolower(nm) in myCon)) emit("1.9", i, "OBJ override '" nm "' is also defined by a CON in this file (line " myCon[tolower(nm)] "); the parent's value wins silently")
      }
    }
    # 2.4 / 6.2: only children that are themselves being checked are read
    if (!(path in listSet)) continue
    if (!conLoaded) {
      while ((getline line < CONFILE) > 0) {
        split(line, a, "\t")
        if (a[1] == "C") childCon[a[2] SUBSEP tolower(a[3])] = a[3]
      }
      close(CONFILE); conLoaded = 1
    }
    for (k = 1; k <= conCnt; k++) {
      if ((path SUBSEP tolower(conN[k])) in childCon) {
        emit("2.4", conL[k], "local CON '" conN[k] "' duplicates a constant of OBJ file " fname "; reference it through the object")
        if (BASE ~ /^test_/) emit("6.2", conL[k], "test file redefines '" conN[k] "' locally; use the object's constant")
      }
    }
  }
}

# ---- 3.1 3.2 -------------------------------------------------------------------------------
function chk_layout(   i, firstMeth, ka, kb, kinds, nk, m, seenPri) {
  for (i = 1; i <= n; i++) if (raw[i] ~ /^[ \t]*\{Spin2_v[0-9]+\}/ && i != 1) emit("3.1", i, "{Spin2_v##} directive must be on line 1")
  firstMeth = n + 1
  if (("PUB" in firstDecl) && firstDecl["PUB"] < firstMeth) firstMeth = firstDecl["PUB"]
  if (("PRI" in firstDecl) && firstDecl["PRI"] < firstMeth) firstMeth = firstDecl["PRI"]
  nk = split("CON OBJ DAT VAR", kinds, " ")
  for (kb = 1; kb <= nk; kb++) {
    if (!(kinds[kb] in firstDecl) || firstDecl[kinds[kb]] > firstMeth) continue
    for (ka = 1; ka < kb; ka++) {
      if ((kinds[ka] in firstDecl) && firstDecl[kinds[ka]] < firstMeth && firstDecl[kinds[ka]] > firstDecl[kinds[kb]]) {
        emit("3.1", firstDecl[kinds[kb]], "first " kinds[kb] " block (line " firstDecl[kinds[kb]] ") precedes first " kinds[ka] " block (line " firstDecl[kinds[ka]] "); layout is CON, OBJ, DAT, VAR, PUB, PRI")
        break
      }
    }
  }
  seenPri = 0
  for (m = 1; m <= nM; m++) {
    if (mKind[m] == "PRI") { if (!seenPri) seenPri = mLine[m] }
    else if (seenPri) emit("3.2", mLine[m], "PUB " mName[m] "() appears after a PRI method (line " seenPri ")")
  }
}

# ---- 4.1 4.5 4.6 4.9 -------------------------------------------------------------------------
function chk_comments(   i, m, seenCode, t, s, txt) {
  for (i = 1; i <= n; i++) {
    if (bcdbl[i] && i != lastDbl) emit("4.1", i, "{{ }} doc block outside the license footer (use { })")
    if (lc[i] == "''" && decl[i] == "" && sec[i] != "HDR" && sec[i] != "PUB") {
      if (lcText[i] ~ /@local/) emit("4.1", i, "@local tag with '' (locals use ')")
      else emit("4.1", i, "'' doc comment in a " sec[i] " section (only the file header and PUB doc blocks use '')")
    }
  }
  for (m = 1; m <= nM; m++) {
    if (mKind[m] != "PUB") continue
    for (i = mLine[m] + 1; i <= mSigEnd[m]; i++)
      if (lc[i] == "''") emit("4.1", i, "'' comment on a partial signature line of " mName[m] "()")
    seenCode = 0
    for (i = mSigEnd[m] + 1; i <= mEnd[m]; i++) {
      t = trim(codeS[i])
      if (lc[i] == "''") {
        if (lcText[i] ~ /@local/) emit("4.1", i, "@local tag with '' (locals use ')")
        else if (t != "" && t !~ /^#[A-Za-z]/) emit("4.1", i, "trailing '' comment after code in " mName[m] "()")
        else if (seenCode) emit("4.1", i, "'' comment after the code of " mName[m] "() began (only the doc block after the signature uses '')")
      }
      if (t != "" && t !~ /^#[A-Za-z]/) seenCode = 1
    }
  }
  for (i = 1; i <= n; i++) {
    if (decl[i] != "") {
      if (tolower(raw[i]) ~ /\{spin2_doc_con\}/) { emit("4.5", i, "{Spin2_Doc_CON} on the declaration line (put it on the first line inside the block)"); continue }
      if (lc[i] == "''") emit("4.5", i, "'' on a block declaration line (use ')")
      else if (lc[i] == "'") {
        txt = substr(lcText[i], 2)
        if (txt !~ /[A-Za-z0-9]/) emit("4.5", i, "decorative border with no label on a block declaration line")
      }
      if (bcOpenCol[i] > 0) emit("4.5", i, "{ } comment on a block declaration line (rule 4.5: MUST use the apostrophe)")
    } else if ((sec[i] == "CON" || sec[i] == "VAR" || sec[i] == "DAT") && bcOpenCol[i] > 0 && bcAfterCode[i]) {
      emit("4.6", i, "trailing { } comment on a " sec[i] " declaration (use an apostrophe comment)")
    }
    if (sec[i] == "CON" && decl[i] == "" && (lastDbl == 0 || i < lastDbl)) {
      s = raw[i]
      gsub(BOX, "=", s)
      sub(/^[ \t]*(''|'|\{\{|\{)?[ \t]*/, "", s); sub(/[ \t}]*$/, "", s)
      if (length(s) >= 5 && s ~ /^[=_*#~-]+$/) emit("4.9", i, "horizontal separator line inside a CON block")
    }
  }
}

# ---- 4.2 4.2.1 --------------------------------------------------------------------------------
function chk_header(   hs, j, labels, lre, nl, k, found, val, lastNB, i, cl, txt) {
  hs = (raw[1] ~ /^\{Spin2_v[0-9]+\}/) ? 2 : 1
  if (raw[hs] !~ /^''/) {
    emit("4.2", hs, "no '' file header block here (it starts on line 1, or line 2 after {Spin2_v##})")
  } else {
    nl = split("file purpose authors? e-mail started updated", labels, " ")
    for (k = 1; k <= nl; k++) {
      found = 0
      for (j = hs; j <= n && raw[j] ~ /^''/; j++) {
        if (tolower(raw[j]) ~ ("^''[ \t]+" labels[k] "\\.+")) {
          found = 1
          if (labels[k] == "file") {
            val = raw[j]; sub(/^''[ \t]+[Ff][Ii][Ll][Ee]\.+[ \t]*/, "", val); val = trim(val)
            if (tolower(val) != tolower(BASE)) emit("4.2", j, "header File names '" val "' but the file is " BASE)
          }
        }
      }
      if (!found) { lre = labels[k]; sub(/\?$/, "", lre); emit("4.2", hs, "header has no '" lre "....' line") }
    }
  }
  lastNB = 0
  for (i = n; i >= 1; i--) if (trim(raw[i]) != "") { lastNB = i; break }
  if (lastDbl == 0) { emit("4.2.1", n, "no {{ }} license footer"); return }
  if (dblEnd != lastNB) emit("4.2.1", lastNB, "license footer is not the last content in the file")
  if (sec[lastDbl] != "CON") emit("4.2.1", lastDbl, "license footer is not inside a CON block")
  cl = 0
  for (i = lastDbl; i <= dblEnd; i++) {
    if (tolower(raw[i]) ~ /copyright \(c\)/) {
      cl = i; txt = raw[i]; sub(/^.*[Cc][Oo][Pp][Yy][Rr][Ii][Gg][Hh][Tt] \([Cc]\)[ \t]*/, "", txt); txt = trim(txt)
      if (tolower(txt) != tolower(LICENSE_TXT)) emit("4.2.1", i, "footer copyright '" txt "' differs from LICENSE '" LICENSE_TXT "'")
      break
    }
  }
  if (!cl) emit("4.2.1", lastDbl, "license footer has no 'Copyright (c)' line")
}

# ---- 2.5 -----------------------------------------------------------------------------------------
function chk_paramdesc(   i, s, h, nm, desc, key) {
  for (i = 1; i <= n; i++) {
    s = raw[i]
    if (match(s, /@param[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*-[ \t]*/)) {
      h = substr(s, RSTART, RLENGTH); desc = trim(substr(s, RSTART + RLENGTH))
      nm = h; sub(/@param[ \t]+/, "", nm); sub(/[ \t]*-[ \t]*$/, "", nm)
      key = tolower(nm); gsub(/[ \t]+/, " ", desc)
      if (key in pdesc) { if (pdesc[key] != desc) emit("2.5", i, "@param " nm " description differs from line " pline[key] ": '" pdesc[key] "' vs '" desc "'") }
      else { pdesc[key] = desc; pline[key] = i }
    }
  }
}

# ---- 5.x -------------------------------------------------------------------------------------------
function chk_methods(   m, k, id, lid, i, t, tl, cnt, base, ind, lastLine, stk, stkN, lits, ln, isBoolName) {
  for (m = 1; m <= nM; m++) {
    delete cnt
    countTokens(m, cnt)
    for (k = 1; k <= mDeclN[m]; k++) {
      id = mDecl[m, k]; lid = tolower(id)
      if (!(lid in cnt)) emit("5.0", mLine[m], mDeclKind[m, k] " '" id "' of " mName[m] "() is never used in the body")
      if (mDeclKind[m, k] == "return variable" && !assignedIn(m, lid)) emit("5.1", mLine[m], "return variable '" id "' of " mName[m] "() is never explicitly assigned")
    }
    isBoolName = (mName[m] ~ /^(is|has)[A-Z0-9_]/)
    for (k = 1; k <= mDeclN[m]; k++) {
      if (mDeclKind[m, k] != "return variable") continue
      lid = tolower(mDecl[m, k])
      if (mKind[m] == "PUB" && !isBoolName) {
        ln = bodyMatch(m, "(^|[^a-z0-9_.])" lid "[ \t]*:=[ \t]*(true|false)([^a-z0-9_]|$)")
        if (ln) emit("5.4", ln, "PUB " mName[m] "() returns TRUE/FALSE through '" mDecl[m, k] "' but is not named is*/has*; operations return SUCCESS/error codes")
      }
      if (mKind[m] == "PUB" && isBoolName) {
        ln = bodyMatch(m, "(^|[^a-z0-9_.])" lid "[ \t]*:=[ \t]*1([^0-9a-z_.$%]|$)")
        if (ln) emit("5.4.1", ln, "boolean return '" mDecl[m, k] "' of " mName[m] "() assigned 1; use TRUE")
      }
    }
    base = -1; lastLine = 0
    for (i = mSigEnd[m] + 1; i <= mEnd[m]; i++) {
      t = trim(codeN[i])
      if (t == "" || t ~ /^#[A-Za-z]/) continue
      ind = indentOf(codeN[i])
      if (base < 0 || ind < base) base = ind
      lastLine = i
    }
    stkN = 0
    for (i = mSigEnd[m] + 1; i <= mEnd[m]; i++) {
      t = trim(codeN[i])
      if (t == "" || t ~ /^#[A-Za-z]/) continue
      tl = tolower(t)
      ind = indentOf(codeN[i])
      while (stkN > 0 && ind <= stk[stkN]) stkN--
      if (tl ~ /(^|[^a-z0-9_.])return([^a-z0-9_]|$)/) {
        if (stkN > 0) emit("5.3", i, "return inside a repeat loop in " mName[m] "() (set the return variable and quit)")
        if (!(i == lastLine && ind == base && stkN == 0)) emit("5.2", i, "return before the end of " mName[m] "() (single exit point required)")
        if (mKind[m] == "PUB" && !isBoolName && tl ~ /(^|[^a-z0-9_.])return[ \t]+(true|false)([^a-z0-9_]|$)/)
          emit("5.4", i, "PUB " mName[m] "() returns TRUE/FALSE but is not named is*/has*")
      }
      if (tl ~ /^repeat([^a-z0-9_]|$)/) stk[++stkN] = ind
      if (t ~ /(^|[^A-Za-z0-9_.])b[A-Z][A-Za-z0-9_]*[ \t]*:=[ \t]*1([^0-9A-Za-z_.$%]|$)/) emit("5.4.1", i, "boolean assigned 1; use TRUE")
      if (t ~ /(^|[^A-Za-z0-9_.])b[A-Z][A-Za-z0-9_]*[ \t]*(==|<>)[ \t]*[01]([^0-9A-Za-z_.$%]|$)/) emit("5.4.1", i, "boolean compared with 1/0; compare with TRUE/FALSE")
      lits = magicLits(t)
      if (lits != "") emit("5.7", i, "numeric literal(s) " lits " in " mName[m] "() (name them in CON unless obvious)")
    }
  }
}

# ---- 6.1 6.4 (test files) ----------------------------------------------------------------------------
function chk_tests(   i, s, args, ni, j, a, items, sz, v) {
  if (BASE !~ /^test_/) return
  for (i = 1; i <= n; i++) {
    s = codeN[i]
    if (match(s, /evaluate[A-Za-z0-9_]*[ \t]*\(/)) {
      args = argsAfter(s, RSTART + RLENGTH - 1)
      ni = splitTop(args, items)
      for (j = 2; j <= ni; j++) {
        a = trim(items[j])
        if (a ~ /^-?(\$[0-9A-Fa-f_]+|%[01_]+|[0-9][0-9_]*)$/) emit("6.1", i, "raw literal " a " in an assertion (use a named constant)")
      }
    }
    if (match(s, /(byte|word|long)(fill|move)[ \t]*\(/)) {
      args = argsAfter(s, RSTART + RLENGTH - 1)
      ni = splitTop(args, items)
      a = trim(items[3])
      if (a ~ /^(\$[0-9A-Fa-f_]+|%[01_]+|[0-9][0-9_]*)$/) { v = a; gsub(/_/, "", v); if (!(v ~ /^[0-9]+$/ && (v + 0 == 0 || v + 0 == 1))) emit("6.4", i, "raw buffer size " a " in a fill/move call (name it in CON)") }
    }
    if (sec[i] == "VAR" || sec[i] == "DAT") {
      sz = s
      while (match(sz, /\[[ \t]*(\$[0-9A-Fa-f_]+|%[01_]+|[0-9][0-9_]*)[ \t]*\]/)) {
        a = substr(sz, RSTART + 1, RLENGTH - 2); a = trim(a); v = a; gsub(/_/, "", v)
        if (!(v ~ /^[0-9]+$/ && (v + 0 == 0 || v + 0 == 1))) emit("6.4", i, "raw array size [" a "] (name it in CON)")
        sz = substr(sz, RSTART + RLENGTH)
      }
    }
  }
}

function load(   nl, i, f) {
  BOX = "\342[\224\225][\200-\277]|\342\226[\200-\237]"
  AOPS =":=|\\+=|-=|\\*=|//=|/=|&=|\\|=|\\^=|<<=|>>=|#>=|<#=|~>=|->=|<-=|><=|&&=|\\|\\|=|\\^\\^=|\\+/=|\\+//=|\\*\\*=|\\+\\+|--|~~|~([^>]|$)"
  nl = split(LIST, f, "|")
  for (i = 1; i <= nl; i++) listSet[f[i]] = 1
  DIRPFX = FILE_NAME; sub(/[^\/]*$/, "", DIRPFX)
  BASE = FILE_NAME; sub(/^.*\//, "", BASE)
}

{ raw[++n] = $0 }
END {
  load()
  lexAll(); sections(); findMethods(); collectCon()
  if (MODE == "cons") {
    for (i = 1; i <= conCnt; i++) printf "C\t%s\t%s\t%d\n", FILE_NAME, conN[i], conL[i]
    exit
  }
  chk_ascii(); chk_pnut(); chk_names(); chk_misc(); chk_layout(); chk_comments(); chk_header()
  chk_paramdesc(); chk_methods(); chk_tests()
}
AWKEOF

# ---------------------------------------------------------------- file list
usage_err() { printf 'check_style.sh: %s\n' "$1" >&2; }

SUMMARY=0
if [ "${1:-}" = "-s" ] || [ "${1:-}" = "--summary" ]; then SUMMARY=1; shift; fi

FILES=()
if [ "$#" -gt 0 ]; then
  for a in "$@"; do FILES+=("${a#./}"); done
else
  cd "$ROOT" || { usage_err "cannot cd to $ROOT"; exit 2; }
  while IFS= read -r f; do
    [ -n "$f" ] && FILES+=("$f")
  done < <(git ls-files --cached --others --exclude-standard -- \
             'Src/isp_hub75_morph*.spin2' 'Src/demo_hub75_morph*.spin2' 'Src/test_hub75_morph*.spin2' | sort -u)
fi

LICENSE_FILE=${STYLE_LICENSE:-$ROOT/LICENSE}
LICENSE_TXT=""
if [ -f "$LICENSE_FILE" ]; then
  LICENSE_TXT=$(awk 'tolower($0) ~ /^copyright \(c\)/ { sub(/^[Cc][Oo][Pp][Yy][Rr][Ii][Gg][Hh][Tt] \([Cc]\)[ \t]*/, ""); print; exit }' "$LICENSE_FILE")
fi

NFILES=${#FILES[@]}
FIND=$(mktemp "${TMPDIR:-/tmp}/check_style.find.XXXXXX") || exit 2
CONS=$(mktemp "${TMPDIR:-/tmp}/check_style.cons.XXXXXX") || exit 2
trap 'rm -f "$FIND" "$CONS"' EXIT

BADFILE=0
if [ "$NFILES" -gt 0 ]; then
  if [ -z "$LICENSE_TXT" ]; then usage_err "no 'Copyright (c)' line found in $LICENSE_FILE (set STYLE_LICENSE)"; exit 2; fi
  LIST=$(IFS='|'; printf '%s' "${FILES[*]}")
  for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then usage_err "listed file missing: $f"; BADFILE=1; continue; fi
    awk -v MODE=cons -v FILE_NAME="$f" -v LIST="$LIST" -v CONFILE=/dev/null -v LICENSE_TXT="$LICENSE_TXT" "$AWKPROG" "$f" >> "$CONS"
  done
  [ "$BADFILE" -eq 1 ] && exit 2
  for f in "${FILES[@]}"; do
    awk -v MODE=check -v FILE_NAME="$f" -v LIST="$LIST" -v CONFILE="$CONS" -v LICENSE_TXT="$LICENSE_TXT" "$AWKPROG" "$f" >> "$FIND"
  done
  sort -s -t "$TAB" -k3,3 -k4,4n "$FIND" | uniq > "$FIND.s" && mv "$FIND.s" "$FIND"
fi

# every emitted rule id needs a ROSTER line; an id missing there would drop its findings from TOTAL
ROSTER_IDS=$(printf '%s\n' "$ROSTER" | awk -F'|' 'NF { printf "%s ", $1 }')
if [ "$NFILES" -gt 0 ]; then
  BAD_ID=$(awk -F"$TAB" -v ids="$ROSTER_IDS" 'BEGIN { n = split(ids, a, " "); for (i = 1; i <= n; i++) ok[a[i]] = 1 } !($2 in ok) { print $2; exit }' "$FIND")
  if [ -n "$BAD_ID" ]; then echo "internal error: rule id $BAD_ID emitted but not in ROSTER"; exit 2; fi
fi

# ---------------------------------------------------------------- report
TOTAL=0
DQ="''"
echo "Spin2 style gate -- central:spin2-authoring-guide -- $NFILES file(s)"
if [ "$NFILES" -gt 0 ]; then printf '  %s\n' "${FILES[@]}"; else echo "  (no files: nothing was checked)"; fi
echo
echo "== PART 1: rules checked =="
NRULES=0
while IFS='|' read -r id tier title note; do
  [ -z "$id" ] && continue
  NRULES=$((NRULES + 1))
  title=${title//\~\~/$DQ}
  if [ "$NFILES" -eq 0 ]; then
    printf '  n/a   [%s] (%s) %s -- not run, no files\n' "$id" "$tier" "$title"
    continue
  fi
  cnt=$(awk -F"$TAB" -v r="$id" '$2 == r' "$FIND" | wc -l | tr -d ' ')
  suffix=""; [ -n "$note" ] && suffix="  [${note//\~\~/$DQ}]"
  if [ "$cnt" -eq 0 ]; then
    printf '  PASS  [%s] (%s) %s%s\n' "$id" "$tier" "$title" "$suffix"
  else
    TOTAL=$((TOTAL + cnt))
    printf '  FAIL  [%s] (%s) %s -- %s finding(s)%s\n' "$id" "$tier" "$title" "$cnt" "$suffix"
    [ "$SUMMARY" -eq 0 ] && awk -F"$TAB" -v r="$id" '$2 == r { printf "          %s:%s: %s\n", $3, $4, $5 }' "$FIND"
  fi
done <<EOF
$ROSTER
EOF
echo
echo "== PART 2: T2 rules NOT checked (agent audit; Docs/analysis/spin2-T2-audit.md) =="
printf '%s\n' "$NOT_T2" | sed 's/^/  /'
echo
echo "== PART 3: assigned-T1 rules NOT implemented in this checker =="
printf '%s\n' "$NOT_IMPL" | sed 's/^/  /'
echo "  $NOT_OTHER"
echo
if [ "$NFILES" -eq 0 ]; then
  echo "RESULT: NOT RUN -- no files to check ($NRULES rules implemented, none run)"
  exit 2
fi
if [ "$TOTAL" -gt 0 ]; then
  echo "RESULT: FAIL -- $TOTAL finding(s) in $NFILES file(s); $NRULES rules implemented"
  exit 1
fi
echo "RESULT: PASS -- 0 findings in $NFILES file(s); $NRULES rules implemented"
exit 0
