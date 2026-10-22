#!/usr/bin/env bash
# Sourced, not run. Checks that more than one checker applies to different
# files: kit/scripts/check.sh to the skills and READMEs of the tree it checks,
# and SparkForge's own scripts/check-repo.sh to that repository's root, where
# the same grammar and the same translated READMEs exist. Kept in one place so
# the two cannot drift into checking different things under the same name.
#
# The caller defines fail, pass and na.

# Tier tags and evidence labels, over the given rule files. <where> names them
# in the output.
#   check_rule_grammar <where> <file>...
check_rule_grammar() {
  local where="$1"; shift
  local tags bad viol f

  tags="$(grep -hoE '`\[T[^]]*\]`' "$@" 2>/dev/null)"
  bad="$(printf '%s\n' "$tags" | grep -vE '^$|^`\[T[0-2]( \| T[0-2] if: [^]]+)*\]`$')"
  if [ -n "$bad" ]; then fail "$where: tier tags outside the grammar: $bad"
  else pass "$where: tier tags conform ($(printf '%s' "$tags" | grep -c .) tags)"; fi

  # Anchored on the ### heading: a block with no heading is not a rule and is
  # not subject to this check. A rule ends at the next heading or at end of
  # file, never at a trailing comment — ending it at a comment would tie the
  # invariant to a convention someone has to remember, and a rule written
  # without that comment would leave the check silently.
  viol="$(for f in "$@"; do
    [ -e "$f" ] || continue
    awk -v F="$(basename "$f")" '
      function close_block() { if (inb && n != 1) printf "%s: %d labels: %s\n", F, n, h; inb=0 }
      /^### / { close_block(); inb=1; h=$0; n=0; next }
      inb && /^> (Evidence|Found|Rationale):/ { n++ }
      END { close_block() }
    ' "$f"
  done)"
  if [ -n "$viol" ]; then fail "$where: evidence labels: $viol"
  else pass "$where: exactly one evidence label per rule"; fi
}

# README.md against every README.*.md beside it, in <dir>.
#   check_readme_translations <dir>
check_readme_translations() {
  local dir="$1" base r n bad vacuous
  local readmes=()
  for r in "$dir"/README.md "$dir"/README.*.md; do
    [ -e "$r" ] && readmes+=("$r")
  done
  if [ "${#readmes[@]}" -le 1 ]; then
    na "README consistency: only one README, nothing to compare"
    return
  fi
  base="$dir/README.md"
  # Two empty extractions compare equal, so a pair of READMEs with nothing
  # copyable in either would satisfy the diff by agreeing about nothing. Say
  # so instead of reporting it as a verified match.
  vacuous=1
  for r in "${readmes[@]}"; do
    [ -n "$(_readme_copyable "$r")" ] && vacuous=0
  done
  bad=""
  for r in "${readmes[@]}"; do
    [ "$r" = "$base" ] && continue
    n="$(basename "$r")"
    [ "$(_readme_structure "$base")" = "$(_readme_structure "$r")" ] || \
      bad="$bad; $n structure $(_readme_structure "$r") != $(_readme_structure "$base")"
    diff <(_readme_copyable "$base") <(_readme_copyable "$r") >/dev/null 2>&1 || \
      bad="$bad; $n copyable lines differ"
  done
  if [ -n "$bad" ]; then fail "README translations${bad}"
  elif [ "$vacuous" -eq 1 ]; then
    na "README: structure agrees across ${#readmes[@]} files, but no side has copyable content to compare"
  else pass "README translations agree (${#readmes[@]} files)"; fi
}

# The two README sections kit/skills/readme.md says restate the repository,
# each held to what it restates. Only README.md is read: the translation check
# above already holds every edition's fences to it.
#
# Every path in a fence under the "## 📦" layout heading exists in <dir>.
#   check_readme_layout <dir>
check_readme_layout() {
  local dir="$1" p missing="" n=0
  [ -f "$dir/README.md" ] || { na "README layout: no README.md"; return; }
  while IFS= read -r p; do
    n=$((n + 1))
    [ -e "$dir/$p" ] || missing="$missing $p"
  done < <(_readme_fenced "$dir/README.md" "## 📦" | sed 's/[[:space:]]#.*$//' | awk 'NF { print $1 }')
  if [ "$n" -eq 0 ]; then na "README layout: no fenced paths under a \"## 📦\" heading"
  elif [ -n "$missing" ]; then fail "README layout names paths that do not exist:$missing"
  else pass "README layout: all $n paths exist"; fi
}

# Every command in a fence under the "## 🛠" development heading is one of the
# Environment facts in <dir>/AGENTS.md, character for character.
#   check_readme_commands <dir>
check_readme_commands() {
  local dir="$1" facts c bad="" n=0
  [ -f "$dir/README.md" ] || { na "README commands: no README.md"; return; }
  facts="$(awk '/^## Environment facts/ { p = 1; next } /^## / { p = 0 }
    p && /^[A-Za-z0-9_-]+:/ { sub(/^[^:]*:[ \t]*/, ""); sub(/[ \t]+#.*$/, ""); sub(/[ \t]+$/, ""); if ($0 != "" && $0 != "none") print }' \
    "$dir/AGENTS.md" 2>/dev/null)"
  if [ -z "$facts" ]; then na "README commands: AGENTS.md has no Environment facts to compare with"; return; fi
  while IFS= read -r c; do
    n=$((n + 1))
    printf '%s\n' "$facts" | grep -qxF -- "$c" || bad="$bad; $c"
  done < <(_readme_fenced "$dir/README.md" "## 🛠" | grep -vE '^[[:space:]]*(#|$)' | sed 's/[[:space:]]*$//')
  if [ "$n" -eq 0 ]; then na "README commands: no fenced commands under a \"## 🛠\" heading"
  elif [ -n "$bad" ]; then fail "README development commands not in AGENTS.md Environment facts${bad}"
  else pass "README development commands match Environment facts ($n)"; fi
}

# The lines inside fences, in sections whose heading starts with <prefix>.
_readme_fenced() {
  awk -v pre="$2" '
    /^## / { sec = (index($0, pre) == 1); f = 0; next }
    /^```/ { f = !f; next }
    sec && f' "$1" | sed 's/\r$//'
}

_readme_structure() {
  printf '%s %s %s' \
    "$(grep -c '^#\{1,6\} ' "$1")" \
    "$(grep -c '^```' "$1")" \
    "$(grep -c '^|' "$1")"
}

# Everything inside a fence, minus comment lines: this is what a reader copies
# out, and it is the part a translation must not have touched.
_readme_copyable() {
  awk '/^```/{f=!f; next} f' "$1" | grep -vE '^[[:space:]]*#' | sed 's/[[:space:]]*$//'
}
