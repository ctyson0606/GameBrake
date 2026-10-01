#!/usr/bin/env bash
# Structural checks for a SparkForge tree. Every failure is reported; the
# script exits 1 if any check failed.
#
# This file lives at kit/scripts/check.sh and is run through the stub at
# scripts/check.sh. ROOT is two levels above it: the SparkForge template inside
# that repository, or the project root inside a project that consumes it.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAILED=0

# Directories that hold per-tool stubs pointing into kit/. One entry per tool
# whose skill directory has been established. Adding a tool means adding its
# directory here and generating its stubs.
STUB_ROOTS=(".claude")

fail() { echo "FAIL  $1"; FAILED=1; }
pass() { echo "ok    $1"; }
# A check with nothing to compare has to say so. Reporting it as a pass makes
# an absence look like a verified agreement.
na()   { echo "n/a   $1"; }

# Checks shared with SparkForge's own repository checker.
. "$(dirname "$0")/rule-checks.sh"

# --- required files -------------------------------------------------------
REQUIRED=(
  AGENTS.md SPEC.md METHOD.md STATE.md GOTCHAS.md
  .gitattributes kit/VERSION kit/entry-points.txt
  scripts/check.sh scripts/update-kit.sh
  kit/scripts/check.sh kit/scripts/update-kit.sh kit/scripts/rule-checks.sh
)
# CLAUDE.md is deliberately not in this list. It is one tool's entry file among
# several, and a project using none of the tools that need one may delete it.
# The entry-point check below is what governs those files.
missing=""
for f in "${REQUIRED[@]}"; do
  [ -f "$ROOT/$f" ] || missing="$missing $f"
done
if [ -n "$missing" ]; then fail "required files missing:$missing"
else pass "required files present"; fi

# --- scripts/ holds stubs that hand over to kit/scripts/ ------------------
# The scripts live in kit/ so that update-kit.sh carries their fixes with
# everything else. A full script left in scripts/ keeps running its old copy
# while the fixed one sits unused in kit/scripts/, and every check it lacks
# reports nothing. That is what a project installed before this layout has
# until its stubs are copied in once by hand.
bad=""
for s in check.sh update-kit.sh; do
  [ -f "$ROOT/scripts/$s" ] || continue
  grep -q "kit/scripts/$s" "$ROOT/scripts/$s" || bad="$bad; scripts/$s does not hand over to kit/scripts/$s"
  [ "$(grep -cvE '^[[:space:]]*(#|$)' "$ROOT/scripts/$s")" -le 1 ] || \
    bad="$bad; scripts/$s holds more than a stub"
done
if [ -n "$bad" ]; then fail "script stubs${bad}"
else pass "scripts/ holds stubs into kit/scripts/"; fi

# --- every canonical skill has a stub under every stub root ---------------
for sr in "${STUB_ROOTS[@]}"; do
  missing=""
  for f in "$ROOT"/kit/skills/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"
    [ -f "$ROOT/$sr/skills/$n/SKILL.md" ] || missing="$missing $n"
  done
  if [ -n "$missing" ]; then fail "$sr/skills: stubs missing for:$missing"
  else pass "$sr/skills: a stub for every skill"; fi

  missing=""
  for f in "$ROOT"/kit/agents/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"
    [ -f "$ROOT/$sr/agents/$n.md" ] || missing="$missing $n"
  done
  if [ -n "$missing" ]; then fail "$sr/agents: stubs missing for:$missing"
  else pass "$sr/agents: a stub for every agent"; fi
done

# --- no stub pointing at a canonical file that does not exist -------------
dangling=""
for sr in "${STUB_ROOTS[@]}"; do
  for s in "$ROOT/$sr"/skills/*/SKILL.md; do
    [ -e "$s" ] || continue
    n="$(basename "$(dirname "$s")")"
    [ -f "$ROOT/kit/skills/$n.md" ] || dangling="$dangling $sr/skills/$n"
  done
  for s in "$ROOT/$sr"/agents/*.md; do
    [ -e "$s" ] || continue
    n="$(basename "$s" .md)"
    [ -f "$ROOT/kit/agents/$n.md" ] || dangling="$dangling $sr/agents/$n"
  done
done
if [ -n "$dangling" ]; then fail "dangling stubs (no canonical file):$dangling"
else pass "no dangling stubs"; fi

# --- agent stubs mirror the canonical tools: line -------------------------
# A tool restriction has to live where the tool reads it, so it exists twice.
# This is the check that keeps the second copy from becoming a comment.
drift=""
for sr in "${STUB_ROOTS[@]}"; do
  for f in "$ROOT"/kit/agents/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"
    stub="$ROOT/$sr/agents/$n.md"
    [ -f "$stub" ] || continue
    a="$(grep '^tools:' "$f" || true)"
    b="$(grep '^tools:' "$stub" || true)"
    [ "$a" = "$b" ] || drift="$drift; $sr/agents/$n.md has [$b], kit has [$a]"
  done
done
if [ -n "$drift" ]; then fail "agent tools drifted${drift}"
else pass "agent stubs mirror the canonical tools line"; fi

# --- every skill named in the AGENTS.md routing block exists --------------
routed="$(awk '/^## Skill routing/{p=1;next} /^## /{p=0} p' "$ROOT/AGENTS.md" \
          | sed -n 's/^\([a-z0-9-]*\) — .*/\1/p')"
missing=""
for n in $routed; do
  [ -f "$ROOT/kit/skills/$n.md" ] || missing="$missing $n"
done
if [ -n "$missing" ]; then fail "AGENTS.md routes skills that do not exist:$missing"
else pass "AGENTS.md routing resolves ($(echo $routed | wc -w) entries)"; fi

# --- every file path mentioned anywhere in AGENTS.md exists ---------------
# Forward references such as scripts/update-kit.sh are caught here rather than
# relying on anyone remembering to keep a renamed file in step.
#
# The extensions are the ones an Environment facts command names. A project on
# Windows writes its scripts as .ps1, .bat or .cmd, and a list without them
# passes a renamed script without looking at it. js and ts are left out on
# purpose: prose names Node.js and Next.js, and neither is a path.
paths="$(grep -oE '[A-Za-z0-9_./-]+\.(md|sh|json|ya?ml|txt|ps1|bat|cmd|py)' "$ROOT/AGENTS.md" | sort -u)"
missing=""
for p in $paths; do
  [ -e "$ROOT/$p" ] || missing="$missing $p"
done
if [ -n "$missing" ]; then fail "AGENTS.md names paths that do not exist:$missing"
else pass "AGENTS.md path references resolve ($(echo $paths | wc -w) paths)"; fi

# --- no .sh carries CRLF --------------------------------------------------
crlf="$(find "$ROOT" -name '*.sh' -exec grep -lU "$(printf '\r')" {} + 2>/dev/null)"
if [ -n "$crlf" ]; then fail "CRLF in shell scripts: $crlf"
else pass "no CRLF in any .sh"; fi

# --- every .sh is executable in the index ---------------------------------
# Read the index, never the working tree: on Windows core.filemode is false,
# so the mode on disk is not the mode anyone else will receive. A script
# committed at 100644 is unrunnable on every platform that honours the bit,
# and there is no symptom on the platform that produced it.
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "executable bit: $ROOT is not inside a git work tree, so the index cannot be read"
else
  bad=""
  for f in $(cd "$ROOT" && find kit scripts -name '*.sh' 2>/dev/null); do
    mode="$(git -C "$ROOT" ls-files -s -- "$f" | awk '{print $1}')"
    case "$mode" in
      100755) ;;
      "")     bad="$bad; $f is not in the index" ;;
      *)      bad="$bad; $f is $mode" ;;
    esac
  done
  if [ -n "$bad" ]; then fail "shell scripts not executable in the index${bad}"
  else pass "every .sh is 100755 in the index"; fi
fi

# --- every tool entry file points at AGENTS.md ----------------------------
# The entry files are what make AGENTS.md load without anyone asking for it,
# and each one lives at a path its tool hardcodes, so they cannot be one file.
# A tool whose entry has drifted into holding instructions of its own is the
# failure this catches: the project then has two sources of truth and no
# symptom until they disagree.
#
# A missing entry is not a failure. Deleting the entry for a tool the project
# does not use is expected, and a check that demanded all of them would force
# every project to carry every tool. All of them missing is a different thing
# and is reported, because then nothing loads AGENTS.md anywhere.
if [ ! -f "$ROOT/kit/entry-points.txt" ]; then
  fail "entry points: kit/entry-points.txt is missing, so the list cannot be read"
else
  present=0
  bad=""
  while read -r e; do
    case "$e" in ''|\#*) continue ;; esac
    [ -f "$ROOT/$e" ] || continue
    present=$((present + 1))
    grep -q 'AGENTS\.md' "$ROOT/$e" || bad="$bad; $e does not name AGENTS.md"
  done < "$ROOT/kit/entry-points.txt"
  # Cursor loads a rule unasked only when the frontmatter says so. Without this
  # the file is present, correct, and silently inert.
  mdc="$ROOT/.cursor/rules/sparkforge.mdc"
  if [ -f "$mdc" ] && ! grep -q '^alwaysApply: true$' "$mdc"; then
    bad="$bad; .cursor/rules/sparkforge.mdc is not alwaysApply: true"
  fi
  if [ -n "$bad" ]; then fail "tool entry points${bad}"
  elif [ "$present" -eq 0 ]; then
    fail "tool entry points: every entry in kit/entry-points.txt is missing, so no tool is pointed at AGENTS.md"
  else pass "tool entry points reach AGENTS.md ($present present)"; fi
fi

# --- tier tags and evidence labels -------------------------------------
check_rule_grammar "kit/skills" "$ROOT"/kit/skills/*.md

# --- .gitattributes verified outside this repo ----------------------------
# It cannot be verified in place: a .gitattributes further up the tree
# contributes attributes to everything below it, so a check run here passes
# whatever this file says. The probe has to run where nothing else applies.
tmp="$(mktemp -d)"
cp "$ROOT/.gitattributes" "$tmp/.gitattributes"
(cd "$tmp" && git init -q .)
expect_eol() {
  got="$(cd "$tmp" && git check-attr eol -- "$1" | sed 's/.*: //')"
  [ "$got" = "$2" ] || echo "$1 -> $got (expected $2)"
}
attr_bad="$( { expect_eol sample.sh lf
               expect_eol sample.md lf
               expect_eol sample.mdc lf
               expect_eol VERSION   lf
               expect_eol kit/entry-points.txt lf
               expect_eol .clinerules lf
               expect_eol .windsurfrules lf
               expect_eol sample.bat crlf
               expect_eol sample.ps1 crlf; } )"
rm -rf "$tmp"
if [ -n "$attr_bad" ]; then fail "gitattributes in a clean repo: $attr_bad"
else pass "gitattributes behaves correctly in a clean repo"; fi

# --- README translations agree ---------------------------------------------
check_readme_translations "$ROOT"

echo
if [ "$FAILED" -eq 0 ]; then echo "check.sh: all checks passed"; else echo "check.sh: FAILED"; fi
exit "$FAILED"
