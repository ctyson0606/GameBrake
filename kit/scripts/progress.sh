#!/usr/bin/env bash
# Generates one self-contained HTML page showing where the project stands, and
# opens it. The page stores nothing: every run rebuilds it from SPEC.md,
# STATE.md, AGENTS.md and git, so it cannot drift from them.
#
# The page is a normal scrolling page: the goals as sections, each acceptance
# criterion a card that opens to what it means, how to try it, its evidence and
# the commits and next steps that name it. Commits and Next Steps entries belong
# to a criterion only where its id is written in them (whole token), and a
# criterion belongs to a goal only where it names the goal "(G1)". Nothing is
# guessed from wording or position. Below them, a timeline of the commits by
# day, each opening to its body.
#
# The work is split in two. This script reads the files and git and writes the
# result as JSON inside the page; JavaScript inside the page does the rendering
# and interaction. Both stay in this one file so the output is one self-contained
# page that needs no network.
#
# This file lives at kit/scripts/progress.sh and is run through the stub at
# scripts/progress.sh (Windows: scripts/progress.ps1, which finds Git Bash and
# opens the page). ROOT is two levels above it, as in check.sh.
#
# Usage: scripts/progress.sh [--no-open] [--out <file>] [--no-mark]
#        scripts/progress.sh --untranslated
#
#   --no-open       write the page, do not open a browser
#   --out <file>    where to write it. Default: inside the git directory, so it
#                   belongs to this clone and is never committed
#   --no-mark       do not move the "last viewed" marker
#   --untranslated  print every displayed unit that has no current translation,
#                   and every orphaned translation, then stop. No page is made.
#
# stdout carries the output path (or, for --untranslated, the report) and
# nothing else; notices go to stderr, so a launcher can read the last line.
#
# Portable on purpose: bash 3.2 and BSD userland (macOS) as well as Git Bash and
# Linux. No associative arrays, mapfile, ${var,,}, sed -i, grep -P, GNU date
# flags, or awk beyond POSIX (no interval expressions either: {n} is missing
# from the awk macOS ships).

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NO_OPEN=0
OUT=""
UNTRANS=0
MARK=1
FIRST_N=15     # commits shown on a first view
MAX_N=50       # commits shown at most

while [ $# -gt 0 ]; do
  case "$1" in
    --no-open)      NO_OPEN=1 ;;
    --no-mark)      MARK=0 ;;
    --untranslated) UNTRANS=1 ;;
    --out)
      shift
      [ $# -gt 0 ] || { echo "progress.sh: --out needs a file" >&2; exit 2; }
      OUT="$1" ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "progress.sh: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if ! GITDIR="$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null)"; then
  echo "progress.sh: $ROOT is not inside a git repository. The page reads git for what changed, and keeps its marker in the git directory." >&2
  exit 1
fi

SPEC="$ROOT/SPEC.md"
STATE="$ROOT/STATE.md"
AGENTS="$ROOT/AGENTS.md"
MARKER="$GITDIR/sparkforge-progress-last"
[ -n "$OUT" ] || OUT="$GITDIR/sparkforge-progress.html"
case "$OUT" in /*|?:*) ;; *) OUT="$PWD/$OUT" ;; esac

T="$(mktemp -d "${TMPDIR:-/tmp}/sparkforge-progress.XXXXXX")" || exit 1
trap 'rm -rf "$T"' EXIT
mkdir "$T/tr" "$T/used"

# --- declarations -----------------------------------------------------------
# TRANSLATION is blank when unset. The value names a file, so it is held to a
# language tag rather than trusted as a path.
LANG2=""
if [ -f "$AGENTS" ]; then
  LANG2="$(sed -n 's/^TRANSLATION:[[:space:]]*//p' "$AGENTS" | head -n 1 \
           | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//' | tr -d '\r')"
fi
case "$LANG2" in
  *[!A-Za-z0-9-]*) echo "progress.sh: TRANSLATION '$LANG2' is not a language tag; ignoring it" >&2; LANG2="" ;;
esac
TRANS_ON=0
[ -n "$LANG2" ] && TRANS_ON=1

if [ "$UNTRANS" -eq 1 ] && [ "$TRANS_ON" -eq 0 ]; then
  echo "TRANSLATION is blank in AGENTS.md, so there is nothing to translate."
  exit 0
fi

# --- awk: units --------------------------------------------------------------
# A unit is one paragraph or one list item of a section, whitespace collapsed
# and trimmed: the thing that gets a translation, and the thing that is hashed.
# Output: "<kind> <text>" with kind p, li or h. Comments and fenced blocks are
# skipped.
UNITS_AWK='
function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
function flush() { if (cur != "") print kind " " cur; cur = ""; kind = "" }
{ sub(/\r$/, "") }
/^## / { flush(); on = (norm($0) == "## " sec); fence = 0; incom = 0; next }
!on { next }
{ line = $0 }
incom { if (line ~ /-->/) incom = 0; next }
line ~ /^[ \t]*<!--/ { if (line !~ /-->/) incom = 1; next }
line ~ /^[ \t]*```/ { flush(); fence = !fence; next }
fence { next }
line ~ /^[ \t]*$/ { flush(); next }
line ~ /^###+ / { flush(); sub(/^#+ +/, "", line); kind = "h"; cur = norm(line); flush(); next }
line ~ /^[ \t]*([-*]|[0-9]+[.)])[ \t]+/ {
  flush(); sub(/^[ \t]*([-*]|[0-9]+[.)])[ \t]+/, "", line); kind = "li"; cur = norm(line); next }
{ if (cur == "") { kind = "p"; cur = norm(line) } else cur = cur " " norm(line) }
END { flush() }
'

# --- awk: translation file -> one file per hash --------------------------------
# An entry is a "## <hash>" heading and the translated text under it, up to the
# next heading. Several lines are joined into one.
TRFILE_AWK='
function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
function done_entry() {
  if (active && txt != "") { print txt > (dir "/" h); close(dir "/" h) }
  active = 0; txt = ""
}
{ sub(/\r$/, "") }
/^## / { done_entry(); h = $2; if (h ~ /^[0-9a-f]+$/) active = 1; next }
active && NF { txt = (txt == "") ? norm($0) : txt " " norm($0) }
END { done_entry() }
'

TRFILE=""
if [ "$TRANS_ON" -eq 1 ]; then
  TRFILE="$ROOT/translations/$LANG2.md"
  if [ -f "$TRFILE" ]; then
    awk -v dir="$T/tr" "$TRFILE_AWK" "$TRFILE"
  else
    echo "progress.sh: translations/$LANG2.md does not exist; every unit shows in English as untranslated" >&2
  fi
fi
# --- awk: JSON ---------------------------------------------------------------------------------
# The page is drawn by JavaScript from one JSON block. Everything read from a
# file is escaped here, and only here: backslash, quote, every control
# character, and "<" as a unicode escape, so "</script>" in a file can never end the
# block it is embedded in. The page itself sets text only through textContent,
# so nothing read from a file is ever parsed as markup.
JLIB='
function jesc(s,   o, i, c, n, k) {
  o = ""
  n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "\\") o = o "\\\\"
    else if (c == "\"") o = o "\\\""
    else if (c == "<") o = o "\\u003c"
    else if ((k = index(CTL, c)) > 0) o = o sprintf("\\u%04x", k)
    else o = o c
  }
  return "\"" o "\""
}
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
BEGIN { for (ci = 1; ci < 32; ci++) CTL = CTL sprintf("%c", ci) }
'

json_str() { printf '%s' "$1" | awk "$JLIB"'{ printf "%s", jesc($0) } END { if (NR == 0) printf "\"\"" }'; }

# units_json <res-file>: [{"k":kind,"st":ok|stale,"en":..,"tr":..}, ...]
units_json() {
  awk "$JLIB"'
    BEGIN { FS = "\037"; printf "[" }
    NF >= 4 { printf "%s{\"k\":%s,\"st\":%s,\"en\":%s,\"tr\":%s}", (n++ ? "," : ""), jesc($1), jesc($2), jesc($4), jesc($5) }
    END { printf "]" }' "$1"
}

# A list item that starts with an id: "G1 (M1): text", "AC3 (G1, G2): text". The
# ids in parentheses are references, and refpat says what a reference looks
# like (goals for a criterion, milestones for a goal). Sets
# pid (empty when the item has no id), prefs (comma list of goal ids, empty
# when none are written) and prest (the text without them). The pattern says
# what an id looks like, so goals and criteria can differ.
HEAD_AWK='
function parse_head(s, pat,   w, rest, p, inner, n, parts, i, ok) {
  pid = ""; prefs = ""; prest = s
  w = s; sub(/ .*$/, "", w)
  if (w == s || w !~ pat) return
  pid = w; sub(/[.:)]$/, "", pid)
  rest = substr(s, length(w) + 2)
  if (substr(rest, 1, 1) == "(") {
    p = index(rest, ")")
    if (p > 0) {
      inner = substr(rest, 2, p - 2)
      gsub(/[,;\/]/, " ", inner)
      n = split(inner, parts, " ")
      ok = (n > 0)
      for (i = 1; i <= n; i++) if (parts[i] !~ refpat) ok = 0
      if (ok) {
        prefs = parts[1]
        for (i = 2; i <= n; i++) prefs = prefs "," parts[i]
        rest = trim(substr(rest, p + 1))
        if (substr(rest, 1, 1) == ":") rest = trim(substr(rest, 2))
        else if (substr(rest, 1, length("：")) == "：") rest = trim(substr(rest, length("：") + 1))
      }
    }
  }
  prest = rest
}
# The same head on a translation: dropped only when it names the same id.
function strip_tr(t, id, pat,   r) {
  if (t == "") return t
  parse_head(t, pat)
  if (pid == id) return prest
  if (substr(t, 1, length(id)) == id) {
    r = substr(t, length(id) + 1)
    if (substr(r, 1, 1) == ":") return trim(substr(r, 2))
    if (substr(r, 1, length("：")) == "：") return trim(substr(r, length("：") + 1))
  }
  return t
}
function jarr_ids(csv,   n, parts, i, o) {
  if (csv == "") return "[]"
  n = split(csv, parts, ",")
  o = "["
  for (i = 1; i <= n; i++) o = o (i > 1 ? "," : "") jesc(parts[i])
  return o "]"
}
'
ID_PAT='^[A-Za-z][A-Za-z]*[0-9][0-9]*[.:)]?$'
GOAL_PAT='^G[0-9][0-9]*[.:)]?$'
MS_PAT='^M[0-9][0-9]*[.:)]?$'
COMP_PAT='^C[0-9][0-9]*[.:)]?$'

# idlist_json <res-file> <id pattern> <prefix> <reference pattern>
# Goals and milestones are lists of the same shape: an item "G1 (M1): text" is
# goal G1 and refers to milestone M1; an item without an id is <prefix><n> by
# position, flagged so the page can say that the id was never written.
idlist_json() {
  awk -v idpat="$2" -v prefix="$3" -v refpat="$4" "$JLIB $HEAD_AWK"'
    BEGIN { FS = "\037"; printf "[" }
    NF >= 4 {
      pos++
      en = $4; tr = $5; refs = ""
      parse_head(en, idpat)
      if (pid == "") { id = prefix pos; impl = 1 }
      else { id = pid; impl = 0; refs = prefs; en = prest; tr = strip_tr(tr, id, idpat) }
      dup = (id in U) ? 1 : 0
      U[id] = 1
      printf "%s{\"id\":%s,\"impl\":%s,\"dup\":%s,\"refs\":%s,\"st\":%s,\"en\":%s,\"tr\":%s}", (n++ ? "," : ""), jesc(id), (impl ? "true" : "false"), (dup ? "true" : "false"), jarr_ids(refs), jesc($2), jesc(en), jesc(tr)
    }
    END { printf "]" }' "$1"
}

# --- awk: acceptance criteria and their sub-items ---------------------------------------------
# Like the units above, but it knows about indentation. A list item starts a
# criterion; indented items under it that begin "Means:" or "Try:" belong to it
# and are units of their own (kinds means and try, the label dropped); any
# other indented item, and continuation lines, stay part of the criterion's
# text. Output: "<kind> <text>" with kind li, means or try, a criterion first
# and its sub-items after it.
AC_UNITS_AWK='
function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
function emit(   i) {
  if (have) {
    print "li " norm(acText)
    for (i = 1; i <= nm; i++) print "means " norm(mt[i])
    for (i = 1; i <= nt; i++) print "try " norm(tt[i])
  }
  have = 0; acText = ""; nm = 0; nt = 0; tgt = ""
}
function addto(s) {
  if (tgt == "m") mt[nm] = mt[nm] " " s
  else if (tgt == "t") tt[nt] = tt[nt] " " s
  else if (tgt == "a") acText = acText " " s
}
{ sub(/\r$/, "") }
/^## / { emit(); on = (norm($0) == "## " sec); fence = 0; incom = 0; base = -1; next }
!on { next }
{ line = $0 }
incom { if (line ~ /-->/) incom = 0; next }
line ~ /^[ \t]*<!--/ { if (line !~ /-->/) incom = 1; next }
line ~ /^[ \t]*```/ { fence = !fence; tgt = ""; next }
fence { next }
line ~ /^[ \t]*$/ { tgt = ""; next }
line ~ /^###+ / { emit(); next }
line ~ /^[ \t]*([-*]|[0-9]+[.)])[ \t]+/ {
  lead = line; sub(/[^ \t].*$/, "", lead); gsub(/\t/, "    ", lead); ind = length(lead)
  sub(/^[ \t]*([-*]|[0-9]+[.)])[ \t]+/, "", line)
  line = norm(line)
  if (!have || ind <= base) { emit(); have = 1; base = ind; acText = line; tgt = "a"; next }
  if (line ~ /^Means:/) { sub(/^Means:[ \t]*/, "", line); mt[++nm] = line; tgt = "m"; next }
  if (line ~ /^Try:/) { sub(/^Try:[ \t]*/, "", line); tt[++nt] = line; tgt = "t"; next }
  acText = acText " " line; tgt = "a"; next
}
{ addto(norm(line)) }
END { emit() }
'

# resolve_section <file> <heading> [li|ac]
# One line per displayed unit: kind, status, hash, English, translation, joined
# by the unit separator (octal 037). status is ok when an entry's hash equals the
# hash of the current English unit, otherwise stale: a translation written for
# an older wording is never shown as current. With a third argument li, only
# list items are kept; with ac, the section is read by AC_UNITS_AWK and every
# kind it produces is kept.
resolve_section() {
  [ -f "$1" ] || return 0
  if [ "${3:-}" = "ac" ]; then awk -v sec="$2" "$AC_UNITS_AWK" "$1"
  else awk -v sec="$2" "$UNITS_AWK" "$1"; fi | while read -r kind text; do
    [ "${3:-}" != "li" ] || [ "$kind" = "li" ] || continue
    h=""; tr=""; st="ok"
    if [ "$TRANS_ON" -eq 1 ]; then
      h="$(printf '%s' "$text" | git hash-object --stdin)"
      if [ -f "$T/tr/$h" ]; then
        tr="$(cat "$T/tr/$h")"
        : > "$T/used/$h"
      else
        st="stale"
      fi
    fi
    printf '%s\037%s\037%s\037%s\037%s\n' "$kind" "$st" "$h" "$text" "$tr"
  done
}

# resolve_batch <in> <out>
# The same resolution for many units at once: git hash-object runs once, over a
# file per unit, instead of once per unit. Each input line is kind, text and any
# extra fields, joined by octal 037; each output line is kind, status, hash,
# text, translation and the extra fields.
TW="$T"
command -v cygpath >/dev/null 2>&1 && TW="$(cygpath -m "$T")"
BN=0
resolve_batch() {
  local in="$1" out="$2" n=0 kind text rest d
  BN=$((BN + 1)); d="$T/b$BN"; mkdir "$d"
  : > "$d.list"; : > "$d.hashes"
  if [ "$TRANS_ON" -eq 1 ]; then
    while IFS=$'\037' read -r kind text rest; do
      n=$((n + 1))
      printf '%s' "$text" > "$d/$n"
      printf '%s\n' "$TW/b$BN/$n" >> "$d.list"
    done < "$in"
    git hash-object --no-filters --stdin-paths < "$d.list" > "$d.hashes"
  fi
  awk -v trdir="$T/tr" -v usedir="$T/used" -v trans="$TRANS_ON" -v hf="$d.hashes" '
    BEGIN { FS = "\037"; if (trans == 1) { while ((getline l < hf) > 0) H[++nh] = l; close(hf) } }
    {
      h = ""; tr = ""; st = "ok"
      if (trans == 1) {
        h = H[NR]; f = trdir "/" h
        if ((getline tr < f) > 0) { printf "" > (usedir "/" h); close(usedir "/" h) } else { tr = ""; st = "stale" }
        close(f)
      }
      printf "%s\037%s\037%s\037%s\037%s", $1, st, h, $2, tr
      for (i = 3; i <= NF; i++) printf "\037%s", $i
      printf "\n"
    }' "$in" > "$out"
}

resolve_section "$SPEC"  "Problem"             > "$T/res.problem"
resolve_section "$SPEC"  "Milestones"          li > "$T/res.ms"
resolve_section "$SPEC"  "Goals"               li > "$T/res.goals"
resolve_section "$SPEC"  "Acceptance criteria" ac > "$T/res.ac"
resolve_section "$STATE" "Current Focus"       > "$T/res.focus"
resolve_section "$STATE" "Next Steps"          li > "$T/res.next"
resolve_section "$STATE" "Open Questions"      > "$T/res.open"

# --- STATE.md's Acceptance status lines ---------------------------------------------------------
# "<id>: evidenced|claimed|not started - evidence (date)". Evidence yields its
# commands (the inline code) and its result (the whole text, commands inline,
# translated around them). Output, joined by octal 037: S, id, status,
# evidence, date, result, commands (joined by octal 036); or B and the raw line
# when it cannot be read.
: > "$T/status.units"
[ -f "$STATE" ] && awk -v sec="Acceptance status" "$UNITS_AWK" "$STATE" > "$T/status.units"
awk -v EM="—" "$JLIB"'
function norm(s) { gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s }
{
  t = $0
  if (t !~ /^li /) next
  t = substr(t, 4)
  i = index(t, ":")
  if (i == 0) { print "B\037" t; next }
  id = trim(substr(t, 1, i - 1)); rest = trim(substr(t, i + 1))
  if (id == "" || id ~ / /) { print "B\037" t; next }
  if (substr(rest, 1, 9) == "evidenced") { st = "evidenced"; rest = substr(rest, 10) }
  else if (substr(rest, 1, 7) == "claimed") { st = "claimed"; rest = substr(rest, 8) }
  else if (substr(rest, 1, 11) == "not started") { st = "none"; rest = substr(rest, 12) }
  else { print "B\037" t; next }
  rest = trim(rest)
  if (substr(rest, 1, length(EM)) == EM) rest = trim(substr(rest, length(EM) + 1))
  else if (substr(rest, 1, 2) == "--") rest = trim(substr(rest, 3))
  else if (substr(rest, 1, 1) == "-" || substr(rest, 1, 1) == ":") rest = trim(substr(rest, 2))
  date = ""
  if (match(rest, /[(][0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][)]$/)) {
    date = substr(rest, RSTART + 1, 10); rest = trim(substr(rest, 1, RSTART - 1))
  }
  # The result keeps its commands inline: cutting them out left sentences
  # with holes ("passed ( : 29 passed"), and a translation keeps inline code
  # as written anyway.
  n = split(rest, parts, "`")
  cmds = ""; res = rest
  if (n > 1 && n % 2 == 1) {
    for (k = 2; k <= n; k += 2) cmds = cmds (cmds == "" ? "" : "\036") parts[k]
  }
  print "S\037" id "\037" st "\037" rest "\037" date "\037" res "\037" cmds
}' "$T/status.units" > "$T/status.parsed"
awk 'BEGIN { FS = "\037" } $1 == "S" && $6 != "" { print "ev\037" $6 "\037" $2 "\037" $5 }' "$T/status.parsed" > "$T/ev.in"
resolve_batch "$T/ev.in" "$T/res.ev"

FMT='%h%x1f%ad%x1f%s'
# --- the components ---------------------------------------------------------------------------
# "C1: Name (`path`) — responsibility; uses C2, C3". Output, joined by octal 037:
# C, id, whether the id was missing (1) or written (0), name, path,
# responsibility, the ids it uses (comma list).
: > "$T/comps.items"
[ -f "$SPEC" ] && awk -v sec="Components" "$UNITS_AWK" "$SPEC" > "$T/comps.items"
awk -v idpat="$COMP_PAT" -v refpat='^$' -v EM="—" "$JLIB $HEAD_AWK"'
  function after_dash(s) {
    s = trim(s)
    if (substr(s, 1, length(EM)) == EM) return trim(substr(s, length(EM) + 1))
    if (substr(s, 1, 2) == "--") return trim(substr(s, 3))
    if (substr(s, 1, 1) == "-") return trim(substr(s, 2))
    return s
  }
  $0 ~ /^li / {
    t = substr($0, 4); pos++
    parse_head(t, idpat)
    if (pid == "") { id = "C" pos; impl = 1; rest = t } else { id = pid; impl = 0; rest = prest }
    name = ""; path = ""; resp = ""; uses = ""
    i = index(rest, " (`")
    if (i > 0) {
      name = trim(substr(rest, 1, i - 1)); r2 = substr(rest, i + 3); p = index(r2, "`)")
      if (p > 0) { path = substr(r2, 1, p - 1); r3 = substr(r2, p + 2) } else { r3 = r2 }
    } else {
      j = index(rest, " " EM " ")
      if (j > 0) { name = trim(substr(rest, 1, j - 1)); r3 = substr(rest, j) } else { name = trim(rest); r3 = "" }
    }
    r3 = after_dash(r3)
    u = index(r3, "; uses ")
    if (u > 0) { resp = trim(substr(r3, 1, u - 1)); uses = substr(r3, u + 7) }
    else if (substr(r3, 1, 5) == "uses ") { uses = substr(r3, 6) }
    else resp = r3
    # A uses list is bare ids. A list holding any token that is not an id shape
    # is not trusted at all: ids sitting in prose may mean something other than
    # "uses" (through, instead of), and a wrong line would look true. Nothing is
    # drawn from it; the whole list is kept as written (field 8) so a gap can
    # name it.
    rawuses = trim(uses); bad = 0
    gsub(/[,;]/, " ", uses); n = split(uses, parts, " "); uses = ""
    for (k = 1; k <= n; k++) {
      sub(/[.]$/, "", parts[k])
      if (parts[k] == "") continue
      if (parts[k] ~ /^C[0-9]+$/) uses = uses (uses == "" ? "" : ",") parts[k]
      else bad = 1
    }
    if (bad) uses = ""
    print "C\037" id "\037" impl "\037" name "\037" path "\037" resp "\037" uses "\037" (bad ? rawuses : "")
  }' "$T/comps.items" > "$T/comps.parsed"
# Names and responsibilities are translation units.
awk 'BEGIN { FS = "\037" } { if ($4 != "") print "cname\037" $4 "\037" $2; if ($6 != "") print "cresp\037" $6 "\037" $2 }' "$T/comps.parsed" > "$T/comp.in"
resolve_batch "$T/comp.in" "$T/res.comp"
# Whether each path exists, and the last commits that touched it.
: > "$T/comps.exist"; : > "$T/cc.in"
while IFS=$'\037' read -r ck cid cimpl cname cpath cresp cuses cbad; do
  [ -n "$cid" ] || continue
  ex=no; safe=0
  if [ -n "$cpath" ]; then
    case "$cpath" in /*|?:*|*..*) ;; *) safe=1; [ -e "$ROOT/$cpath" ] && ex=yes ;; esac
  fi
  printf '%s\037%s\n' "$cid" "$ex" >> "$T/comps.exist"
  if [ "$safe" -eq 1 ]; then
    git --literal-pathspecs -C "$ROOT" log -n 5 --date=short --format="$FMT" -- "$cpath" 2>/dev/null \
      | awk -v id="$cid" 'BEGIN { FS = "\037" } NF >= 3 { print "commit\037" $3 "\037" $1 "\037" $2 "\037" id }' >> "$T/cc.in"
  fi
done < "$T/comps.parsed"
resolve_batch "$T/cc.in" "$T/res.cc"

# --- what changed since this machine last looked ------------------------------------------
# changes.log holds the commits to show; hist.log holds every commit (newest
# first, up to HIST_N) whose subject names a criterion, so that a criterion can
# list the commits that touched it, however old. Both go through translation:
# a commit subject is a unit like any other.
HIST_N=5000
HIST_SHOWN=300
CH_KIND="nocommits"; CH_N=""; CH_TOTAL=0
: > "$T/changes.log"; : > "$T/hist.log"
HEADC="$(git -C "$ROOT" rev-parse --verify -q HEAD 2>/dev/null)" || HEADC=""
if [ -n "$HEADC" ]; then
  last=""
  [ -f "$MARKER" ] && last="$(head -n 1 "$MARKER" | tr -d '[:space:]')"
  if [ -z "$last" ]; then
    CH_KIND="first"
    git -C "$ROOT" log -n "$FIRST_N" --date=short --format="$FMT" HEAD > "$T/changes.log"
  elif ! git -C "$ROOT" cat-file -e "$last^{commit}" 2>/dev/null; then
    CH_KIND="lost"
    git -C "$ROOT" log -n "$FIRST_N" --date=short --format="$FMT" HEAD > "$T/changes.log"
  else
    CH_TOTAL="$(git -C "$ROOT" rev-list --count "$last..HEAD")"
    CH_N="$(git -C "$ROOT" rev-parse --short "$last")"
    if [ "$CH_TOTAL" -eq 0 ]; then CH_KIND="none"; else CH_KIND="some"
      git -C "$ROOT" log -n "$MAX_N" --date=short --format="$FMT" "$last..HEAD" > "$T/changes.log"
    fi
  fi
  git -C "$ROOT" log -n "$HIST_N" --date=short --format="$FMT" HEAD 2>/dev/null \
    | awk -F '\037' '$3 ~ /[A-Za-z][0-9]/' > "$T/hist.pre"
fi
[ -f "$T/hist.pre" ] || : > "$T/hist.pre"

# The ids of the criteria, as the page will know them, to keep from the history
# only the commits that name one (whole token: AC1 is not found in AC10).
awk -v idpat="$ID_PAT" -v refpat='^G[0-9][0-9]*$' "$JLIB $HEAD_AWK"'
  BEGIN { FS = "\037" }
  $1 == "li" { pos++; parse_head($4, idpat); print (pid == "" ? "AC" pos : pid) }' "$T/res.ac" > "$T/ac.ids"
awk -v idf="$T/ac.ids" '
  function isw(c) { return c ~ /[A-Za-z0-9_]/ }
  function has_tok(s, id,   i, p, b, a) {
    p = 1
    while ((i = index(substr(s, p), id)) > 0) {
      i += p - 1
      b = (i == 1) ? "" : substr(s, i - 1, 1); a = substr(s, i + length(id), 1)
      if (!isw(b) && !isw(a)) return 1
      p = i + 1
    }
    return 0
  }
  BEGIN { FS = "\037"; while ((getline l < idf) > 0) ids[++n] = l }
  { for (k = 1; k <= n; k++) if (has_tok($3, ids[k])) { print; break } }' "$T/hist.pre" | head -n "$HIST_SHOWN" > "$T/hist.log"

awk 'BEGIN { FS = "\037" } NF >= 3 { print "commit\037" $3 "\037" $1 "\037" $2 }' "$T/changes.log" > "$T/ch.in"
awk 'BEGIN { FS = "\037" } NF >= 3 { print "commit\037" $3 "\037" $1 "\037" $2 }' "$T/hist.log" > "$T/hi.in"
resolve_batch "$T/ch.in" "$T/res.changes"
resolve_batch "$T/hi.in" "$T/res.hist"

# --- the timeline ---------------------------------------------------------------------
# The last TL_N commits, newest first: subject, date, whether it is new since the
# last view, and its body split into paragraphs, trailers such as Co-Authored-By
# dropped. A commit is a record when every file it touched is memory or
# framework: the memory files, AGENTS.md, the entry files kit/entry-points.txt
# lists, kit/, the skill stubs under .claude/, the script stubs and translations/. The page folds records away so
# the timeline shows the work. Subjects and paragraphs are translation units.
# Output lines, joined by octal 037: tls, subject, hash, date, record (1|0),
# new (1|0); then tlb, paragraph, hash for each paragraph of its body.
TL_N=300
: > "$T/tl.in"; : > "$T/tl.new"; : > "$T/tl.entry"
if [ -n "$HEADC" ]; then
  [ "$CH_KIND" = "some" ] && awk -F '\037' '{ print $1 }' "$T/changes.log" > "$T/tl.new"
  [ -f "$ROOT/kit/entry-points.txt" ] && grep -v -e '^#' -e '^[[:space:]]*$' "$ROOT/kit/entry-points.txt" > "$T/tl.entry"
  git -C "$ROOT" log -n "$TL_N" --date=short --name-only --format='%x1e%h%x1f%ad%x1f%s%x1f%b%x1d' HEAD 2>/dev/null \
    | awk -v nf="$T/tl.new" -v ef="$T/tl.entry" '
      BEGIN {
        RS = "\036"; FS = "\035"
        while ((getline l < nf) > 0) NEW[l] = 1; close(nf)
        while ((getline l < ef) > 0) { sub(/\r$/, "", l); ENT[l] = 1 } close(ef)
      }
      function isrec(f) {
        if (f ~ /^(SPEC|METHOD|STATE|GOTCHAS|AGENTS)\.md$/) return 1
        if (f ~ /^(kit|translations|\.claude)\//) return 1
        if (f ~ /^scripts\/(check|update-kit|progress)\.(sh|ps1)$/) return 1
        return (f == ".gitattributes" || (f in ENT))
      }
      $1 != "" {
        n = split($1, H, "\037"); if (n < 3) next
        h = H[1]; d = H[2]; s = H[3]; b = (n >= 4) ? H[4] : ""
        rec = 1; nfl = split($2, F, "\n")
        for (i = 1; i <= nfl; i++) { f = F[i]; sub(/\r$/, "", f); if (f != "" && !isrec(f)) { rec = 0; break } }
        print "tls\037" s "\037" h "\037" d "\037" rec "\037" ((h in NEW) ? 1 : 0)
        m = split(b, L, "\n"); para = ""
        for (i = 1; i <= m + 1; i++) {
          line = (i <= m) ? L[i] : ""
          sub(/\r$/, "", line)
          if (line ~ /^[A-Za-z]+(-[A-Za-z]+)*-[Bb]y: / || line ~ /^Change-Id: /) line = ""
          gsub(/^[ \t]+|[ \t]+$/, "", line)
          if (line == "" || line ~ /^[-*] /) {
            if (para != "") print "tlb\037" para "\037" h
            para = ""
            if (line == "") continue
          }
          para = (para == "") ? line : para " " line
        }
      }' > "$T/tl.in"
fi
resolve_batch "$T/tl.in" "$T/res.tl"

# --- --untranslated: report and stop ------------------------------------------------
if [ "$UNTRANS" -eq 1 ]; then
  echo "# Language: $LANG2 (translations/$LANG2.md)"
  echo "# Units below have no current translation. Each block is a translation-file"
  echo "# entry: keep the '## <hash>' line, replace the English with the translation."
  echo "# Commands and inline code (between backticks) are kept exactly as written."
  echo
  cat "$T/res.problem" "$T/res.focus" "$T/res.ms" "$T/res.goals" "$T/res.ac" "$T/res.ev" "$T/res.next" "$T/res.open" "$T/res.changes" "$T/res.hist" "$T/res.tl" "$T/res.comp" "$T/res.cc" \
    | awk 'BEGIN { FS = "\037" } $2 == "stale" && !($3 in seen) { seen[$3] = 1; print "## " $3; print $4; print "" }'
  echo "# Orphaned entries: their hash matches no displayed unit, so prune them."
  orph=0
  for f in "$T"/tr/*; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"
    [ -e "$T/used/$n" ] && continue
    orph=$((orph + 1))
    printf '%s  %s\n' "$n" "$(head -c 60 "$f")"
  done
  [ "$orph" -gt 0 ] || echo "(none)"
  exit 0
fi

# acs_json: criteria joined with the parsed status lines and the resolved
# evidence results. The id is the first word of a criterion when it looks like
# AC1; a criterion without one is numbered by position as AC<n>. Goals it serves
# are the ids in parentheses after the id. The status of a criterion comes only
# from a status line naming that id, and nothing is checked here: the page shows
# the evidence so a person can rerun it. Output:
# {"acs":[...],"unknown":[ids],"bad":[lines]}
acs_json() {
  awk -v pf="$T/status.parsed" -v ef="$T/res.ev" -v idpat="$ID_PAT" -v refpat='^G[0-9][0-9]*$' "$JLIB $HEAD_AWK"'
function unit(st, en, tr) { return "{\"st\":" jesc(st) ",\"en\":" jesc(en) ",\"tr\":" jesc(tr) "}" }
function jcmds(csv,   n, parts, i, o) {
  if (csv == "") return "[]"
  n = split(csv, parts, "\036"); o = "["
  for (i = 1; i <= n; i++) o = o (i > 1 ? "," : "") jesc(parts[i])
  return o "]"
}
function flush_ac(   evr) {
  if (!have) return
  evr = "null"
  if (RES[cid] != "") evr = unit(EVS[cid], RES[cid], EVT[cid])
  printf "%s{\"id\":%s,\"impl\":%s,\"dup\":%s,\"goals\":%s,\"decl\":%s,\"ev\":%s,\"cmds\":%s,\"evr\":%s,\"date\":%s,\"st\":%s,\"en\":%s,\"tr\":%s,\"means\":[%s],\"tries\":[%s]}", \
    (nacs++ ? "," : ""), jesc(cid), (cimpl ? "true" : "false"), (cdup ? "true" : "false"), jarr_ids(crefs), jesc(cdecl), jesc(E[cid]), jcmds(C[cid]), evr, jesc(D[cid]), jesc(cst), jesc(cen), jesc(ctr), mj, tj
  have = 0; mj = ""; tj = ""
}
BEGIN { FS = "\037"; printf "{\"acs\":[" }
FILENAME == pf {
  if ($1 == "B") { bad[++nb] = $2; next }
  if ($1 == "S") { id = $2; S[id] = $3; E[id] = $4; D[id] = $5; RES[id] = $6; C[id] = $7 }
  next
}
FILENAME == ef { EVS[$6] = $2; EVT[$6] = $5; next }
$1 == "li" {
  flush_ac()
  pos++
  cen = $4; ctr = $5; cst = $2
  parse_head(cen, idpat)
  if (pid == "") { cid = "AC" pos; cimpl = 1; crefs = "" }
  else { cid = pid; cimpl = 0; crefs = prefs; cen = prest; ctr = strip_tr(ctr, cid, idpat) }
  cdup = (cid in U) ? 1 : 0
  U[cid] = 1
  cdecl = (cid in S) ? S[cid] : "missing"
  have = 1
  next
}
$1 == "means" { mj = mj (mj == "" ? "" : ",") unit($2, $4, $5); next }
$1 == "try" { tj = tj (tj == "" ? "" : ",") unit($2, $4, $5); next }
END {
  flush_ac()
  printf "],\"unknown\":["
  for (id in S) if (!(id in U)) printf "%s%s", (nu++ ? "," : ""), jesc(id)
  printf "],\"bad\":["
  for (i = 1; i <= nb; i++) printf "%s%s", (i > 1 ? "," : ""), jesc(bad[i])
  printf "]}"
}' "$T/status.parsed" "$T/res.ev" "$T/res.ac"
}

# commits_json <res-file>: [{"h":hash,"d":date,"s":subject,"tr":..,"st":..}, ...]
commits_json() {
  awk "$JLIB"'
    BEGIN { FS = "\037"; printf "[" }
    NF >= 7 { printf "%s{\"h\":%s,\"d\":%s,\"s\":%s,\"tr\":%s,\"st\":%s}", (n++ ? "," : ""), jesc($6), jesc($7), jesc($4), jesc($5), jesc($2) }
    END { printf "]" }' "$1"
}

# tl_json: the timeline's commits, each with its body paragraphs as units.
tl_json() {
  awk "$JLIB"'
    function unit() { return "{\"en\":" jesc($4) ",\"tr\":" jesc($5) ",\"st\":" jesc($2) "}" }
    BEGIN { FS = "\037"; printf "[" }
    $1 == "tls" {
      if (open) printf "]}"
      printf "%s{\"h\":%s,\"d\":%s,\"s\":%s,\"tr\":%s,\"st\":%s,\"rec\":%s,\"isnew\":%s,\"body\":[", (n++ ? "," : ""), jesc($6), jesc($7), jesc($4), jesc($5), jesc($2), ($8 == 1 ? "true" : "false"), ($9 == 1 ? "true" : "false")
      open = 1; nb = 0; next
    }
    $1 == "tlb" && open { printf "%s%s", (nb++ ? "," : ""), unit() }
    END { if (open) printf "]}"; printf "]" }' "$1"
}

# comps_json: the components with their translated names and responsibilities,
# whether the path exists, and the last commits that touched it.
comps_json() {
  awk -v pf="$T/comps.parsed" -v rf="$T/res.comp" -v xf="$T/comps.exist" -v cf="$T/res.cc" "$JLIB"'
    function unit(st, en, tr) { return "{\"st\":" jesc(st) ",\"en\":" jesc(en) ",\"tr\":" jesc(tr) "}" }
    function jarr(csv,   n, parts, i, o) { if (csv == "") return "[]"; n = split(csv, parts, ","); o = "["; for (i = 1; i <= n; i++) o = o (i > 1 ? "," : "") jesc(parts[i]); return o "]" }
    BEGIN { FS = "\037"; printf "[" }
    FILENAME == rf { if ($1 == "cname") { NMS[$6] = $2; NMT[$6] = $5 } else { RSS[$6] = $2; RTT[$6] = $5 } next }
    FILENAME == xf { EX[$1] = $2; next }
    FILENAME == cf { CC[$8] = CC[$8] (CC[$8] == "" ? "" : ",") "{\"h\":" jesc($6) ",\"d\":" jesc($7) ",\"s\":" jesc($4) ",\"tr\":" jesc($5) ",\"st\":" jesc($2) "}"; next }
    FILENAME == pf {
      id = $2; dup = (id in U) ? 1 : 0; U[id] = 1
      printf "%s{\"id\":%s,\"impl\":%s,\"dup\":%s,\"name\":%s,\"path\":%s,\"exists\":%s,\"resp\":%s,\"uses\":%s,\"badUses\":%s,\"commits\":[%s]}", (n++ ? "," : ""), jesc(id), ($3 == 1 ? "true" : "false"), (dup ? "true" : "false"), ($4 == "" ? "null" : unit(NMS[id], $4, NMT[id])), jesc($5), (EX[id] == "yes" ? "true" : "false"), ($6 == "" ? "null" : unit(RSS[id], $6, RTT[id])), jarr($7), jesc($8), CC[id]
    }
    END { printf "]" }' "$T/res.comp" "$T/comps.exist" "$T/res.cc" "$T/comps.parsed"
}

# env_json: dev always, install and build when AGENTS.md has the key. A blank
# value is a finding, so it is passed on as blank (p true, v empty).
env_json() {
  [ -f "$AGENTS" ] || { printf '{"install":{"p":false,"v":""},"dev":{"p":false,"v":""},"build":{"p":false,"v":""}}'; return; }
  awk "$JLIB"'
    { sub(/\r$/, "") }
    /^## / { on = ($0 == "## Environment facts"); next }
    !on { next }
    /^(install|dev|build):/ {
      k = $0; sub(/:.*$/, "", k)
      v = $0; sub(/^[a-z]+:/, "", v); sub(/[ \t]+#.*$/, "", v); v = trim(v)
      V[k] = v; P[k] = 1
    }
    function one(k) { return "{\"p\":" ((k in P) ? "true" : "false") ",\"v\":" jesc(V[k]) "}" }
    END { printf "{\"install\":%s,\"dev\":%s,\"build\":%s}", one("install"), one("dev"), one("build") }' "$AGENTS"
}


# --- the page ------------------------------------------------------------------------------
esc_sh() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
NAME=""
[ -f "$AGENTS" ] && NAME="$(sed -n 's/^# //p' "$AGENTS" | head -n 1 | tr -d '\r')"
[ -n "$NAME" ] || NAME="$(basename "$ROOT")"
NAME_H="$(printf '%s' "$NAME" | esc_sh)"
if [ "$TRANS_ON" -eq 1 ]; then DEF_LANG="zh"; TLANG="$LANG2"; else DEF_LANG="en"; TLANG="zh-TW"; fi
UPDATED=""
[ -f "$STATE" ] && UPDATED="$(sed -n 's/^> Last updated:[[:space:]]*//p' "$STATE" | head -n 1 | tr -d '\r')"
NOW="$(date '+%Y-%m-%d %H:%M')"
HEAD_SHORT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo none)"
TRFILE_OK=true
[ "$TRANS_ON" -eq 1 ] && [ ! -f "$TRFILE" ] && TRFILE_OK=false
TRANS_JS=false; [ "$TRANS_ON" -eq 1 ] && TRANS_JS=true
# Translations whose hash matches no displayed unit (the same ones --untranslated
# lists for pruning).
ORPHANS=0
for f in "$T"/tr/*; do
  [ -e "$f" ] || continue
  [ -e "$T/used/$(basename "$f")" ] || ORPHANS=$((ORPHANS + 1))
done

{
printf '<!doctype html>\n<html lang="%s" data-lang="%s" data-tlang="%s">\n' "$DEF_LANG" "$DEF_LANG" "$TLANG"
cat <<'EOF'
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
EOF
printf '<title>%s progress</title>\n' "$NAME_H"
printf '<style>\n'
cat <<'EOF'
:root { --bg:#f6f5f1; --fg:#1f1f1c; --muted:#6a6963; --line:#e2e0d8; --card:#fff; --panel:#fff;
  --ok:#14663a; --okbg:#e3f4ea; --mid:#8a5a00; --midbg:#fbf0d4; --none:#5d5d57; --nonebg:#eeeeea;
  --warn:#a02c1b; --warnbg:#fceae6; --code:#efeee8; --acc:#1b5fa8; --shadow:0 1px 2px rgba(0,0,0,.06), 0 4px 14px rgba(0,0,0,.05); }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg:#141417; --fg:#e9e7e0; --muted:#a09e96; --line:#2f2f33; --card:#1d1d21; --panel:#1b1b1f;
  --ok:#74d69e; --okbg:#173325; --mid:#f0c460; --midbg:#3a2e12; --none:#b3b3ad; --nonebg:#2a2a2d;
  --warn:#ff9d8a; --warnbg:#3b1d19; --code:#2a2a2e; --acc:#7db6f0; --shadow:0 1px 2px rgba(0,0,0,.4), 0 4px 14px rgba(0,0,0,.3); } }
* { box-sizing:border-box; }
[hidden] { display:none !important; }
html { scroll-behavior:smooth; }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior:auto; } * { transition:none !important; animation:none !important; } }
body { margin:0; background:var(--bg); color:var(--fg);
  font:16px/1.55 system-ui, -apple-system, "Segoe UI", "Noto Sans TC", "PingFang TC", "Microsoft JhengHei", sans-serif; }
code { background:var(--code); border-radius:4px; padding:.05em .3em; font:.88em ui-monospace, Consolas, Menlo, monospace; overflow-wrap:anywhere; }
pre { margin:.3rem 0; background:var(--code); border-radius:8px; padding:.55rem .7rem; overflow:auto; }
pre code { background:none; padding:0; white-space:pre-wrap; overflow-wrap:anywhere; }
button { font:inherit; font-size:.9rem; padding:.3rem .8rem; border:1px solid var(--line); border-radius:8px; background:var(--card); color:var(--fg); cursor:pointer; }
button:hover { border-color:var(--acc); }
:focus-visible { outline:3px solid var(--acc); outline-offset:2px; }
html[data-lang="en"] .zh { display:none; }
html[data-lang="zh"] .en { display:none; }

/* chrome */
#top { position:sticky; top:0; z-index:5; background:var(--bg); border-bottom:1px solid var(--line); }
.bar { max-width:1180px; margin:0 auto; padding:.6rem 20px; display:flex; flex-wrap:wrap; gap:.4rem 1rem; align-items:center; justify-content:space-between; }
.bar h1 { font-size:1.25rem; margin:0; }
.tools { display:flex; gap:.5rem; }
#page { max-width:1180px; margin:0 auto; padding:1.2rem 20px 4rem; }
.id { font:600 .78rem ui-monospace, Consolas, Menlo, monospace; color:var(--muted); }
.muted { color:var(--muted); }
.date { color:var(--muted); font-size:.85em; }

/* what this is / progress */
.top2 { display:grid; grid-template-columns:minmax(0,3fr) minmax(0,2fr); gap:16px; }
.box { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:1rem 1.2rem; box-shadow:var(--shadow); min-width:0; }
.box h2 { margin:0 0 .5rem; font-size:1.05rem; }
.box h3 { margin:.9rem 0 .2rem; font-size:.72rem; letter-spacing:.07em; color:var(--muted); }
.box h3:first-of-type { margin-top:0; }
.box p { margin:.2rem 0; }
.cmd { display:flex; gap:.5rem; align-items:center; margin:.25rem 0; min-width:0; }
.cmd .k { font-weight:600; width:4.6rem; flex:none; background:none; }
.cmd code { flex:1; min-width:0; padding:.3em .5em; }
.cmd button { flex:none; padding:.1rem .6rem; font-size:.8rem; }
.gapname { color:var(--warn); font-style:italic; flex:1; }
.big { font-size:2rem; font-weight:700; line-height:1.1; margin:.2rem 0 .1rem; }
.bar3 { display:flex; height:14px; border-radius:7px; overflow:hidden; background:var(--nonebg); margin:.6rem 0; }
.bar3 i { display:block; height:100%; }
.bar3 .k1 { background:var(--ok); } .bar3 .k2 { background:#d9a21b; }
.counts { display:flex; flex-wrap:wrap; gap:.3rem 1.1rem; font-size:.95rem; }
.counts .t1 { color:var(--ok); } .counts .t2 { color:var(--mid); } .counts .t3 { color:var(--none); }
#trline { margin:0 0 .9rem; padding:.45rem .8rem; border:1px solid var(--warn); background:var(--warnbg); border-radius:10px; font-size:.9rem; }
#highline { margin:.9rem 0 0; }
#highline button { width:100%; text-align:left; padding:.55rem .9rem; border-color:var(--warn); background:var(--warnbg); color:var(--warn); font-weight:600; border-radius:10px; }

/* goal sections and cards */
.goal { margin-top:1.8rem; }
.gh { display:flex; flex-wrap:wrap; gap:.3rem 1rem; align-items:baseline; margin-bottom:.7rem; }
.gh .gid { font:700 .85rem ui-monospace, Consolas, Menlo, monospace; background:var(--nonebg); border-radius:6px; padding:.1rem .45rem; }
.gh .gt { flex:1 1 320px; min-width:0; font-size:1.08rem; font-weight:600; }
.gh .gs { color:var(--muted); font-size:.9rem; white-space:nowrap; }
.empty { color:var(--muted); font-style:italic; margin:.3rem 0; }
.grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(260px, 1fr)); gap:14px; }
.acard { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:.9rem 1rem 1rem; cursor:pointer; box-shadow:var(--shadow); display:flex; flex-direction:column; gap:.55rem; min-height:140px; transition:transform .12s, border-color .12s; }
.acard:hover { transform:translateY(-2px); border-color:var(--acc); }
.acard .top { display:flex; align-items:center; gap:.6rem; }
.ico { flex:none; width:2.3rem; height:2.3rem; border-radius:50%; display:grid; place-items:center; font-size:1.25rem; font-weight:700; }
.lab { font-weight:700; font-size:.95rem; }
.s-evidenced .ico { background:var(--okbg); color:var(--ok); } .s-evidenced .lab { color:var(--ok); }
.s-claimed .ico { background:var(--midbg); color:var(--mid); } .s-claimed .lab { color:var(--mid); }
.s-none .ico { background:var(--nonebg); color:var(--none); } .s-none .lab { color:var(--none); }
.acard .title { overflow-wrap:anywhere; font-size:1rem; font-weight:600; line-height:1.4; flex:1; }
.acard .foot { display:flex; align-items:center; justify-content:space-between; gap:.5rem; }
.untr { font-size:.72rem; font-weight:700; color:var(--warn); background:var(--warnbg); border:1px solid var(--warn); border-radius:99px; padding:0 .5rem; white-space:nowrap; margin-left:auto; }
.mtTag { font-size:.66em; font-weight:700; border:1px solid var(--acc); border-radius:4px; padding:0 .3em; margin-right:.35em; color:var(--acc); font-style:normal; vertical-align:.1em; white-space:nowrap; }
.trbtns { display:flex; flex-wrap:wrap; gap:.5rem; margin-top:.45rem; }
.enTag { font-size:.66em; font-weight:700; border:1px solid var(--line); border-radius:4px; padding:0 .3em; margin-right:.35em; color:var(--muted); font-style:normal; vertical-align:.1em; }
.fb { color:var(--muted); }
.cl { overflow:hidden; display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:3; }
.cl.l2 { -webkit-line-clamp:2; } .cl.l4 { -webkit-line-clamp:4; }
.cw.open .cl { display:block; }
.more { margin-top:.2rem; padding:0 .5rem; font-size:.75rem; }
.cw.open .lm, .cw:not(.open) .ll { display:none; }
.flash { animation:flash 1.6s ease-out; }
@keyframes flash { 0%, 40% { box-shadow:0 0 0 4px var(--acc); } 100% { box-shadow:var(--shadow); } }

/* lists */
#lists { margin-top:2.2rem; display:grid; grid-template-columns:minmax(0,3fr) minmax(0,2fr); gap:16px; align-items:start; }
.lead .leadtext { margin:.15rem 0 .2rem; font-size:1.02rem; font-weight:600; line-height:1.55; }
.leadfull > .u { margin:.15rem 0 .65rem; line-height:1.6; }
.gnote { color:var(--muted); font-size:.88rem; margin:-.35rem 0 .7rem; }
.glist { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:.9rem 1.2rem; box-shadow:var(--shadow); margin:1.4rem 0 1.6rem; }
.glist h3 { margin:0 0 .5rem; font-size:1rem; }
.glist ul { list-style:none; margin:0; padding:0; }
.glist li { display:flex; gap:.7rem; align-items:baseline; padding:.4rem 0; border-top:1px solid var(--line); }
.glist li:first-child { border-top:0; }
.glist .gid { font:700 .8rem ui-monospace, Consolas, Menlo, monospace; background:var(--nonebg); border-radius:6px; padding:.05rem .4rem; flex:none; }
.glist .gt { flex:1; min-width:0; }
.tl { margin-top:.3rem; }
.tlday { position:relative; border-left:2px solid var(--line); margin-left:.35rem; padding:0 0 1.1rem 1.1rem; }
.tlday::before { content:""; position:absolute; left:-7px; top:.3rem; width:12px; height:12px; border-radius:50%; background:var(--acc); border:2px solid var(--card); }
.tlday:last-child { border-left-color:transparent; }
.tlhead { display:flex; flex-wrap:wrap; gap:.2rem .8rem; align-items:baseline; }
.tldate { font-weight:700; font-variant-numeric:tabular-nums; }
.tlcount, .tlidl { color:var(--muted); font-size:.85rem; }
.tlids { display:flex; flex-wrap:wrap; gap:.3rem .5rem; align-items:center; margin-top:.25rem; }
.tlids .chips { margin-top:0; }
.lcol .tlday ul { margin-top:.35rem; }
.lcol li.tlitem { padding:.45rem 0; }
.tlsubj { flex:1; min-width:0; }
.newb { font-size:.7rem; font-weight:700; color:var(--acc); border:1px solid var(--acc); border-radius:99px; padding:0 .45rem; }
.tltog, .tlolder { margin-top:.3rem; padding:.05rem .55rem; font-size:.78rem; color:var(--muted); }
.tlbody { margin:.4rem 0 .2rem; padding:.6rem .8rem; border-radius:10px; background:var(--code); font-size:.92rem; }
.tlbody > .u { margin:0 0 .55rem; line-height:1.6; }
.tlmeta { color:var(--muted); font-size:.8rem; }
.tlrec { opacity:.85; }
.lcol { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:1rem 1.2rem; box-shadow:var(--shadow); min-width:0; }
.lcol h2 { margin:0; font-size:1.05rem; }
.lcol .sub { color:var(--muted); font-size:.85rem; margin:.1rem 0 .6rem; }
.lcol ul { list-style:none; margin:0; padding:0; }
.lcol li { padding:.6rem 0; border-top:1px solid var(--line); }
.lcol li:first-child { border-top:0; }
.lcol .row { display:flex; flex-wrap:wrap; gap:.3rem .6rem; align-items:baseline; }
.chips { display:flex; flex-wrap:wrap; gap:.3rem; margin-top:.3rem; }
.chip { font:600 .75rem ui-monospace, Consolas, Menlo, monospace; padding:.05rem .5rem; border-radius:99px; background:var(--nonebg); }
.origbtn { margin-left:.4rem; padding:0 .4rem; font-size:.7rem; color:var(--muted); }
.origtext { display:block; color:var(--muted); font-size:.88em; margin-top:.15rem; }

/* drawers */
#scrim { position:fixed; inset:0; background:rgba(0,0,0,.4); z-index:19; }
.drawer { position:fixed; top:0; right:0; bottom:0; width:min(560px, 100vw); background:var(--panel); z-index:20; overflow:auto; padding:1rem 1.3rem 3rem;
  box-shadow:-8px 0 30px rgba(0,0,0,.25); transform:translateX(100%); visibility:hidden; transition:transform .2s ease, visibility 0s linear .2s; }
.drawer.open { transform:none; visibility:visible; transition:transform .2s ease; }
.dhead { display:flex; align-items:center; justify-content:space-between; gap:.6rem; margin-bottom:.6rem; }
.dtitle { font-size:1.3rem; line-height:1.35; margin:.2rem 0 .3rem; }
.dmeta { display:flex; flex-wrap:wrap; gap:.4rem .8rem; align-items:center; color:var(--muted); font-size:.9rem; }
.badge { display:inline-flex; align-items:center; gap:.35rem; font-weight:700; font-size:.9rem; padding:.1rem .7rem .1rem .2rem; border-radius:99px; }
.badge .ico { width:1.6rem; height:1.6rem; font-size:.95rem; }
.badge.s-evidenced { background:var(--okbg); color:var(--ok); } .badge.s-claimed { background:var(--midbg); color:var(--mid); } .badge.s-none { background:var(--nonebg); color:var(--none); }
.badge .ico { background:transparent; }
.dsec { margin-top:1.3rem; }
.dsec h3 { margin:0 0 .35rem; font-size:.8rem; letter-spacing:.06em; color:var(--muted); }
.dsec ol { margin:.2rem 0; padding-left:1.4rem; } .dsec ol li { margin:.35rem 0; }
.dsec ul { list-style:none; margin:0; padding:0; } .dsec ul li { padding:.45rem 0; border-top:1px solid var(--line); } .dsec ul li:first-child { border-top:0; }
.warnline { color:var(--warn); font-weight:600; }
.gl { margin-top:.2rem; }
.gl h3 { margin:1rem 0 .3rem; font-size:.78rem; letter-spacing:.05em; }
.gl h3.high { color:var(--warn); } .gl h3.medium { color:var(--mid); } .gl h3.low { color:var(--muted); }
.gi { display:flex; gap:.6rem; padding:.55rem .7rem; margin:.35rem 0; border:1px solid var(--line); border-radius:10px; background:var(--card); font-size:.92rem; }
.gi.ref { cursor:pointer; } .gi.ref:hover { border-color:var(--acc); }
.gi.high { border-color:var(--warn); background:var(--warnbg); } .gi.medium { border-color:#d9a21b; background:var(--midbg); } .gi.low { color:var(--muted); }
.gi .ic { flex:none; width:1rem; text-align:center; font-weight:700; }
.gi.high .ic { color:var(--warn); } .gi.medium .ic { color:var(--mid); }
.drawer details { margin-top:1.2rem; } .drawer summary { cursor:pointer; font-weight:600; }
.drawer details li { margin:.35rem 0; font-size:.92rem; }
.gen { color:var(--muted); font-size:.8rem; margin-top:1.5rem; }
noscript { display:block; padding:1rem; }

/* tabs */
.tabs { max-width:1180px; margin:0 auto; padding:0 20px; display:flex; gap:.2rem; overflow-x:auto; }
.tab { border:0; border-bottom:3px solid transparent; border-radius:0; background:none; padding:.55rem 1rem; font-size:.98rem; color:var(--muted); font-weight:600; white-space:nowrap; }
.tab[aria-selected="true"] { color:var(--fg); border-bottom-color:var(--acc); }
.tabtitle { font-size:1.35rem; margin:.2rem 0 .2rem; }
.tabnote, .quiet { color:var(--muted); font-size:.92rem; margin:.2rem 0 1rem; }
.emptybox { background:var(--card); border:1px dashed var(--line); border-radius:14px; padding:1rem 1.2rem; }
.emptybox p { margin:0 0 .4rem; }

/* scope */
#scopebar { display:flex; flex-wrap:wrap; gap:.4rem; align-items:center; margin:0 0 1rem; }
#scopebar .lbl { color:var(--muted); font-size:.85rem; margin-right:.3rem; }
.scopechip { display:inline-flex; align-items:center; gap:.4rem; border-radius:99px; padding:.25rem .85rem; font-weight:600; }
.scopechip[aria-pressed="true"] { border-color:var(--acc); background:var(--acc); color:#fff; }
.scopechip[aria-pressed="true"] .id { color:#fff; }
.scopechip .curdot { font-size:.7rem; color:var(--acc); background:var(--nonebg); border-radius:99px; padding:0 .4rem; }
.scopeline { color:var(--muted); font-size:.92rem; margin:-.2rem 0 .3rem; }

/* roadmap */
.rm { list-style:none; margin:0; padding:0; }
.rm li { position:relative; }
.rm li + li { margin-top:.7rem; }
.rmrow { display:flex; gap:1rem; width:100%; text-align:left; padding:1rem 1.2rem; border-radius:14px; background:var(--card); box-shadow:var(--shadow); align-items:flex-start; }
.rmrow.cur { border:2px solid var(--acc); }
.step { flex:none; width:2.2rem; height:2.2rem; border-radius:50%; display:grid; place-items:center; font-weight:700; background:var(--nonebg); color:var(--none); }
.st-done .step { background:var(--okbg); color:var(--ok); } .st-progress .step { background:var(--midbg); color:var(--mid); }
.rmbody { display:flex; flex-direction:column; gap:.3rem; min-width:0; flex:1; }
.rmtop { display:flex; flex-wrap:wrap; align-items:center; gap:.4rem .7rem; }
.rmtitle { font-weight:700; font-size:1.05rem; }
.rmsub { color:var(--muted); font-size:.92rem; }
.rmgoals { display:flex; flex-direction:column; gap:.15rem; margin-top:.2rem; font-size:.9rem; }
.rmgoal { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.sbadge { font-size:.75rem; font-weight:700; padding:.05rem .6rem; border-radius:99px; }
.sbadge.st-done { background:var(--okbg); color:var(--ok); } .sbadge.st-progress { background:var(--midbg); color:var(--mid); } .sbadge.st-planned { background:var(--nonebg); color:var(--none); }
.curpill { font-size:.72rem; font-weight:700; color:#fff; background:var(--acc); border-radius:99px; padding:.05rem .6rem; }

/* features */
.fmh { font-size:1.15rem; margin:1.8rem 0 .2rem; }
.fgoal { margin-top:1rem; }
.fgh { font-size:1rem; margin:0 0 .6rem; display:flex; gap:.5rem; align-items:baseline; flex-wrap:wrap; }
.fgh .gid { font:700 .85rem ui-monospace, Consolas, Menlo, monospace; background:var(--nonebg); border-radius:6px; padding:.1rem .45rem; }
.fgrid { display:grid; grid-template-columns:repeat(auto-fill, minmax(300px, 1fr)); gap:14px; }
.feat { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:.9rem 1.1rem; box-shadow:var(--shadow); cursor:pointer; }
.feat:hover { border-color:var(--acc); }
.ftitle { font-weight:700; margin-bottom:.3rem; }
.feat ol { margin:.2rem 0 .5rem; padding-left:1.3rem; } .feat li { margin:.25rem 0; }

/* structure */
.cgrid { display:grid; grid-template-columns:repeat(auto-fill, minmax(300px, 1fr)); gap:14px; }
.ccard { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:.9rem 1.1rem; box-shadow:var(--shadow); cursor:pointer; display:flex; flex-direction:column; gap:.5rem; }
.ccard:hover { border-color:var(--acc); }
.ccard.missingpath { border:2px dashed var(--warn); }
.ctop { display:flex; align-items:baseline; gap:.5rem; flex-wrap:wrap; }
.cname { font-weight:700; font-size:1.05rem; }
.cpath { display:flex; flex-wrap:wrap; align-items:center; gap:.4rem; }
.pbad { color:var(--warn); background:var(--warnbg); border:1px solid var(--warn); border-radius:99px; font-size:.72rem; font-weight:700; padding:0 .5rem; }
.cresp { color:var(--fg); }
.crow { display:flex; flex-wrap:wrap; align-items:center; gap:.35rem; margin-top:.2rem; }
.crow .lbl { color:var(--muted); font-size:.8rem; }
.chip.bad { background:var(--warnbg); color:var(--warn); border:1px solid var(--warn); }
.kindtag { color:var(--muted); font-weight:700; font-size:.85rem; }

@media (max-width: 800px) {
  .top2, #lists { grid-template-columns:1fr; }
  .tabs { padding:0 14px; } .rmgoal { white-space:normal; }
  .drawer { width:100vw; }
  .grid { grid-template-columns:repeat(auto-fill, minmax(220px, 1fr)); }
  #page { padding:1rem 14px 3rem; } .bar { padding:.5rem 14px; }
}
EOF
printf '</style>\n</head>\n<body>\n'
cat <<'EOF'
<header id="top">
<div class="bar">
<h1 id="title" class="name"></h1>
<div class="tools"><button id="gapsbtn" type="button" hidden></button><button id="lang" type="button" hidden></button></div>
</div>
<nav class="tabs" id="tabs" role="tablist"></nav>
</header>
<main id="page">
<div id="trline" class="zh" hidden></div>
<div id="tab-progress" class="tabpanel">
<div id="scopebar" hidden></div>
<div class="top2">
<section class="box" id="what"></section>
<section class="box" id="prog"></section>
</div>
<div id="highline" hidden></div>
<div id="goals"></div>
<section id="lists"></section>
</div>
<div id="tab-roadmap" class="tabpanel" hidden></div>
<div id="tab-features" class="tabpanel" hidden></div>
<div id="tab-structure" class="tabpanel" hidden></div>
</main>
<div id="scrim" hidden></div>
<aside class="drawer" id="detail" role="dialog" aria-modal="true" aria-labelledby="dtitle"></aside>
<aside class="drawer" id="gaps" role="dialog" aria-modal="true" aria-labelledby="gtitle"></aside>
<noscript><p>This page draws itself with JavaScript, which is off here. 這個頁面要靠 JavaScript 才能顯示，目前已關閉。</p></noscript>
EOF
printf '<script type="application/json" id="data">\n'
printf '{"name":%s,"updated":%s,"now":%s,"head":%s,"trans":%s,"tlang":%s,"trfileOk":%s,'   "$(json_str "$NAME")" "$(json_str "$UPDATED")" "$(json_str "$NOW")" "$(json_str "$HEAD_SHORT")"   "$TRANS_JS" "$(json_str "$LANG2")" "$TRFILE_OK"
printf '"orphans":%s,"trfile":%s,' "$ORPHANS" "$(json_str "translations/$LANG2.md")"
printf '"problem":%s,' "$(units_json "$T/res.problem")"
printf '"focus":%s,' "$(units_json "$T/res.focus")"
printf '"ms":%s,' "$(idlist_json "$T/res.ms" "$MS_PAT" M '^$')"
printf '"goals":%s,' "$(idlist_json "$T/res.goals" "$GOAL_PAT" G '^M[0-9][0-9]*$')"
printf '"comps":%s,' "$(comps_json)"
printf '"ac":%s,' "$(acs_json)"
printf '"next":%s,' "$(units_json "$T/res.next")"
printf '"open":%s,' "$(units_json "$T/res.open")"
printf '"env":%s,' "$(env_json)"
printf '"changes":{"kind":%s,"n":%s,"total":%s,"items":%s},' "$(json_str "$CH_KIND")" "$(json_str "$CH_N")" "$CH_TOTAL" "$(commits_json "$T/res.changes")"
printf '"tl":%s,' "$(tl_json "$T/res.tl")"
printf '"hist":%s}\n' "$(commits_json "$T/res.hist")"
printf '</script>\n<script>\n'
cat <<'EOF'
(function () {
  "use strict";
  var D = JSON.parse(document.getElementById("data").textContent);
  var root = document.documentElement;
  var KEY = "sparkforge-progress-lang", TABKEY = "sparkforge-progress-tab";

  /* ---------- helpers: every file-derived string goes in through textContent ---------- */
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    // Commands, paths and ids stay as written when the browser translates the page.
    if (tag === "code") e.setAttribute("translate", "no");
    return e;
  }
  // Inline code is the one piece of markdown shown: `like this`.
  function rich(parent, s) {
    var parts = s.split("`");
    if (parts.length === 1 || parts.length % 2 === 0) { parent.appendChild(document.createTextNode(s)); return parent; }
    for (var i = 0; i < parts.length; i++) {
      if (i % 2 === 1) parent.appendChild(el("code", null, parts[i]));
      else if (parts[i]) parent.appendChild(document.createTextNode(parts[i]));
    }
    return parent;
  }
  // Both languages are in the page; the one not chosen is hidden by CSS.
  function bi(en, zh) {
    var f = document.createDocumentFragment();
    f.appendChild(rich(el("span", "en"), en));
    f.appendChild(rich(el("span", "zh"), zh));
    return f;
  }
  function biEl(tag, cls, en, zh) { var e = el(tag, cls); e.appendChild(bi(en, zh)); return e; }

  // A translation that is missing or out of date: the zh view shows the English
  // as a fallback. What says so never sits where line clamping can cut it off:
  // a leading EN tag on the unit, and a pill in the header of the card or box.
  //
  // A unit the file does not cover can be machine translated by the browser's
  // own Translator API (Chrome, Edge). That is kept per viewer in localStorage,
  // never written to the file, and marked as a machine translation: the file
  // holds what an agent or a person wrote.
  var MTKEY = "sparkforge-progress-mt:" + (root.getAttribute("data-tlang") || "zh-TW"), MT = {};
  try { MT = JSON.parse(localStorage.getItem(MTKEY) || "{}") || {}; } catch (e) { MT = {}; }
  function mtOf(u) { return D.trans && !u.tr && Object.prototype.hasOwnProperty.call(MT, u.en) ? MT[u.en] : null; }
  function isFb(u) { return D.trans && !u.tr && mtOf(u) === null; }
  function untrTag() { var t = el("span", "untr zh", "未翻譯"); t.title = "No current translation: showing the English"; t.setAttribute("translate", "no"); return t; }
  function zhSpan(u) {
    var mt = mtOf(u), z = el("span", isFb(u) ? "zh fb" : mt !== null ? "zh mt" : "zh");
    if (isFb(u)) {
      z.setAttribute("lang", "en");
      var t = el("span", "enTag", "EN"); t.setAttribute("translate", "no"); z.appendChild(t);
    } else if (mt !== null) {
      var g = el("span", "mtTag", "機器翻譯"); g.title = "Machine translated by this browser, not in the translation file"; g.setAttribute("translate", "no"); z.appendChild(g);
    }
    rich(z, u.tr || (mt !== null ? mt : u.en));
    return z;
  }
  function unitFrag(u) {
    var f = document.createDocumentFragment();
    f.appendChild(rich(el("span", "en"), u.en));
    var z = zhSpan(u);
    if (mtOf(u) !== null) z.title = u.en;
    f.appendChild(z);
    return f;
  }
  function unitDiv(u) { var d = el("div", "u"); d.appendChild(unitFrag(u)); return d; }
  // A unit whose original is worth keeping in reach: commit subjects and
  // evidence results. In the zh view a translated one has a small button that
  // shows the original English under it.
  function revealFrag(u) {
    var f = document.createDocumentFragment();
    f.appendChild(rich(el("span", "en"), u.en));
    var z = zhSpan(u);
    if (D.trans && (u.tr || mtOf(u) !== null)) {
      var b = el("button", "origbtn", "原文"); b.type = "button"; b.title = "Show the original English"; b.setAttribute("aria-expanded", "false");
      var o = el("span", "origtext"); o.hidden = true; rich(o, u.en);
      b.addEventListener("click", function (e) { e.stopPropagation(); o.hidden = !o.hidden; b.setAttribute("aria-expanded", o.hidden ? "false" : "true"); });
      z.appendChild(b); z.appendChild(o);
    }
    f.appendChild(z);
    return f;
  }
  // An example that is code, shown as it is written (it may itself contain backticks).
  function exampleBlock(lines) { var pre = el("pre"); pre.appendChild(el("code", null, lines.join("\n"))); return pre; }
  function clampN(n, a, b) { return Math.max(a, Math.min(b, n)); }

  /* ---------- ids: an item belongs to a criterion only where its id is written ---------- */
  function isW(c) { return c !== "" && /[A-Za-z0-9_]/.test(c); }
  // Whole-token match: AC1 is not found inside AC10, AC1x or xAC1.
  function hasTok(s, id) {
    var i = 0;
    while ((i = s.indexOf(id, i)) >= 0) {
      var b = i === 0 ? "" : s.charAt(i - 1), a = s.charAt(i + id.length);
      if (!isW(b) && !isW(a)) return true;
      i += 1;
    }
    return false;
  }

  /* ---------- computed state: nothing here is written by hand ---------- */
  // A criterion counts as evidenced only when its status line records evidence.
  function effOf(a) { return a.decl === "evidenced" ? (a.ev ? "evidenced" : "claimed") : (a.decl === "claimed" ? "claimed" : "none"); }
  // Tag goals with their milestones. m.goals gets the goals that name it and g.mids
  // the known milestones a goal names; references to unknown ones are returned.
  function linkMilestones(msList, goalList) {
    var by = {}, unknown = [];
    msList.forEach(function (m) { by[m.id] = m; m.goals = []; });
    goalList.forEach(function (g) {
      g.mids = [];
      g.refs.forEach(function (r) {
        if (by[r]) { if (g.mids.indexOf(r) < 0) { g.mids.push(r); by[r].goals.push(g); } }
        else unknown.push({ goal: g, ref: r });
      });
    });
    return unknown;
  }
  // planned: no goal names the milestone. done: it has criteria and every one is
  // evidenced. in progress: anything else. A criterion belongs to a milestone through
  // its goals, and one whose goals span milestones counts toward each.
  function milestoneState(m) {
    var seen = {}, list = [];
    m.goals.forEach(function (g) { g.acs.forEach(function (a) { if (!seen[a.id]) { seen[a.id] = 1; list.push(a); } }); });
    var ev = list.filter(function (a) { return a.eff === "evidenced"; }).length;
    var state = !m.goals.length ? "planned" : (list.length && ev === list.length ? "done" : "progress");
    return { state: state, acs: list, ev: ev, total: list.length };
  }
  // The current milestone is the first, in listed order, that is neither done nor planned.
  function currentMilestone(list) {
    for (var i = 0; i < list.length; i++) { var s = list[i].info.state; if (s !== "done" && s !== "planned") return list[i]; }
    return null;
  }
  function subj(c) { return { en: c.s, tr: c.tr, st: c.st }; }

  /* ---------- model ---------- */
  // How a gap is ranked, so the panel can be read top down:
  //   high    an incomplete or false state shown as if it were complete or true:
  //           evidenced with no evidence, a status line for an id that is not in
  //           `SPEC.md`, a criterion naming a goal or a goal naming a milestone that
  //           `SPEC.md` does not list, a component whose path is not on disk or that
  //           uses one that does not exist, a status line that cannot be read, an id
  //           used twice (one card silently lost)
  //   medium  something needed to finish the picture is missing: a criterion
  //           with no goal, a goal with no criterion or no milestone, no status
  //           line, no Means or Try, claimed without evidence, a component with no
  //           path, an empty dev command, no problem, goals or criteria at all,
  //           a missing translation file
  //   low     housekeeping: empty install or build, empty focus or next steps,
  //           untranslated units, orphaned translations, a lost marker commit
  // Within a rank the order is the order the checks run in.
  var SEV = ["high", "medium", "low"];
  var gaps = [];
  function gap(sev, en, zh, ref) { gaps.push({ sev: sev, en: en, zh: zh, ref: ref || null }); }
  function bt(s) { return "`" + s + "`"; }

  var msList = [], msBy = {}, goals = [], acs = [], goalBy = {}, acBy = {}, comps = [], compBy = {};
  D.ms.forEach(function (m) {
    if (m.dup) { gap("high", bt(m.id) + " appears more than once under `Milestones` in `SPEC.md`; only the first is shown.", bt(m.id) + " 在 `SPEC.md` 的 `Milestones` 裡重複出現，只顯示第一個。"); return; }
    msBy[m.id] = m; msList.push(m);
    if (m.impl) gap("medium", "A milestone in `SPEC.md` has no id written; it is numbered " + bt(m.id) + " by position.", "`SPEC.md` 裡有一個里程碑沒有寫編號，依位置編為 " + bt(m.id) + "。");
  });
  var hasMs = msList.length > 0;
  D.goals.forEach(function (g) {
    if (g.dup) { gap("high", bt(g.id) + " appears more than once under `Goals` in `SPEC.md`; only the first is shown.", bt(g.id) + " 在 `SPEC.md` 的 `Goals` 裡重複出現，只顯示第一個。"); return; }
    goalBy[g.id] = g; goals.push(g); g.acs = [];
    if (g.impl) gap("medium", "A goal in `SPEC.md` has no id written; it is numbered " + bt(g.id) + " by position.", "`SPEC.md` 裡有一個目標沒有寫編號，依位置編為 " + bt(g.id) + "。", "g:" + g.id);
  });
  D.ac.acs.forEach(function (a) {
    if (a.dup) { gap("high", bt(a.id) + " appears more than once under `Acceptance criteria` in `SPEC.md`; only the first is shown.", bt(a.id) + " 在 `SPEC.md` 的 `Acceptance criteria` 裡重複出現，只顯示第一個。"); return; }
    acBy[a.id] = a; acs.push(a);
    a.eff = effOf(a);
    a.gids = []; a.commits = []; a.nexts = [];
    a.title = a.means.length ? a.means[0] : a;
  });

  // goal -> criteria: the criterion names its goal.
  acs.forEach(function (a) {
    a.goals.forEach(function (gid) {
      if (goalBy[gid]) { if (a.gids.indexOf(gid) < 0) { a.gids.push(gid); goalBy[gid].acs.push(a); } }
      else gap("high", bt(a.id) + " names goal " + bt(gid) + ", which `SPEC.md` does not list.", bt(a.id) + " 指名的目標 " + bt(gid) + " 不在 `SPEC.md` 裡。", "a:" + a.id);
    });
  });
  // milestone -> goals: the goal names its milestone. State is computed from the criteria.
  var unknownRefs = linkMilestones(msList, goals);
  msList.forEach(function (m) { m.info = milestoneState(m); });
  var current = currentMilestone(msList);
  var unassigned = hasMs ? goals.filter(function (g) { return !g.mids.length; }) : [];

  // commits and next steps belong to a criterion when its id is in the subject or the entry.
  D.hist.forEach(function (c) { acs.forEach(function (a) { if (hasTok(c.s, a.id)) a.commits.push(c); }); });
  var changes = D.changes.items.map(function (c) { return { c: c, ids: acs.filter(function (a) { return hasTok(c.s, a.id); }).map(function (a) { return a.id; }) }; });
  var nexts = D.next.filter(function (u) { return u.k === "li"; }).map(function (u) {
    var k = { u: u, ids: acs.filter(function (a) { return hasTok(u.en, a.id); }).map(function (a) { return a.id; }) };
    k.ids.forEach(function (id) { acBy[id].nexts.push(u); });
    return k;
  });

  // components: used by is computed from the uses lists
  D.comps.forEach(function (c) {
    if (c.dup) { gap("high", bt(c.id) + " appears more than once under `Components` in `SPEC.md`; only the first is shown.", bt(c.id) + " 在 `SPEC.md` 的 `Components` 裡重複出現，只顯示第一個。"); return; }
    compBy[c.id] = c; comps.push(c); c.usedBy = [];
  });
  comps.forEach(function (c) { c.uses.forEach(function (u) { if (compBy[u] && compBy[u].usedBy.indexOf(c.id) < 0) compBy[u].usedBy.push(c.id); }); });
  var highs = 0;

  /* ---------- gaps: what is missing, named ---------- */
  if (!D.problem.length) gap("medium", "`SPEC.md` has nothing under `Problem`: the spec gate has not run.", "`SPEC.md` 的 `Problem` 是空的：規格門還沒跑過。");
  if (!goals.length) gap("medium", "`SPEC.md` lists no goals (list items under `Goals`).", "`SPEC.md` 沒有列出任何目標（`Goals` 底下的清單項目）。");
  if (!acs.length) gap("medium", "`SPEC.md` lists no acceptance criteria (list items under `Acceptance criteria`).", "`SPEC.md` 沒有列出任何驗收條件（`Acceptance criteria` 底下的清單項目）。");
  // Up to two of the same kind are named one by one; more become one line that
  // lists them, so the panel reads as a short list of problems, not a wall.
  function fmt(s, a, n) { return s.replace("%", function () { return a; }).replace("#", function () { return n; }); }
  function group(sev, ids, ref, one, many) {
    if (!ids.length) return;
    if (ids.length <= 2) { ids.forEach(function (id) { gap(sev, fmt(one[0], bt(id), 1), fmt(one[1], bt(id), 1), ref + id); }); return; }
    gap(sev, fmt(many[0], ids.join(", "), ids.length), fmt(many[1], ids.join(", "), ids.length), ref + ids[0]);
  }
  unknownRefs.forEach(function (u) { gap("high", bt(u.goal.id) + " names milestone " + bt(u.ref) + ", which `SPEC.md` does not list.", bt(u.goal.id) + " 指名的里程碑 " + bt(u.ref) + " 不在 `SPEC.md` 裡。", "g:" + u.goal.id); });
  if (hasMs) group("medium", goals.filter(function (g) { return !g.refs.length; }).map(function (g) { return g.id; }), "g:",
    ["% has no milestone tag, so it is in no milestone.", "% 沒有標上里程碑，不屬於任何里程碑。"],
    ["# goals have no milestone tag, so they are in no milestone: %.", "# 個目標沒有標上里程碑，不屬於任何里程碑：%。"]);
  group("medium", goals.filter(function (g) { return !g.acs.length; }).map(function (g) { return g.id; }), "g:",
    ["% has no acceptance criteria: no criterion names it.", "% 沒有驗收條件：沒有任何條件指名它。"],
    ["# goals have no acceptance criteria, because no criterion names them: %.", "# 個目標沒有驗收條件，因為沒有任何條件指名它們：%。"]);
  acs.forEach(function (a) {
    var r = "a:" + a.id;
    if (a.impl) gap("medium", "A criterion in `SPEC.md` has no id written; it is numbered " + bt(a.id) + " by position.", "`SPEC.md` 裡有一項驗收條件沒有寫編號，依位置編為 " + bt(a.id) + "。", r);
    if (a.decl === "evidenced" && !a.ev) gap("high", bt(a.id) + " is marked evidenced but records no evidence, so it counts as claimed.", bt(a.id) + " 標為有證據，但沒有記錄證據，因此算作僅宣稱。", r);
    else if (a.decl === "claimed" && !a.ev) gap("medium", bt(a.id) + " is claimed but records no evidence.", bt(a.id) + " 是僅宣稱，而且沒有記錄證據。", r);
  });
  if (goals.length) group("medium", acs.filter(function (a) { return !a.gids.length; }).map(function (a) { return a.id; }), "a:",
    ["% names no goal.", "% 沒有指名任何目標。"],
    ["# criteria name no goal: %.", "# 項驗收條件沒有指名任何目標：%。"]);
  group("medium", acs.filter(function (a) { return a.decl === "missing"; }).map(function (a) { return a.id; }), "a:",
    ["% has no status line in `STATE.md`.", "% 在 `STATE.md` 沒有狀態行。"],
    ["# criteria have no status line in `STATE.md`, so they show as not started: %.", "# 項驗收條件在 `STATE.md` 沒有狀態行，因此顯示為未開始：%。"]);
  group("medium", acs.filter(function (a) { return !a.means.length || !a.tries.length; }).map(function (a) { return a.id; }), "a:",
    ["% lacks its Means or Try line, so the spec does not explain it in plain language yet.", "% 缺少「意思」或「自己試試」，規格還沒有用白話說明它。"],
    ["# criteria lack a Means or Try line, so the spec does not explain them in plain language yet: %.", "# 項驗收條件缺少「意思」或「自己試試」，規格還沒有用白話說明它們：%。"]);
  D.ac.unknown.slice().sort().forEach(function (id) { gap("high", "`STATE.md` has a status line for " + bt(id) + ", which `SPEC.md` does not list.", "`STATE.md` 有 " + bt(id) + " 的狀態行，但 `SPEC.md` 沒有這一項。"); });
  D.ac.bad.forEach(function (t) { gap("high", "Unreadable status line: " + bt(t.replace(/`/g, "'")) + " (expected `id: evidenced|claimed|not started - evidence (date)`).", "無法解讀的狀態行：" + bt(t.replace(/`/g, "'")) + "（格式：`id: evidenced|claimed|not started - 證據 (日期)`）。"); });
  comps.forEach(function (c) {
    var r = "c:" + c.id;
    if (c.impl) gap("medium", "A component in `SPEC.md` has no id written; it is numbered " + bt(c.id) + " by position.", "`SPEC.md` 裡有一個元件沒有寫編號，依位置編為 " + bt(c.id) + "。", r);
    if (!c.path) gap("medium", bt(c.id) + " has no path written, so nothing can check that it exists.", bt(c.id) + " 沒有寫路徑，所以無法確認它是否存在。", r);
    else if (!c.exists) gap("high", bt(c.id) + " says its path is " + bt(c.path) + ", which does not exist in the project.", bt(c.id) + " 寫的路徑 " + bt(c.path) + " 在專案裡不存在。", r);
    if (c.badUses) gap("high", bt(c.id) + "'s uses list has text that is not an id: " + bt(c.badUses.replace(/`/g, "'")) + ". Nothing was drawn from that text; write bare ids only.", bt(c.id) + " 的 uses 清單含有不是編號的文字：" + bt(c.badUses.replace(/`/g, "'")) + "。這段文字沒有被畫成任何連線；請只寫編號。", r);
    c.uses.forEach(function (u) { if (!compBy[u]) gap("high", bt(c.id) + " uses " + bt(u) + ", which is not a component in `SPEC.md`.", bt(c.id) + " 使用的 " + bt(u) + " 不是 `SPEC.md` 裡的元件。", r); });
  });
  [["dev", true], ["install", false], ["build", false]].forEach(function (p) {
    var e = D.env[p[0]];
    if (!e.p) { if (p[1]) gap("medium", "`dev` is not listed in `AGENTS.md`, so nothing says how to start the project.", "`AGENTS.md` 裡沒有 `dev`，沒有任何地方說明怎麼啟動專案。"); }
    else if (e.v === "") gap(p[1] ? "medium" : "low", bt(p[0]) + " command is empty in `AGENTS.md`: not established yet.", "`AGENTS.md` 的 " + bt(p[0]) + " 指令是空的：尚未確立。");
  });
  if (!D.focus.length) gap("low", "`STATE.md` has nothing under `Current Focus`.", "`STATE.md` 的 `Current Focus` 是空的。");
  if (!nexts.length) gap("low", "`STATE.md` has no `Next Steps` (list items).", "`STATE.md` 沒有 `Next Steps`（清單項目）。");
  if (D.changes.kind === "lost") gap("low", "The marker commit is no longer in this repository (history was rewritten?), so the changes list shows the last commits instead.", "標記的 commit 已不在這個 repository（歷史被改寫過？），因此變更清單改為顯示最近的 commit。");
  if (D.trans && !D.trfileOk) gap("medium", bt(D.trfile) + " does not exist, so every unit shows in English as untranslated.", bt(D.trfile) + " 不存在，所有單位都以英文顯示為未翻譯。");
  // Every distinct unit the page shows, and the ones with no current translation
  // in the file. A machine translation does not take a unit off that list.
  var trTotal = 0, trMiss = 0, trUnits = [];
  (function () {
    var seen = {};
    function count(u) { if (!u || seen[u.en]) return; seen[u.en] = 1; trTotal++; if (D.trans && !u.tr) { trMiss++; trUnits.push(u); } }
    [D.problem, D.focus, D.ms, D.goals, D.next, D.open].forEach(function (l) { l.forEach(count); });
    D.ac.acs.forEach(function (a) { count(a); a.means.forEach(count); a.tries.forEach(count); if (a.evr) count(a.evr); });
    D.comps.forEach(function (c) { count(c.name); count(c.resp); c.commits.forEach(function (k) { count(subj(k)); }); });
    D.changes.items.forEach(function (c) { count(subj(c)); });
    D.hist.forEach(function (c) { count(subj(c)); });
    D.tl.forEach(function (c) { count(subj(c)); c.body.forEach(count); });
  })();
  if (D.trans && trMiss) gap("low", trMiss + " of " + trTotal + " displayed units have no current translation; `scripts/progress.sh --untranslated` lists them.", trTotal + " 段中 " + trMiss + " 段沒有最新的翻譯；`scripts/progress.sh --untranslated` 會列出它們。");
  if (D.trans && D.orphans) gap("low", D.orphans + " translation(s) in " + bt(D.trfile) + " match no displayed unit; `scripts/progress.sh --untranslated` lists them to prune.", bt(D.trfile) + " 裡有 " + D.orphans + " 筆翻譯對不到任何顯示的單位；`scripts/progress.sh --untranslated` 會列出，請清掉。");
  gaps.forEach(function (g) { if (g.sev === "high") highs++; });

  /* ---------- clamped text: long text is cut, the rest one click away ---------- */
  var clamps = [];
  function clampBox(content, lines) {
    var wrap = el("div", "cw"), box = el("div", "cl" + (lines ? " l" + lines : ""));
    box.appendChild(content);
    var btn = el("button", "more"); btn.type = "button"; btn.hidden = true;
    var m = el("span", "lm"); m.appendChild(bi("more", "展開"));
    var l = el("span", "ll"); l.appendChild(bi("less", "收合"));
    btn.appendChild(m); btn.appendChild(l);
    btn.addEventListener("click", function (e) { e.stopPropagation(); wrap.classList.toggle("open"); refreshClamps(); });
    wrap.appendChild(box); wrap.appendChild(btn);
    clamps.push({ wrap: wrap, box: box, btn: btn });
    return wrap;
  }
  function refreshClamps() {
    clamps = clamps.filter(function (c) { return document.body.contains(c.wrap); });
    clamps.forEach(function (c) {
      if (c.wrap.classList.contains("open")) c.btn.hidden = false;
      else c.btn.hidden = !(c.box.scrollHeight > c.box.clientHeight + 1);
    });
  }

  /* ---------- drawers ---------- */
  var scrim = document.getElementById("scrim"), detail = document.getElementById("detail"), gapsEl = document.getElementById("gaps");
  var opener = null, shown = null;
  function openDrawer(d, from) {
    closeDrawers(true);
    opener = from || document.activeElement; shown = d;
    d.classList.add("open"); scrim.hidden = false;
    var x = d.querySelector(".close"); if (x) x.focus();
  }
  function closeDrawers(keepFocus) {
    [detail, gapsEl].forEach(function (d) { d.classList.remove("open"); });
    scrim.hidden = true; shown = null;
    if (!keepFocus && opener && opener.focus) { try { opener.focus(); } catch (e) {} }
  }
  scrim.addEventListener("click", function () { closeDrawers(); });
  document.addEventListener("keydown", function (e) { if (e.key === "Escape" && shown) closeDrawers(); });
  function closeBtn() { var b = el("button", "close"); b.type = "button"; b.appendChild(bi("Close", "關閉")); b.addEventListener("click", function () { closeDrawers(); }); return b; }
  function flash(node) { node.classList.remove("flash"); void node.offsetWidth; node.classList.add("flash"); setTimeout(function () { node.classList.remove("flash"); }, 1700); }

  /* ---------- the header ---------- */
  document.getElementById("title").textContent = D.name;
  function copyText(text, done) {
    function fallback() {
      try { var t = el("textarea"); t.value = text; t.style.position = "fixed"; t.style.opacity = "0"; document.body.appendChild(t); t.select(); document.execCommand("copy"); document.body.removeChild(t); done(); } catch (y) {}
    }
    try { navigator.clipboard.writeText(text).then(done, fallback); } catch (x) { fallback(); }
  }

  // What the file lacks can be filled two ways, both offered here: an agent
  // writes the translation file (the copied instruction works in any agent),
  // or this browser machine translates for this viewer only.
  var AGENT_ASK = "Fill the progress page's translations: run `scripts/progress.sh --untranslated`, " +
    "write each unit it lists into " + D.trfile + " under its `## <hash>` line, keeping every `inline code` span exactly as written, " +
    "delete the entries it lists as orphaned, then open the page with scripts/progress.sh.";
  function tlCode() {
    var l = root.getAttribute("data-tlang") || "zh-TW";
    if (/^zh-(TW|HK|MO|Hant)/i.test(l)) return "zh-Hant";
    if (/^zh/i.test(l)) return "zh";
    return l;
  }
  function mtTodo() { return trUnits.filter(function (u) { return mtOf(u) === null; }); }
  // Inline code is never sent: only the text between code spans is translated,
  // and a backtick the translator returns is dropped so the spans stay where they were.
  function machineTranslate(btn) {
    var todo = mtTodo(), opts = { sourceLanguage: "en", targetLanguage: tlCode() };
    if (!todo.length) return;
    if (btn) btn.disabled = true;
    function say(s) { if (btn) btn.textContent = s; }
    function save() { try { localStorage.setItem(MTKEY, JSON.stringify(MT)); } catch (e) {} }
    var o = {}; for (var k in opts) o[k] = opts[k];
    o.monitor = function (m) { m.addEventListener("downloadprogress", function (e) { say("下載翻譯模型 " + Math.round((e.loaded || 0) * 100) + "%"); }); };
    say("準備翻譯…（第一次要先下載翻譯模型，約一分鐘）");
    return Promise.resolve().then(function () { return Translator.create(o); }).then(function (tr) {
      var i = 0;
      function next() {
        if (i >= todo.length) return;
        var u = todo[i++];
        say("翻譯中 " + i + " / " + todo.length);
        var parts = u.en.split("`");
        if (parts.length % 2 === 0) parts = [u.en];
        return Promise.all(parts.map(function (p, j) {
          if (j % 2 === 1 || !/[A-Za-z]/.test(p)) return p;
          return tr.translate(p).then(function (r) { return String(r).replace(/`/g, "'"); });
        })).then(function (out) { MT[u.en] = out.join("`"); }).then(next);
      }
      return next();
    // Parts of the page are drawn once, at load, so it reloads to show the
    // translations; the address keeps the tab and scope.
    }).then(function () { save(); location.reload(); }, function (err) {
      save();
      if (btn) { btn.disabled = false; btn.textContent = "瀏覽器翻譯失敗，可再試一次"; btn.title = String(err && err.message || err); }
    });
  }
  function renderTrline() {
    var t = document.getElementById("trline");
    t.textContent = "";
    if (!D.trans || !trMiss) { t.hidden = true; return; }
    var left = mtTodo().length, mtN = trMiss - left, p = el("div");
    rich(p, trTotal + " 段中 " + trMiss + " 段在 `" + D.trfile + "` 裡沒有翻譯" +
      (mtN ? "；其中 " + mtN + " 段由這個瀏覽器機器翻譯，標上「機器翻譯」" : "") +
      (left ? "；" + left + " 段以淡色英文並標上 EN 顯示。" : "。"));
    t.appendChild(p);
    var row = el("div", "trbtns");
    var a = el("button", null, "複製給 agent 的翻譯指令"); a.type = "button";
    a.title = "Copies an instruction that any agent can follow to write " + D.trfile;
    a.addEventListener("click", function () { copyText(AGENT_ASK, function () { a.textContent = "已複製，貼給 agent 即可"; setTimeout(function () { a.textContent = "複製給 agent 的翻譯指令"; }, 2000); }); });
    row.appendChild(a);
    if (left && typeof self.Translator !== "undefined") {
      var m = el("button", null, "用瀏覽器翻譯剩下的 " + left + " 段"); m.type = "button"; m.id = "mtbtn";
      m.title = "Machine translation by this browser's built-in translator; kept in this browser only";
      m.addEventListener("click", function () { machineTranslate(m); });
      row.appendChild(m);
    }
    t.appendChild(row);
    t.hidden = false;
  }
  renderTrline();

  function boxHead(s, en, zh, units) {
    var h = el("h2"); h.appendChild(bi(en, zh));
    if (units && units.some(isFb)) { h.appendChild(document.createTextNode(" ")); h.appendChild(untrTag()); }
    s.appendChild(h);
    return s;
  }
  function sub(s, en, zh, units) {
    var h = el("h3"); h.appendChild(bi(en, zh));
    if (units && units.some(isFb)) { h.appendChild(document.createTextNode(" ")); h.appendChild(untrTag()); }
    s.appendChild(h);
  }
  // The start commands, with copy buttons; used by the progress tab and the features tab.
  function startRows(s) {
    [["dev", true], ["install", false], ["build", false]].forEach(function (p) {
      var e = D.env[p[0]];
      if (!e.p && !p[1]) return;
      var row = el("div", "cmd");
      row.appendChild(el("code", "k", p[0]));
      if (!e.p) row.appendChild(biEl("span", "gapname", "not listed in `AGENTS.md`", "`AGENTS.md` 裡沒有這一項"));
      else if (e.v === "") row.appendChild(biEl("span", "gapname", "empty: not established yet", "空白：尚未確立"));
      else {
        row.appendChild(el("code", null, e.v));
        var b = el("button"); b.type = "button"; b.appendChild(bi("copy", "複製"));
        b.addEventListener("click", function () {
          copyText(e.v, function () { b.textContent = "✓"; setTimeout(function () { b.textContent = ""; b.appendChild(bi("copy", "複製")); }, 1200); });
        });
        row.appendChild(b);
      }
      s.appendChild(row);
    });
  }
  // A long section opens on its first sentence; the whole text, one paragraph
  // per unit, is one click away. The sentence is cut from whichever text the
  // view shows, so the zh view cuts the translation, not the English.
  function firstSentence(s, zh) {
    var m = zh ? s.match(/^[\s\S]*?[。！？](?=[^。！？]|$)/) : s.match(/^[\s\S]*?[.!?](?=\s+["'(A-Z0-9]|$)/);
    return m ? m[0] : s;
  }
  function leadBlock(units) {
    var wrap = el("div", "lead"), u = units[0], mt = mtOf(u), zt = u.tr || mt;
    var p = el("p", "leadtext");
    var en1 = firstSentence(u.en, false);
    p.appendChild(rich(el("span", "en"), en1));
    var z = el("span", D.trans && !zt ? "zh fb" : "zh");
    if (D.trans && !zt) { z.setAttribute("lang", "en"); var t = el("span", "enTag", "EN"); t.setAttribute("translate", "no"); z.appendChild(t); }
    else if (mt !== null) { var g = el("span", "mtTag", "機器翻譯"); g.setAttribute("translate", "no"); z.appendChild(g); }
    rich(z, zt ? firstSentence(zt, true) : en1);
    p.appendChild(z);
    wrap.appendChild(p);
    if (units.length === 1 && en1.length >= u.en.trim().length) return wrap;
    var full = el("div", "leadfull"); full.hidden = true;
    units.forEach(function (x) { full.appendChild(unitDiv(x)); });
    var b = el("button", "more"); b.type = "button";
    function label() { b.textContent = ""; b.appendChild(full.hidden ? bi("Read all", "看完整內容") : bi("Less", "收合")); }
    b.addEventListener("click", function () { full.hidden = !full.hidden; p.hidden = !full.hidden; label(); });
    label();
    wrap.appendChild(full); wrap.appendChild(b);
    return wrap;
  }
  (function what() {
    var s = boxHead(document.getElementById("what"), "What this is", "這是什麼");
    sub(s, "The problem", "要解決的問題", D.problem);
    if (!D.problem.length) { var e = el("p", "empty"); e.appendChild(bi("Not written: the spec gate has not run.", "還沒寫：規格門還沒跑過。")); s.appendChild(e); }
    else s.appendChild(leadBlock(D.problem));
    sub(s, "Current focus", "目前焦點", D.focus);
    if (!D.focus.length) { var e2 = el("p", "empty"); e2.appendChild(bi("Nothing written under Current Focus yet.", "目前焦點還沒有內容。")); s.appendChild(e2); }
    else s.appendChild(leadBlock(D.focus));
    sub(s, "How to start", "怎麼啟動");
    startRows(s);
  })();

  /* ---------- the progress tab: a scope, then goal sections and their cards ---------- */
  var ICON = { evidenced: "✓", claimed: "◐", none: "○" };
  var LABEL = { evidenced: ["evidenced", "有證據"], claimed: ["claimed", "僅宣稱"], none: ["not started", "未開始"] };
  var SL = { done: ["done", "已完成"], progress: ["in progress", "進行中"], planned: ["planned", "規劃中"] };
  var cards = {};
  // scope: "all", a milestone id, or "unassigned". Without milestones it is always "all".
  var scope = hasMs && current ? current.id : "all";
  function scopeGoalsOf(sc) { if (!hasMs || sc === "all") return goals; if (sc === "unassigned") return unassigned; return msBy[sc] ? msBy[sc].goals : goals; }
  function scopeAcsOf(sc) {
    if (!hasMs || sc === "all") return acs;
    var seen = {}, out = [];
    scopeGoalsOf(sc).forEach(function (g) { g.acs.forEach(function (a) { if (!seen[a.id]) { seen[a.id] = 1; out.push(a); } }); });
    return out;
  }
  function setScope(sc) { scope = sc; renderProgress(); writeHash(); refreshClamps(); }

  function renderScopebar() {
    var bar = document.getElementById("scopebar");
    bar.textContent = "";
    if (!hasMs) { bar.hidden = true; return; }
    bar.hidden = false;
    bar.appendChild(biEl("span", "lbl", "Showing", "顯示範圍"));
    function chip(key, node, state) {
      var b = el("button", "scopechip" + (state ? " st-" + state : "")); b.type = "button"; b.setAttribute("aria-pressed", scope === key ? "true" : "false");
      b.appendChild(node);
      b.addEventListener("click", function () { setScope(key); });
      bar.appendChild(b);
    }
    msList.forEach(function (m) {
      var n = document.createDocumentFragment(); n.appendChild(el("span", "id", m.id));
      if (m === current) n.appendChild(biEl("span", "curdot", "now", "目前"));
      chip(m.id, n, m.info.state);
    });
    chip("all", biEl("span", "txt", "All", "全部"));
    if (unassigned.length) chip("unassigned", biEl("span", "txt", "Unassigned", "未分配"));
  }
  function renderProgressBox() {
    var s = document.getElementById("prog"); s.textContent = "";
    boxHead(s, "Progress", "進度");
    if (hasMs) {
      var line = el("div", "scopeline");
      line.appendChild(bi("Scope: ", "範圍："));
      if (scope === "all") line.appendChild(bi("the whole project", "整個專案"));
      else if (scope === "unassigned") line.appendChild(bi("goals with no milestone", "沒有里程碑的目標"));
      else { line.appendChild(el("span", "id", scope)); line.appendChild(document.createTextNode(" ")); line.appendChild(unitFrag(msBy[scope])); }
      s.appendChild(line);
    }
    var list = scopeAcsOf(scope), total = list.length, counts = { evidenced: 0, claimed: 0, none: 0 };
    list.forEach(function (a) { counts[a.eff]++; });
    if (!total) { var e = el("p", "empty"); e.appendChild(bi("No acceptance criteria here yet.", "這裡還沒有驗收條件。")); s.appendChild(e); return; }
    var big = el("div", "big"); big.appendChild(bi(counts.evidenced + " of " + total + " evidenced", total + " 項中 " + counts.evidenced + " 項有證據")); s.appendChild(big);
    var bar = el("div", "bar3");
    [["k1", counts.evidenced], ["k2", counts.claimed]].forEach(function (p) { var i = el("i", p[0]); i.style.width = (100 * p[1] / total) + "%"; bar.appendChild(i); });
    s.appendChild(bar);
    var lg = el("div", "counts");
    var t1 = el("span", "t1"); t1.appendChild(bi("✓ " + counts.evidenced + " evidenced", "✓ " + counts.evidenced + " 項有證據"));
    var t2 = el("span", "t2"); t2.appendChild(bi("◐ " + counts.claimed + " claimed", "◐ " + counts.claimed + " 項僅宣稱"));
    var t3 = el("span", "t3"); t3.appendChild(bi("○ " + counts.none + " not started", "○ " + counts.none + " 項未開始"));
    lg.appendChild(t1); lg.appendChild(t2); lg.appendChild(t3); s.appendChild(lg);
  }

  function openAC(id) {
    var a = acBy[id]; if (!a) return;
    closeDrawers(true);
    if (tabName !== "progress") showTab("progress");
    if (!(cards[id] && cards[id].length)) setScope("all");
    var c = cards[id] && cards[id][0];
    if (c) { c.scrollIntoView({ block: "center" }); flash(c); }
    renderDetail(a); openDrawer(detail, c);
  }
  function card(a) {
    var d = el("div", "acard s-" + a.eff);
    d.tabIndex = 0; d.setAttribute("role", "button"); d.setAttribute("data-ac", a.id);
    var top = el("div", "top");
    top.appendChild(el("span", "ico", ICON[a.eff]));
    top.appendChild(biEl("span", "lab", LABEL[a.eff][0], LABEL[a.eff][1]));
    if (isFb(a.title)) top.appendChild(untrTag());
    d.appendChild(top);
    var t = el("div", "title"), tb = el("div", "cl"); tb.appendChild(unitDiv(a.title)); t.appendChild(tb); d.appendChild(t);
    var f = el("div", "foot"); f.appendChild(el("span", "id", a.id)); d.appendChild(f);
    d.addEventListener("click", function () { renderDetail(a); openDrawer(detail, d); });
    d.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); renderDetail(a); openDrawer(detail, d); } });
    (cards[a.id] = cards[a.id] || []).push(d);
    return d;
  }
  function section(id, head, list, emptyEn, emptyZh) {
    var s = el("section", "goal"); s.id = id;
    s.appendChild(head);
    if (!list.length) { var e = el("p", "empty"); e.appendChild(bi(emptyEn, emptyZh)); s.appendChild(e); }
    else { var g = el("div", "grid"); list.forEach(function (a) { g.appendChild(card(a)); }); s.appendChild(g); }
    return s;
  }
  function renderGoals() {
    var host = document.getElementById("goals"); host.textContent = "";
    var sg = scopeGoalsOf(scope);
    // Goals with criteria first, in the order SPEC.md gives them; then the criteria that
    // name no goal; then the goals nothing names yet, so that a project whose criteria
    // carry no goal ids still opens on its criteria.
    var used = sg.filter(function (g) { return g.acs.length; }), unused = sg.filter(function (g) { return !g.acs.length; });
    function goalSection(g) {
      var h = el("div", "gh");
      h.appendChild(el("span", "gid", g.id));
      var t = el("div", "gt"); t.appendChild(clampBox(unitDiv(g), 2)); if (isFb(g)) { t.appendChild(untrTag()); } h.appendChild(t);
      var ev = g.acs.filter(function (a) { return a.eff === "evidenced"; }).length;
      if (g.acs.length) { var st = el("div", "gs"); st.appendChild(bi(ev + " of " + g.acs.length + " evidenced", g.acs.length + " 項中 " + ev + " 項有證據")); h.appendChild(st); }
      return section("sec-" + g.id, h, g.acs, "No acceptance criterion names " + g.id + " yet.", "還沒有任何驗收條件指名 " + g.id + "。");
    }
    // Goals that no criterion names are one compact list, not a section each
    // saying it is empty.
    function goalList(list, en, zh) {
      var box = el("section", "glist");
      var h = el("h3"); h.appendChild(bi(en, zh)); box.appendChild(h);
      var ul = el("ul");
      list.forEach(function (g) {
        var li = el("li"); li.id = "sec-" + g.id;
        li.appendChild(el("span", "gid", g.id));
        var t = el("div", "gt"); t.appendChild(unitDiv(g)); if (isFb(g)) t.appendChild(untrTag()); li.appendChild(t);
        ul.appendChild(li);
      });
      box.appendChild(ul);
      return box;
    }
    function critHead(list, en, zh) {
      var h = el("div", "gh"); var t = el("div", "gt"); t.appendChild(bi(en, zh)); h.appendChild(t);
      var ev = list.filter(function (a) { return a.eff === "evidenced"; }).length;
      var st = el("div", "gs"); st.appendChild(bi(ev + " of " + list.length + " evidenced", list.length + " 項中 " + ev + " 項有證據")); h.appendChild(st);
      return h;
    }
    var rest = (!hasMs || scope === "all") ? acs.filter(function (a) { return !a.gids.length; }) : [];
    if (!used.length && rest.length) {
      // Nothing links a criterion to a goal: the goals as a list, the criteria as one grid.
      if (unused.length) host.appendChild(goalList(unused, "Goals", "目標"));
      var s1 = section("sec-none", critHead(rest, "Acceptance criteria", "驗收標準"), rest);
      s1.insertBefore(biEl("p", "gnote", "These criteria do not say which goal they serve, so they are listed apart from the goals.", "這些驗收標準沒有註明屬於哪個目標，所以和目標分開列出。"), s1.children[1]);
      host.appendChild(s1);
    } else {
      used.forEach(function (g) { host.appendChild(goalSection(g)); });
      if (rest.length) {
        var s2 = section("sec-none", critHead(rest, "Other criteria", "其他驗收標準"), rest);
        s2.insertBefore(biEl("p", "gnote", "These name no goal, or one that is not listed.", "這些沒有註明目標，或註明的目標不存在。"), s2.children[1]);
        host.appendChild(s2);
      }
      if (unused.length) host.appendChild(goalList(unused, "Goals no criterion covers yet", "還沒有驗收標準的目標"));
    }
    if (!sg.length && !rest.length) {
      var e = el("p", "empty");
      if (!hasMs && !goals.length && !acs.length) e.appendChild(bi("`SPEC.md` lists no goals or acceptance criteria yet.", "`SPEC.md` 還沒有列出目標或驗收條件。"));
      else e.appendChild(bi("No goals here yet: the spec gate adds them when work on this milestone starts.", "這裡還沒有目標：開始做這個里程碑時，規格門會補上。"));
      host.appendChild(e);
    }
  }
  function renderProgress() { cards = {}; renderScopebar(); renderProgressBox(); renderGoals(); }

  /* ---------- the criterion detail panel ---------- */
  function dsec(en, zh) { var s = el("div", "dsec"); var h = el("h3"); h.appendChild(bi(en, zh)); s.appendChild(h); return s; }
  function missing() { var p = el("p", "empty"); p.appendChild(bi("The spec does not explain this yet.", "規格還沒有說明這一項。")); return p; }
  function chipsFor(ids) {
    var w = el("div", "chips");
    ids.forEach(function (id) { var b = el("button", "chip", id); b.type = "button"; b.addEventListener("click", function (e) { e.stopPropagation(); openAC(id); }); w.appendChild(b); });
    return w;
  }
  function commitList(list) {
    var ul = el("ul");
    list.forEach(function (c) {
      var li = el("li"); var row = el("div", "row");
      row.appendChild(el("code", null, c.h)); row.appendChild(document.createTextNode(" ")); row.appendChild(el("span", "date", c.d));
      li.appendChild(row); var sj = el("div"); sj.appendChild(revealFrag(subj(c))); li.appendChild(sj); ul.appendChild(li);
    });
    return ul;
  }
  function renderDetail(a) {
    detail.textContent = "";
    var hd = el("div", "dhead");
    var badge = el("span", "badge s-" + a.eff); badge.appendChild(el("span", "ico", ICON[a.eff])); badge.appendChild(bi(LABEL[a.eff][0], LABEL[a.eff][1]));
    hd.appendChild(badge); hd.appendChild(closeBtn()); detail.appendChild(hd);
    var t = el("h2", "dtitle"); t.id = "dtitle"; t.appendChild(unitFrag(a.title)); if (isFb(a.title)) { t.appendChild(document.createTextNode(" ")); t.appendChild(untrTag()); } detail.appendChild(t);
    var meta = el("div", "dmeta"); meta.appendChild(el("span", "id", a.id));
    if (a.gids.length) {
      var sv = el("span"); sv.appendChild(bi("serves ", "對應 "));
      a.gids.forEach(function (gid, i) { if (i) sv.appendChild(document.createTextNode(", ")); sv.appendChild(el("span", "id", gid)); });
      meta.appendChild(sv);
    }
    detail.appendChild(meta);

    var s = dsec("What it means", "意思");
    if (a.means.length) a.means.forEach(function (u) { s.appendChild(unitDiv(u)); }); else s.appendChild(missing());
    detail.appendChild(s);

    s = dsec("Try it yourself", "自己試試");
    if (a.tries.length) { var ol = el("ol"); a.tries.forEach(function (u) { var li = el("li"); li.appendChild(unitFrag(u)); ol.appendChild(li); }); s.appendChild(ol); } else s.appendChild(missing());
    detail.appendChild(s);

    s = dsec("The criterion", "驗收條件原文");
    s.appendChild(unitDiv(a));
    detail.appendChild(s);

    s = dsec("Evidence", "證據");
    if (a.ev) {
      // The commands stay inside the sentence that says what each one did; a
      // list of them alone read as if every one had been run and passed.
      if (a.evr) { var r = el("div", "u"); r.appendChild(revealFrag(a.evr)); s.appendChild(r); }
      if (a.date) s.appendChild(el("div", "date", a.date));
    } else {
      var e = el("p", "empty"); e.appendChild(bi("No evidence recorded.", "沒有記錄證據。")); s.appendChild(e);
    }
    if (a.decl === "evidenced" && !a.ev) { var w = el("p", "warnline"); w.appendChild(bi("Marked evidenced, but no evidence is recorded: counted as claimed.", "標為有證據，但沒有記錄證據：算作僅宣稱。")); s.appendChild(w); }
    else if (a.decl === "missing") { var w2 = el("p", "warnline"); w2.appendChild(bi("No status line in `STATE.md`.", "`STATE.md` 沒有這一項的狀態行。")); s.appendChild(w2); }
    detail.appendChild(s);

    s = dsec("Related commits", "相關 commit");
    if (a.commits.length) s.appendChild(commitList(a.commits));
    else { var e2 = el("p", "empty"); e2.appendChild(bi("No commit names " + a.id + " yet.", "還沒有任何 commit 提到 " + a.id + "。")); s.appendChild(e2); }
    detail.appendChild(s);

    s = dsec("Related next steps", "相關的下一步");
    if (a.nexts.length) { var ul2 = el("ul"); a.nexts.forEach(function (u) { var li = el("li"); li.appendChild(unitDiv(u)); ul2.appendChild(li); }); s.appendChild(ul2); }
    else { var e3 = el("p", "empty"); e3.appendChild(bi("No next step names " + a.id + " yet.", "還沒有任何下一步提到 " + a.id + "。")); s.appendChild(e3); }
    detail.appendChild(s);
    detail.scrollTop = 0;
  }

  /* ---------- the two lists under the progress tab ---------- */
  (function lists() {
    var host = document.getElementById("lists");
    // The timeline: one entry per day, newest first. A day shows its work as one
    // line per commit, and folds away the commits that only touched memory or the
    // framework. A commit with a body opens to it: the detailed account of what was
    // done. The criteria a day's commits name, and the evidence recorded that day,
    // are chips that open the criterion.
    var c1 = el("div", "lcol tlcol");
    var h1 = el("h2"); h1.appendChild(bi("Timeline", "時間線")); c1.appendChild(h1);
    var ch = D.changes, sb;
    if (ch.kind === "some") sb = [ch.total + " commit(s) since the last view (at `" + ch.n + "`), marked new", "自上次檢視（`" + ch.n + "`）以來有 " + ch.total + " 個新 commit，標上「新」"];
    else if (ch.kind === "none") sb = ["Nothing new since the last view (at `" + ch.n + "`)", "自上次檢視（`" + ch.n + "`）以來沒有新的 commit"];
    else if (ch.kind === "lost") sb = ["The last-view marker is gone, so nothing is marked new", "上次檢視的標記已不存在，所以沒有標出新的 commit"];
    else if (ch.kind === "first") sb = ["First view on this machine", "這台機器第一次檢視"];
    else sb = ["No commits yet", "還沒有任何 commit"];
    c1.appendChild(biEl("div", "sub", sb[0], sb[1]));
    var days = [], dayBy = {};
    function dayOf(d) { if (!dayBy[d]) { dayBy[d] = { d: d, work: [], rec: [], named: [], ev: [] }; days.push(dayBy[d]); } return dayBy[d]; }
    function addId(list, id) { if (list.indexOf(id) < 0) list.push(id); }
    D.tl.forEach(function (c) {
      var day = dayOf(c.d);
      (c.rec ? day.rec : day.work).push(c);
      acs.forEach(function (a) { if (hasTok(c.s, a.id)) addId(day.named, a.id); });
    });
    acs.forEach(function (a) { if (a.date) addId(dayOf(a.date).ev, a.id); });
    days.sort(function (x, y) { return x.d < y.d ? 1 : x.d > y.d ? -1 : 0; });
    function toggle(btnEn, btnZh, closeEn, closeZh, body) {
      var b = el("button", "tltog"); b.type = "button"; body.hidden = true;
      function label() { b.textContent = ""; b.appendChild(body.hidden ? bi(btnEn, btnZh) : bi(closeEn, closeZh)); b.setAttribute("aria-expanded", body.hidden ? "false" : "true"); }
      b.addEventListener("click", function (e) { e.stopPropagation(); body.hidden = !body.hidden; label(); });
      label();
      return b;
    }
    function tlItem(c) {
      var li = el("li", "tlitem");
      var row = el("div", "row");
      if (c.isnew) row.appendChild(biEl("span", "newb", "new", "新"));
      var sj = el("div", "tlsubj"); sj.appendChild(revealFrag(subj(c))); row.appendChild(sj);
      li.appendChild(row);
      var ids = acs.filter(function (a) { return hasTok(c.s, a.id); }).map(function (a) { return a.id; });
      if (ids.length) li.appendChild(chipsFor(ids));
      if (c.body.length) {
        var body = el("div", "tlbody");
        c.body.forEach(function (u) { body.appendChild(unitDiv(u)); });
        var meta = el("div", "tlmeta"); meta.appendChild(el("code", null, c.h)); body.appendChild(meta);
        li.appendChild(toggle("How it was done", "詳細過程", "Hide", "收起", body));
        li.appendChild(body);
      }
      return li;
    }
    var DAYS_SHOWN = 6, WORK_SHOWN = 5, tl = el("div", "tl");
    days.forEach(function (day, i) {
      var dv = el("div", "tlday"); if (i >= DAYS_SHOWN) dv.hidden = true;
      var hd = el("div", "tlhead");
      hd.appendChild(el("span", "tldate", day.d));
      var parts = [];
      if (day.work.length) parts.push([day.work.length + " change(s)", day.work.length + " 項工作"]);
      if (day.rec.length) parts.push([day.rec.length + " record(s)", day.rec.length + " 個記錄"]);
      if (parts.length) hd.appendChild(biEl("span", "tlcount", parts.map(function (p) { return p[0]; }).join(" · "), parts.map(function (p) { return p[1]; }).join(" · ")));
      dv.appendChild(hd);
      if (day.named.length) { var r1 = el("div", "tlids"); r1.appendChild(biEl("span", "tlidl", "Criteria named:", "提到的驗收：")); r1.appendChild(chipsFor(day.named)); dv.appendChild(r1); }
      if (day.ev.length) { var r2 = el("div", "tlids"); r2.appendChild(biEl("span", "tlidl", "Evidence recorded:", "記錄了證據：")); r2.appendChild(chipsFor(day.ev)); dv.appendChild(r2); }
      if (day.work.length) {
        var ul = el("ul"); day.work.slice(0, WORK_SHOWN).forEach(function (c) { ul.appendChild(tlItem(c)); }); dv.appendChild(ul);
        if (day.work.length > WORK_SHOWN) {
          var ul2 = el("ul"); day.work.slice(WORK_SHOWN).forEach(function (c) { ul2.appendChild(tlItem(c)); });
          var wn = day.work.length - WORK_SHOWN;
          dv.appendChild(toggle(wn + " more change(s) this day", "這天還有 " + wn + " 項工作", "Show fewer", "收起", ul2));
          dv.appendChild(ul2);
        }
      }
      if (day.rec.length) {
        var rl = el("ul", "tlrec"); day.rec.forEach(function (c) { rl.appendChild(tlItem(c)); });
        var rn = day.rec.length;
        dv.appendChild(toggle(rn + " record commit(s): memory, framework, translations", "另有 " + rn + " 個記錄 commit：記憶、框架、翻譯", "Hide records", "收起記錄", rl));
        dv.appendChild(rl);
      }
      tl.appendChild(dv);
    });
    c1.appendChild(tl);
    if (days.length > DAYS_SHOWN) {
      var older = el("button", "tlolder"); older.type = "button";
      older.appendChild(bi("Show " + (days.length - DAYS_SHOWN) + " earlier day(s)", "顯示更早的 " + (days.length - DAYS_SHOWN) + " 天"));
      older.addEventListener("click", function () { tl.querySelectorAll(".tlday").forEach(function (d) { d.hidden = false; }); older.hidden = true; });
      c1.appendChild(older);
    }
    if (!days.length) { var e0 = el("p", "empty"); e0.appendChild(bi("No commits yet.", "還沒有任何 commit。")); c1.appendChild(e0); }
    host.appendChild(c1);

    var c2 = el("div", "lcol");
    var h2 = el("h2"); h2.appendChild(bi("Next steps", "下一步")); c2.appendChild(h2);
    c2.appendChild(biEl("div", "sub", nexts.length + " in `STATE.md`", "`STATE.md` 裡共 " + nexts.length + " 項"));
    if (!nexts.length) { var e = el("p", "empty"); e.appendChild(bi("No next steps written yet.", "還沒有寫下任何下一步。")); c2.appendChild(e); }
    else {
      var ul2 = el("ul");
      nexts.forEach(function (k) {
        var li = el("li");
        if (isFb(k.u)) { li.appendChild(untrTag()); }
        li.appendChild(clampBox(unitDiv(k.u), 3));
        if (k.ids.length) li.appendChild(chipsFor(k.ids));
        ul2.appendChild(li);
      });
      c2.appendChild(ul2);
    }
    host.appendChild(c2);
  })();

  /* ---------- the roadmap tab ---------- */
  function tabHead(host, en, zh, noteEn, noteZh) {
    var h = el("h2", "tabtitle"); h.appendChild(bi(en, zh)); host.appendChild(h);
    if (noteEn) host.appendChild(biEl("p", "tabnote", noteEn, noteZh));
  }
  function emptyState(host, en, zh, example) {
    var b = el("div", "emptybox"); b.appendChild(biEl("p", null, en, zh)); b.appendChild(exampleBlock(example)); host.appendChild(b);
  }
  function msBadge(state) { return biEl("span", "sbadge st-" + state, SL[state][0], SL[state][1]); }
  function renderRoadmap() {
    var host = document.getElementById("tab-roadmap"); host.textContent = "";
    tabHead(host, "Roadmap", "路線圖", "The milestones in the order `SPEC.md` lists them. Each state is worked out from the evidence, never written by hand.", "依 `SPEC.md` 列出的順序排列里程碑。每個狀態都由證據算出來，不是手寫的。");
    if (!hasMs) {
      emptyState(host, "No milestones yet. Add a `Milestones` section to `SPEC.md`, one line each, and tag every goal with its milestone, for example:", "還沒有里程碑。在 `SPEC.md` 加一個 `Milestones` 區段，一個里程碑一行，並在每個目標標上它屬於哪個里程碑，例如：", ["## Milestones", "- M1: v1 — first usable version", "- M2: v2 — sharing", "", "## Goals", "- G1 (M1): ..."]);
      return;
    }
    host.appendChild(current ? biEl("p", "quiet", "Current milestone: " + current.id + ", the first one that is not done and has goals.", "目前的里程碑：" + current.id + "，第一個還沒完成而且已有目標的里程碑。") : biEl("p", "quiet", "There is no current milestone: everything is done or only planned.", "目前沒有進行中的里程碑：全部已完成，或還只是規劃。"));
    var ol = el("ol", "rm");
    msList.forEach(function (m, i) {
      var li = el("li"); var b = el("button", "rmrow st-" + m.info.state + (m === current ? " cur" : "")); b.type = "button";
      b.appendChild(el("span", "step", m.info.state === "done" ? "✓" : String(i + 1)));
      var body = el("span", "rmbody");
      var top = el("span", "rmtop");
      top.appendChild(msBadge(m.info.state));
      top.appendChild(el("span", "id", m.id));
      var ttl = el("span", "rmtitle"); ttl.appendChild(unitFrag(m)); top.appendChild(ttl);
      if (isFb(m)) top.appendChild(untrTag());
      if (m === current) top.appendChild(biEl("span", "curpill", "Current", "目前"));
      body.appendChild(top);
      var st = el("span", "rmsub");
      if (m.info.state === "planned") st.appendChild(bi("No goals yet: the spec gate adds them when work starts.", "還沒有目標：開始做的時候，規格門會補上。"));
      else if (!m.info.total) st.appendChild(bi(m.goals.length + " goal(s), no acceptance criteria yet", m.goals.length + " 個目標，還沒有驗收條件"));
      else st.appendChild(bi(m.info.ev + " of " + m.info.total + " evidenced", m.info.total + " 項中 " + m.info.ev + " 項有證據"));
      body.appendChild(st);
      if (m.goals.length) {
        var gl = el("span", "rmgoals");
        m.goals.forEach(function (g) { var gi = el("span", "rmgoal"); gi.appendChild(el("span", "id", g.id)); gi.appendChild(document.createTextNode(" ")); gi.appendChild(unitFrag(g)); gl.appendChild(gi); });
        body.appendChild(gl);
      }
      b.appendChild(body);
      b.addEventListener("click", function () { scope = m.id; showTab("progress"); renderProgress(); writeHash(); window.scrollTo(0, 0); refreshClamps(); });
      li.appendChild(b); ol.appendChild(li);
    });
    host.appendChild(ol);
    if (unassigned.length) {
      var u = el("p", "quiet"); u.appendChild(bi(unassigned.length + " goal(s) belong to no milestone: " + unassigned.map(function (g) { return g.id; }).join(", ") + ".", unassigned.length + " 個目標不屬於任何里程碑：" + unassigned.map(function (g) { return g.id; }).join(", ") + "。")); host.appendChild(u);
    }
  }

  /* ---------- the features tab: the usage guide, from what has evidence ---------- */
  function renderFeatures() {
    var host = document.getElementById("tab-features"); host.textContent = "";
    tabHead(host, "Features", "功能", "What the project does and how to try each thing, taken from the criteria that have recorded evidence.", "專案做得到什麼、每一項怎麼親自試，取自已經記錄了證據的條件。");
    var box = el("section", "box"); boxHead(box, "How to start", "怎麼啟動"); startRows(box); host.appendChild(box);
    var ev = acs.filter(function (a) { return a.eff === "evidenced"; });
    var cl = acs.filter(function (a) { return a.eff === "claimed"; }).length, ns = acs.filter(function (a) { return a.eff === "none"; }).length;
    if (!acs.length) { host.appendChild(biEl("p", "quiet", "No acceptance criteria listed in `SPEC.md` yet, so there is nothing to list here.", "`SPEC.md` 還沒有列出驗收條件，所以這裡還沒有東西。")); return; }
    host.appendChild(biEl("p", "quiet", "Only what has evidence is listed: " + ev.length + " of " + acs.length + ". Left out: " + cl + " claimed, " + ns + " not started.", "只列出有證據的項目：" + acs.length + " 項中的 " + ev.length + " 項。未列入：" + cl + " 項僅宣稱、" + ns + " 項未開始。"));
    if (!ev.length) { host.appendChild(biEl("p", "empty", "Nothing has evidence yet.", "還沒有任何項目有證據。")); return; }
    // each criterion once, under its first goal; goals grouped by their first milestone
    var byGoal = {}, loose = [];
    ev.forEach(function (a) { if (a.gids.length) (byGoal[a.gids[0]] = byGoal[a.gids[0]] || []).push(a); else loose.push(a); });
    function entry(a) {
      var d = el("div", "feat"); d.tabIndex = 0; d.setAttribute("role", "button");
      var t = el("div", "ftitle"); t.appendChild(unitFrag(a.title)); if (isFb(a.title)) { t.appendChild(document.createTextNode(" ")); t.appendChild(untrTag()); } d.appendChild(t);
      if (a.tries.length) { var ol = el("ol"); a.tries.forEach(function (u) { var li = el("li"); li.appendChild(unitFrag(u)); ol.appendChild(li); }); d.appendChild(ol); }
      else d.appendChild(biEl("p", "empty", "The spec does not explain how to try this yet.", "規格還沒有說明怎麼試這一項。"));
      d.appendChild(el("span", "id", a.id));
      function open() { renderDetail(a); openDrawer(detail, d); }
      d.addEventListener("click", open);
      d.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); open(); } });
      return d;
    }
    function goalBlock(g) {
      var list = byGoal[g.id]; if (!list || !list.length) return null;
      var b = el("section", "fgoal"); var h = el("h3", "fgh"); h.appendChild(el("span", "gid", g.id)); h.appendChild(document.createTextNode(" ")); h.appendChild(unitFrag(g)); b.appendChild(h);
      var grid = el("div", "fgrid"); list.forEach(function (a) { grid.appendChild(entry(a)); }); b.appendChild(grid); return b;
    }
    function mshead(m) { var h = el("h2", "fmh"); if (m) { h.appendChild(el("span", "id", m.id)); h.appendChild(document.createTextNode(" ")); h.appendChild(unitFrag(m)); } else h.appendChild(bi("Not in a milestone", "不屬於任何里程碑")); return h; }
    if (hasMs) {
      msList.concat([null]).forEach(function (m) {
        var gl = m ? m.goals.filter(function (g) { return g.mids[0] === m.id; }) : unassigned;
        var blocks = gl.map(goalBlock).filter(Boolean);
        if (!blocks.length) return;
        host.appendChild(mshead(m)); blocks.forEach(function (b) { host.appendChild(b); });
      });
    } else goals.map(goalBlock).filter(Boolean).forEach(function (b) { host.appendChild(b); });
    if (loose.length) {
      var lb2 = el("section", "fgoal"); var h2 = el("h3", "fgh"); h2.appendChild(bi("Not under a goal", "未歸類")); lb2.appendChild(h2);
      var grid2 = el("div", "fgrid"); loose.forEach(function (a) { grid2.appendChild(entry(a)); }); lb2.appendChild(grid2); host.appendChild(lb2);
    }
  }

  /* ---------- the structure tab ---------- */
  var compCards = {};
  function jumpComp(id) {
    closeDrawers(true);
    if (tabName !== "structure") showTab("structure");
    var c = compCards[id]; if (c) { c.scrollIntoView({ block: "center" }); flash(c); }
  }
  function compChips(ids, jumpFn) {
    var w = el("span", "chips");
    ids.forEach(function (id) {
      if (compBy[id]) { var b = el("button", "chip", id); b.type = "button"; b.addEventListener("click", function (e) { e.stopPropagation(); jumpFn(id); }); w.appendChild(b); }
      else { var s = el("span", "chip bad", id + "?"); s.title = "Not a component in SPEC.md"; w.appendChild(s); }
    });
    return w;
  }
  function pathLine(c) {
    var p = el("div", "cpath");
    if (c.path) p.appendChild(el("code", null, c.path));
    if (!c.path) p.appendChild(biEl("span", "pbad", "no path written", "沒有寫路徑"));
    else if (!c.exists) p.appendChild(biEl("span", "pbad", "path not found", "路徑不存在"));
    return p;
  }
  function renderComp(c) {
    detail.textContent = "";
    var hd = el("div", "dhead"); hd.appendChild(biEl("span", "kindtag", "Component", "元件")); hd.appendChild(closeBtn()); detail.appendChild(hd);
    var t = el("h2", "dtitle"); t.id = "dtitle"; if (c.name) { t.appendChild(unitFrag(c.name)); if (isFb(c.name)) { t.appendChild(document.createTextNode(" ")); t.appendChild(untrTag()); } } else t.appendChild(document.createTextNode(c.id)); detail.appendChild(t);
    var meta = el("div", "dmeta"); meta.appendChild(el("span", "id", c.id)); detail.appendChild(meta);
    detail.appendChild(pathLine(c));
    var s = dsec("What it is responsible for", "它負責什麼");
    if (c.resp) s.appendChild(unitDiv(c.resp)); else s.appendChild(biEl("p", "empty", "The spec does not say yet.", "規格還沒有說明。"));
    detail.appendChild(s);
    s = dsec("Uses", "使用");
    if (c.uses.length) s.appendChild(compChips(c.uses, jumpComp)); else s.appendChild(biEl("p", "empty", "Uses no other component.", "沒有使用其他元件。"));
    detail.appendChild(s);
    s = dsec("Used by", "被使用");
    if (c.usedBy.length) s.appendChild(compChips(c.usedBy, jumpComp)); else s.appendChild(biEl("p", "empty", "No other component uses it.", "沒有其他元件使用它。"));
    detail.appendChild(s);
    s = dsec("Last commits that touched it", "最近動過它的 commit");
    if (c.commits.length) s.appendChild(commitList(c.commits)); else s.appendChild(biEl("p", "empty", c.path ? "No commit touched this path." : "No path, so no history to show.", c.path ? "沒有任何 commit 動過這個路徑。" : "沒有路徑，所以沒有紀錄可看。"));
    detail.appendChild(s);
    detail.scrollTop = 0;
  }
  function renderStructure() {
    var host = document.getElementById("tab-structure"); host.textContent = ""; compCards = {};
    tabHead(host, "Structure", "結構", "The project's parts: what each one is for, where it lives and what it uses. A path that is not on disk is marked.", "專案的各個部分：各自負責什麼、放在哪裡、使用誰。路徑不在磁碟上的會被標出來。");
    if (!comps.length) {
      emptyState(host, "No components yet. Add a `Components` section to `SPEC.md`, one line each: id, name, path in backticks, what it is for, and what it uses, for example:", "還沒有元件。在 `SPEC.md` 加一個 `Components` 區段，一個元件一行：編號、名稱、用反引號包起來的路徑、它負責什麼、使用誰，例如：", ["## Components", "- C1: Parser (`src/parser`) — turns files into records; uses C2", "- C2: Store (`src/store.js`) — keeps the records"]);
      return;
    }
    var grid = el("div", "cgrid");
    comps.forEach(function (c) {
      var d = el("div", "ccard" + (c.path && !c.exists ? " missingpath" : "")); d.tabIndex = 0; d.setAttribute("role", "button"); d.setAttribute("data-comp", c.id);
      var top = el("div", "ctop");
      var nm = el("div", "cname"); if (c.name) nm.appendChild(unitFrag(c.name)); else nm.appendChild(document.createTextNode(c.id)); top.appendChild(nm);
      if (c.name && isFb(c.name)) top.appendChild(untrTag());
      top.appendChild(el("span", "id", c.id)); d.appendChild(top);
      d.appendChild(pathLine(c));
      if (c.resp) { var r = el("div", "cresp"); r.appendChild(unitFrag(c.resp)); d.appendChild(r); }
      var rel = el("div", "crel");
      if (c.uses.length) { var u = el("div", "crow"); u.appendChild(biEl("span", "lbl", "Uses", "使用")); u.appendChild(compChips(c.uses, jumpComp)); rel.appendChild(u); }
      if (c.usedBy.length) { var ub = el("div", "crow"); ub.appendChild(biEl("span", "lbl", "Used by", "被使用")); ub.appendChild(compChips(c.usedBy, jumpComp)); rel.appendChild(ub); }
      d.appendChild(rel);
      function open() { renderComp(c); openDrawer(detail, d); }
      d.addEventListener("click", open);
      d.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); open(); } });
      compCards[c.id] = d; grid.appendChild(d);
    });
    host.appendChild(grid);
  }

  /* ---------- the gaps panel ---------- */
  (function panel() {
    var hd = el("div", "dhead"); var t = el("h2", "dtitle"); t.id = "gtitle"; t.appendChild(bi("Gaps (" + gaps.length + ")", "缺口（" + gaps.length + "）")); hd.appendChild(t); hd.appendChild(closeBtn()); gapsEl.appendChild(hd);
    var gl = el("div", "gl");
    if (!gaps.length) gl.appendChild(biEl("p", "t1", "No gaps found.", "沒有發現缺口。"));
    var HEAD = { high: ["High: shown as complete or true, but is not", "高：看起來完整或正確，其實不是"], medium: ["Medium: something needed is missing", "中：缺少必要的東西"], low: ["Low: housekeeping", "低：整理類"] };
    var MARK = { high: "▲", medium: "◆", low: "·" };
    SEV.forEach(function (sv) {
      var list = gaps.filter(function (g) { return g.sev === sv; });
      if (!list.length) return;
      gl.appendChild(biEl("h3", sv, HEAD[sv][0] + " (" + list.length + ")", HEAD[sv][1] + "（" + list.length + "）"));
      list.forEach(function (g) {
        var li = el("div", "gi " + sv + (g.ref ? " ref" : ""));
        li.appendChild(el("span", "ic", MARK[sv]));
        var tx = el("span"); tx.appendChild(bi(g.en, g.zh)); li.appendChild(tx);
        if (g.ref) { li.tabIndex = 0; li.setAttribute("role", "button"); li.addEventListener("click", function () { jump(g.ref); }); li.addEventListener("keydown", function (e) { if (e.key === "Enter") jump(g.ref); }); }
        gl.appendChild(li);
      });
    });
    gapsEl.appendChild(gl);
    var det = el("details"), sm = el("summary"); sm.appendChild(bi("Open questions (" + D.open.length + ")", "未解問題（" + D.open.length + "）")); det.appendChild(sm);
    if (!D.open.length) { var e = el("p", "empty"); e.appendChild(bi("No open questions written yet.", "還沒有寫下任何未解問題。")); det.appendChild(e); }
    else { var ul = el("ul"); D.open.forEach(function (u) { var li = el("li"); li.appendChild(unitFrag(u)); ul.appendChild(li); }); det.appendChild(ul); }
    gapsEl.appendChild(det);
    var gen = el("p", "gen");
    gen.appendChild(bi("Generated " + D.now + " at commit `" + D.head + "` from `SPEC.md`, `STATE.md` (last updated: " + (D.updated || "unknown") + "), `AGENTS.md` and `git`. The page stores nothing and verifies nothing; run the generator again to refresh it, and rerun the evidence to check it.",
      "產生於 " + D.now + "，commit `" + D.head + "`，來源為 `SPEC.md`、`STATE.md`（最後更新：" + (D.updated || "不明") + "）、`AGENTS.md` 與 `git`。本頁不儲存也不驗證任何事；要更新請重新執行產生器，要確認請自行重跑證據裡的指令。"));
    gapsEl.appendChild(gen);

    var gb = document.getElementById("gapsbtn");
    gb.appendChild(bi("Gaps (" + gaps.length + ")", "缺口（" + gaps.length + "）")); gb.hidden = false;
    gb.addEventListener("click", function () { openDrawer(gapsEl, gb); });

    var hl = document.getElementById("highline");
    if (highs) {
      var b = el("button"); b.type = "button";
      b.appendChild(bi("▲ " + highs + " item(s) look complete but are not", "▲ " + highs + " 項看起來完整其實不是"));
      b.addEventListener("click", function () { openDrawer(gapsEl, b); });
      hl.appendChild(b); hl.hidden = false;
    }
  })();
  // A gap that names a criterion, a goal or a component takes you to it.
  function jump(ref) {
    var kind = ref.charAt(0), id = ref.slice(2);
    if (kind === "a" && acBy[id]) { openAC(id); return; }
    if (kind === "c" && compBy[id]) { jumpComp(id); return; }
    closeDrawers(true);
    if (kind === "g" && goalBy[id]) {
      if (tabName !== "progress") showTab("progress");
      if (scopeGoalsOf(scope).indexOf(goalBy[id]) < 0) setScope("all");
      var s = document.getElementById("sec-" + id);
      if (s) { s.scrollIntoView({ block: "start" }); flash(s); }
    }
  }

  /* ---------- tabs: remembered, and reflected in the address so a link can open one ---------- */
  var TABS = [["progress", "Progress", "進度"], ["roadmap", "Roadmap", "路線圖"], ["features", "Features", "功能"], ["structure", "Structure", "結構"]];
  var tabName = "progress", tabBtns = {};
  function writeHash() {
    var h = "#" + tabName + (tabName === "progress" && hasMs ? "/" + scope : "");
    try { history.replaceState(null, "", h); } catch (e) { try { location.hash = h; } catch (e2) {} }
  }
  function showTab(name) {
    if (!tabBtns[name]) name = "progress";
    tabName = name;
    TABS.forEach(function (t) {
      var on = t[0] === name;
      document.getElementById("tab-" + t[0]).hidden = !on;
      tabBtns[t[0]].setAttribute("aria-selected", on ? "true" : "false");
      tabBtns[t[0]].tabIndex = on ? 0 : -1;
    });
    try { localStorage.setItem(TABKEY, name); } catch (e) {}
    writeHash(); refreshClamps();
  }
  (function tabs() {
    var nav = document.getElementById("tabs");
    TABS.forEach(function (t) {
      var b = el("button", "tab"); b.type = "button"; b.setAttribute("role", "tab"); b.id = "tabbtn-" + t[0];
      b.appendChild(bi(t[1], t[2]));
      b.addEventListener("click", function () { closeDrawers(true); showTab(t[0]); window.scrollTo(0, 0); });
      b.addEventListener("keydown", function (e) {
        var i = TABS.map(function (x) { return x[0]; }).indexOf(t[0]), n = e.key === "ArrowRight" ? i + 1 : e.key === "ArrowLeft" ? i - 1 : -1;
        if (n >= 0 && n < TABS.length) { tabBtns[TABS[n][0]].focus(); showTab(TABS[n][0]); }
      });
      nav.appendChild(b); tabBtns[t[0]] = b;
    });
  })();
  function readHash() {
    var parts = (location.hash || "").replace(/^#/, "").split("/");
    var name = tabBtns[parts[0]] ? parts[0] : null;
    if (name === "progress" && parts[1] && hasMs && (parts[1] === "all" || msBy[parts[1]] || (parts[1] === "unassigned" && unassigned.length))) scope = parts[1];
    return name;
  }
  window.addEventListener("hashchange", function () { var n = readHash(); if (n) { closeDrawers(true); renderProgress(); showTab(n); } });

  /* ---------- language ---------- */
  var lb = document.getElementById("lang"), tl = root.getAttribute("data-tlang") || "zh-TW";
  try { var s0 = localStorage.getItem(KEY); if (s0 === "en" || s0 === "zh") root.setAttribute("data-lang", s0); } catch (e) {}
  function applyLang() {
    var l = root.getAttribute("data-lang");
    root.setAttribute("lang", l === "zh" ? tl : "en");
    lb.textContent = l === "zh" ? "English" : "繁體中文";
  }
  lb.hidden = false;
  lb.addEventListener("click", function () {
    var n = root.getAttribute("data-lang") === "zh" ? "en" : "zh";
    root.setAttribute("data-lang", n);
    try { localStorage.setItem(KEY, n); } catch (e) {}
    applyLang(); refreshClamps();
  });
  applyLang();

  /* ---------- start ---------- */
  var first = readHash();
  if (!first) { try { first = localStorage.getItem(TABKEY); } catch (e) {} }
  renderProgress(); renderRoadmap(); renderFeatures(); renderStructure();
  showTab(first);
  // A translator model already on this machine needs no click: fill in what the file lacks.
  if (D.trans && mtTodo().length && typeof self.Translator !== "undefined") {
    try {
      Translator.availability({ sourceLanguage: "en", targetLanguage: tlCode() }).then(function (a) {
        if (a === "available") machineTranslate(document.getElementById("mtbtn"));
      }, function () {});
    } catch (e) {}
  }
  var rz = 0;
  window.addEventListener("resize", function () { clearTimeout(rz); rz = setTimeout(refreshClamps, 120); });
})();

EOF
printf '</script>\n</body>\n</html>\n'
} > "$OUT" || { echo "progress.sh: could not write $OUT" >&2; exit 1; }

# Move the marker only after the page was written, so a failed run does not
# swallow the changes it never showed.
if [ "$MARK" -eq 1 ]; then
  git -C "$ROOT" rev-parse --verify -q HEAD > "$MARKER" 2>/dev/null || true
fi

# Git Bash hands native Windows programs a drive-letter path, which the launcher
# and the browser both read; elsewhere the path is already native.
SHOWN="$OUT"
command -v cygpath >/dev/null 2>&1 && SHOWN="$(cygpath -m "$OUT")"
echo "$SHOWN"

if [ "$NO_OPEN" -eq 0 ]; then
  case "$(uname -s 2>/dev/null)" in
    Darwin) open "$OUT" >/dev/null 2>&1 || echo "progress.sh: could not open the page; open $OUT yourself" >&2 ;;
    MINGW*|MSYS*|CYGWIN*) cmd //c start "" "$(cygpath -w "$OUT")" >/dev/null 2>&1 || echo "progress.sh: could not open the page; open $OUT yourself" >&2 ;;
    *) if command -v xdg-open >/dev/null 2>&1; then xdg-open "$OUT" >/dev/null 2>&1 &
       else echo "progress.sh: xdg-open not found; open $OUT yourself" >&2; fi ;;
  esac
fi
exit 0
