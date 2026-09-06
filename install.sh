#!/bin/sh
set -eu

repository="pearl-computing/rune-releases"
version=
bin_dir="${HOME:?HOME is required}/.local/bin"
temporary_root=
temporary_binary=

fail() {
  echo "Rune installation failed: $*" >&2
  echo "The previous Rune executable was preserved. Fix the reported problem and retry." >&2
  exit 1
}

cleanup() {
  if [ -n "$temporary_binary" ]; then
    rm -f "$temporary_binary"
  fi
  if [ -n "$temporary_root" ]; then
    rm -rf "$temporary_root"
  fi
}

trap cleanup 0
trap 'exit 130' HUP INT TERM

usage() {
  echo "usage: install.sh [--version X.Y.Z] [--bin-dir DIR]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || usage
      version="${2#v}"
      shift 2
      ;;
    --bin-dir)
      [ "$#" -ge 2 ] || usage
      bin_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

echo "Installing Rune means that you accept the Rune Personal Use License Agreement:" >&2
echo "https://github.com/pearl-computing/rune-releases/blob/main/LICENSE" >&2

if [ -z "$version" ]; then
  latest_url="https://github.com/$repository/releases/latest"
  if ! effective_latest="$(curl --fail --silent --show-error --location \
    --proto '=https' --max-redirs 3 --output /dev/null \
    --write-out '%{url_effective}' "$latest_url")"; then
    fail "cannot resolve the latest stable Rune release"
  fi
  latest_host="$(printf '%s\n' "$effective_latest" | sed -n 's#^https://\([^/:]*\).*#\1#p')"
  [ "$latest_host" = "github.com" ] || \
    fail "latest release redirected to unexpected host: ${latest_host:-invalid URL}"
  version="$(printf '%s\n' "$effective_latest" | sed -n 's#^.*/releases/tag/v\([0-9][0-9.]*\)$#\1#p')"
  [ -n "$version" ] || fail "latest release did not resolve to a stable semantic version tag"
fi
case "$version" in
  *[!0-9.]*|.*|*..*|*.) fail "invalid version: $version" ;;
esac
old_ifs="$IFS"
IFS=.
set -- $version
IFS="$old_ifs"
[ "$#" -eq 3 ] || fail "invalid version: $version"

os="$(uname -s)" || fail "cannot detect operating system"
architecture="$(uname -m)" || fail "cannot detect CPU architecture"
case "$os:$architecture" in
  Linux:x86_64|Linux:amd64) target="x86_64-unknown-linux-gnu" ;;
  Linux:aarch64|Linux:arm64) target="aarch64-unknown-linux-gnu" ;;
  Darwin:x86_64|Darwin:amd64) target="x86_64-apple-darwin" ;;
  Darwin:aarch64|Darwin:arm64) target="aarch64-apple-darwin" ;;
  *) fail "unsupported target: $os $architecture" ;;
esac

if [ ! -d "$bin_dir" ]; then
  mkdir -p "$bin_dir" || fail "cannot create install directory: $bin_dir"
fi
[ -w "$bin_dir" ] || fail "install directory is not writable: $bin_dir"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/rune-install.XXXXXX")" || \
  fail "cannot create temporary download directory"
archive_name="rune-${version}-${target}.tar.gz"
archive="$temporary_root/$archive_name"
checksum_asset="$archive_name.sha256"
checksum="$temporary_root/$checksum_asset"

download() {
  download_url="$1"
  download_destination="$2"
  if ! effective_url="$(curl --fail --silent --show-error --location \
    --proto '=https' --max-redirs 3 --output "$download_destination" \
    --write-out '%{url_effective}' "$download_url")"; then
    fail "download failed: $download_url"
  fi
  effective_host="$(printf '%s\n' "$effective_url" | sed -n 's#^https://\([^/:]*\).*#\1#p')"
  case "$effective_host" in
    github.com|release-assets.githubusercontent.com|objects.githubusercontent.com) ;;
    *) fail "download redirected to unexpected host: ${effective_host:-invalid URL}" ;;
  esac
}

release_base="https://github.com/$repository/releases/download/v$version"
download "$release_base/$checksum_asset" "$checksum"
download "$release_base/$archive_name" "$archive"

set -- $(sed -n '1p' "$checksum")
[ "$#" -eq 2 ] || fail "malformed checksum file"
expected_digest="$1"
checksum_name="${2#\*}"
[ "${#expected_digest}" -eq 64 ] || fail "malformed checksum digest"
case "$expected_digest" in *[!0-9a-f]*) fail "malformed checksum digest" ;; esac
[ "$checksum_name" = "$archive_name" ] || fail "checksum names an unexpected archive"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$temporary_root" && sha256sum --check "$(basename "$checksum")") || \
    fail "archive checksum verification failed"
elif command -v shasum >/dev/null 2>&1; then
  (cd "$temporary_root" && shasum -a 256 --check "$(basename "$checksum")") || \
    fail "archive checksum verification failed"
else
  fail "sha256sum or shasum is required"
fi

if ! members="$(tar -tzf "$archive")"; then
  fail "release archive is malformed"
fi
rune_member=
rune_count=0
while IFS= read -r member; do
  [ -n "$member" ] || continue
  case "$member" in
    /*|../*|*/../*|*/..) fail "release archive contains an unsafe path: $member" ;;
  esac
  case "$member" in
    rune|./rune)
      rune_member="$member"
      rune_count=$((rune_count + 1))
      ;;
  esac
done <<EOF
$members
EOF
[ "$rune_count" -eq 1 ] || fail "release archive must contain exactly one rune executable"

extract_dir="$temporary_root/extract"
mkdir "$extract_dir" || fail "cannot create archive inspection directory"
tar -xzf "$archive" -C "$extract_dir" "$rune_member" || fail "cannot extract Rune executable"
candidate="$extract_dir/rune"
[ -f "$candidate" ] && [ ! -L "$candidate" ] || fail "Rune archive member is not a regular file"

temporary_binary="$(mktemp "$bin_dir/.rune.tmp.XXXXXX")" || \
  fail "cannot create temporary executable in $bin_dir"
install -m 0755 "$candidate" "$temporary_binary" || fail "cannot stage Rune executable"
if ! actual_version="$($temporary_binary --version 2>/dev/null)"; then
  fail "staged Rune executable did not run"
fi
[ "$actual_version" = "rune $version" ] || \
  fail "staged Rune version mismatch: expected rune $version, found $actual_version"

mv -f "$temporary_binary" "$bin_dir/rune" || fail "cannot atomically replace $bin_dir/rune"
temporary_binary=
echo "Installed Rune $version to $bin_dir/rune"
