#!/bin/sh
set -eu

case "${1:-}" in
  -s) printf '%s\n' "${RUNE_FIXTURE_OS:?fixture OS required}" ;;
  -m) printf '%s\n' "${RUNE_FIXTURE_ARCH:?fixture architecture required}" ;;
  *) echo "fake uname supports only -s and -m" >&2; exit 2 ;;
esac
