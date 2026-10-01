#!/usr/bin/env bash
# Stub. The checker is kit/scripts/check.sh, which scripts/update-kit.sh
# replaces along with the rest of kit/. Edit that file, never this one.
exec bash "$(cd "$(dirname "$0")/.." && pwd)/kit/scripts/check.sh" "$@"
