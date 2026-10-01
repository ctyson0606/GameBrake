#!/usr/bin/env bash
# Stub. The updater is kit/scripts/update-kit.sh, which replaces kit/ and so
# updates itself. Edit that file, never this one.
exec bash "$(cd "$(dirname "$0")/.." && pwd)/kit/scripts/update-kit.sh" "$@"
