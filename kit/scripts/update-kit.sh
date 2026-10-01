#!/usr/bin/env bash
# Pull the latest framework content from upstream and overwrite kit/ with it.
#
# Nothing outside kit/ is written. SPEC.md, METHOD.md, STATE.md, GOTCHAS.md
# and every section of AGENTS.md — Declarations and Environment facts
# included — are this project's own and are never touched by this script.
#
# For a project that consumes this framework the upstream is SparkForge
# itself, so that is the default. Fork it and set SPARKFORGE_UPSTREAM to point
# somewhere else. The URL is HTTPS rather than SSH: whoever runs this may not
# have an SSH key on the account the repository lives under.
#
# Usage:  scripts/update-kit.sh [<upstream-url-or-path>] [<ref>]
#         SPARKFORGE_UPSTREAM=<url> scripts/update-kit.sh

set -eu

# This file lives at kit/scripts/update-kit.sh, inside the kit/ it is about to
# delete and replace. Bash reads a script while it runs it, so replacing the
# file underneath a running copy can leave bash reading the new file from the
# old one's offset. Run from a copy instead, made before anything is touched.
if [ -z "${SPARKFORGE_UPDATE_COPY:-}" ]; then
  ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
  self="$(mktemp)"
  cp "$0" "$self"
  SPARKFORGE_ROOT="$ROOT" SPARKFORGE_UPDATE_COPY="$self" exec bash "$self" "$@"
fi
ROOT="$SPARKFORGE_ROOT"

SPARKFORGE_UPSTREAM="${SPARKFORGE_UPSTREAM:-https://github.com/ctyson0606/SparkForge.git}"
UPSTREAM="${1:-$SPARKFORGE_UPSTREAM}"
REF="${2:-main}"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp" "$SPARKFORGE_UPDATE_COPY"; }
trap cleanup EXIT

echo "Fetching $UPSTREAM ($REF)"
# Never ask for a login. Whoever runs this may be an agent that cannot answer a
# prompt, and Git Credential Manager waits for an answer indefinitely: the first
# run against an upstream that needed a login sat there until it was killed.
# Fail instead, before anything here is touched, and say what to pass.
if ! GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never \
     git clone --quiet --depth 1 --branch "$REF" "$UPSTREAM" "$tmp/upstream"; then
  ssh_url="$(printf '%s' "$UPSTREAM" | sed -n 's#^https://github\.com/#git@github.com:#p')"
  {
    echo
    echo "error: could not fetch $UPSTREAM ($REF). Nothing in this project changed."
    echo "If it needs a login, this script will not ask for one. Pass a URL you can"
    echo "reach without one instead, or set SPARKFORGE_UPSTREAM to it."
    if [ -n "$ssh_url" ]; then
      echo "Over SSH that is:  scripts/update-kit.sh $ssh_url"
    fi
  } >&2
  exit 1
fi

SRC="$tmp/upstream/template/kit"
if [ ! -d "$SRC" ]; then
  echo "error: $UPSTREAM ($REF) has no template/kit directory." >&2
  exit 1
fi

OLD_VERSION="$(cat "$ROOT/kit/VERSION" 2>/dev/null || echo "unknown")"
NEW_VERSION="$(cat "$SRC/VERSION" 2>/dev/null || echo "unknown")"

# kit/entry-points.txt travels with kit/, so an update can start listing a tool
# this project has no entry file for. check.sh cannot report that: it reads a
# missing entry as a deliberate deletion, which is exactly what lets a project
# drop the tools it does not use. Only here are both lists in hand, so only
# here can the two be told apart. Keep the old one before it is overwritten.
OLD_LIST="$tmp/old-entry-points.txt"
if [ -f "$ROOT/kit/entry-points.txt" ]; then
  cp "$ROOT/kit/entry-points.txt" "$OLD_LIST"
else
  : > "$OLD_LIST"
fi

rm -rf "$ROOT/kit"
cp -R "$SRC" "$ROOT/kit"

echo "kit/ updated: $OLD_VERSION -> $NEW_VERSION"

arrived=""
if [ -f "$ROOT/kit/entry-points.txt" ]; then
  while read -r e; do
    case "$e" in ''|\#*) continue ;; esac
    grep -qxF "$e" "$OLD_LIST" && continue
    [ -f "$ROOT/$e" ] && continue
    arrived="$arrived $e"
  done < "$ROOT/kit/entry-points.txt"
fi

if [ -n "$arrived" ]; then
  echo
  echo "This update supports tools you have no entry file for:"
  for e in $arrived; do echo "    $e"; done
  echo
  echo "Each of those is the file that makes one tool read AGENTS.md without"
  echo "being asked. Create the ones you use, copying the body of an entry you"
  echo "already have. A tool you do not use needs nothing — an absent entry is"
  echo "how a project opts out, which is also why check.sh cannot raise this."
fi

echo
echo "Nothing outside kit/ was written. The scripts live in kit/scripts/ and"
echo "came with it; scripts/ holds only the stubs that hand over to them."
echo "Run scripts/check.sh: a skill added or removed upstream needs its stub"
echo "adding or removing, and check.sh is what reports that."
