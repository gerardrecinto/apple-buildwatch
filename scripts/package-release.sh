#!/usr/bin/env bash
set -euo pipefail

binary="${1:-.build/release/buildwatch}"
output="${2:-.}"
if [ ! -f "$binary" ]; then
  printf 'Release binary not found: %s\n' "$binary" >&2
  exit 1
fi
mkdir -p "$output"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp "$binary" "$stage/buildwatch"
chmod 755 "$stage/buildwatch"
(cd "$stage" && zip -q buildwatch-macos.zip buildwatch)
(cd "$stage" && shasum -a 256 buildwatch-macos.zip > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
mv "$stage/buildwatch-macos.zip" "$output/buildwatch-macos.zip"
mv "$stage/SHA256SUMS" "$output/SHA256SUMS"
printf 'Packaged %s with SHA256SUMS in %s\n' "$binary" "$output"
