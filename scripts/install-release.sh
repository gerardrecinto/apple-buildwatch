#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'error: %s\n' "$1" >&2; exit 1; }
version="${1:-}"
if ! printf '%s\n' "$version" | LC_ALL=C grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z][0-9A-Za-z.-]*)?$'; then
  fail 'Pass an explicit release tag, for example scripts/install-release.sh v1.2.2. Check that the release includes SHA256SUMS first; v1.2.1 and earlier do not.'
fi
for tool in curl shasum unzip install; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required command not found: $tool. Build from source instead."
done
base="${BUILDWATCH_RELEASE_BASE_URL:-https://github.com/gerardrecinto/apple-buildwatch/releases/download}"
destination="${BUILDWATCH_INSTALL_DIR:-$HOME/.local/bin}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fL --connect-timeout 15 --max-time 120 "$base/$version/SHA256SUMS" -o "$work/SHA256SUMS" || fail "Could not download SHA256SUMS for $version. This release may not provide it; v1.2.1 and earlier do not. Check the release page or build from source. Nothing was installed."
curl -fL --connect-timeout 15 --max-time 120 "$base/$version/buildwatch-macos.zip" -o "$work/buildwatch-macos.zip" || fail "Could not download the binary archive for $version. Nothing was installed."
expected="$(awk '$2 == "buildwatch-macos.zip" && NF == 2 { value = tolower($1); count++ } END { if (count == 1) print value; else exit 1 }' "$work/SHA256SUMS")" || fail 'SHA256SUMS must contain exactly one SHA-256 value for buildwatch-macos.zip. Nothing was installed.'
printf '%s\n' "$expected" | LC_ALL=C grep -Eq '^[0-9a-fA-F]{64}$' || fail 'SHA256SUMS must contain exactly one SHA-256 value for buildwatch-macos.zip. Nothing was installed.'
actual="$(shasum -a 256 "$work/buildwatch-macos.zip" | awk '{ print $1 }')"
[ "$expected" = "$actual" ] || fail 'Archive checksum did not match SHA256SUMS. Nothing was installed.'
unzip -p "$work/buildwatch-macos.zip" buildwatch > "$work/buildwatch" || fail 'The archive did not contain buildwatch. Nothing was installed.'
[ -s "$work/buildwatch" ] || fail 'The archive contained an empty executable. Nothing was installed.'
mkdir -p "$destination"
install -m 755 "$work/buildwatch" "$destination/buildwatch"
printf 'Installed %s after checksum verification.\nRun "%s" version to check it.\n' "$destination/buildwatch" "$destination/buildwatch"
