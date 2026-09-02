#!/bin/sh
set -eu

output=
url=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output|-o)
      output="${2:?fake curl output path required}"
      shift 2
      ;;
    --write-out|-w|--proto|--max-redirs)
      shift 2
      ;;
    --fail|--silent|--show-error|--location)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

case "$url" in
  */releases/latest)
    printf 'https://github.com/pearl-computing/rune-releases/releases/tag/v%s' "${RUNE_FIXTURE_LATEST_VERSION:-0.1.3}"
    ;;
  */releases/download/*)
    asset="${url##*/}"
    test -n "$output"
    if [ "${RUNE_FIXTURE_INTERRUPT_ASSET:-}" = "$asset" ]; then
      printf 'partial' > "$output"
      exit 56
    fi
    cp "${RUNE_FIXTURE_ASSETS:?fixture assets required}/$asset" "$output"
    printf 'https://%s/pearl-computing/rune-releases/%s' \
      "${RUNE_FIXTURE_EFFECTIVE_HOST:-release-assets.githubusercontent.com}" "$asset"
    ;;
  *)
    echo "fake curl received unexpected URL: $url" >&2
    exit 2
    ;;
esac
