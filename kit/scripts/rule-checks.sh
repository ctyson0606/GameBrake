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
