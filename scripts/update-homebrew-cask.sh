#!/usr/bin/env bash
# ==============================================================================
# Pin the Homebrew Cask to the checksum of a published Songleton.dmg.
#
# Usage:
#   ./scripts/update-homebrew-cask.sh /path/to/Songleton.dmg [VERSION]
#
# VERSION defaults to the version already present in the cask. Always run this
# with the DMG downloaded from the published GitHub Release, never with a
# locally built one, so the pinned checksum matches what users actually get.
# ==============================================================================
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 /path/to/Songleton.dmg [VERSION]" >&2
  exit 64
fi

dmg_path="$1"
version="${2:-}"
if [[ ! -f "$dmg_path" ]]; then
  echo "DMG not found: $dmg_path" >&2
  exit 66
fi

file_name="$(basename "$dmg_path")"
if [[ "$file_name" != "Songleton.dmg" && ! "$file_name" =~ ^Songleton-([0-9]+(\.[0-9]+)*)\.dmg$ ]]; then
  echo "Expected a file named Songleton.dmg (or Songleton-<version>.dmg), got: $file_name" >&2
  exit 65
fi

checksum="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
cask_path="homebrew-tap/Casks/songleton.rb"

if [[ ! -f "$cask_path" ]]; then
  echo "Cask not found: $cask_path" >&2
  exit 66
fi

if [[ -z "$version" ]]; then
  version="$(sed -nE 's/^[[:space:]]*version "([0-9.]+)"/\1/p' "$cask_path" | head -n1)"
  [[ -n "$version" ]] || { echo "Could not read the version from $cask_path" >&2; exit 65; }
fi

tmp_path="$(mktemp)"
sed -E \
  -e "s/version \"[0-9.]+\"/version \"${version}\"/" \
  -e "s/sha256 \"[0-9a-f]{64}\"/sha256 \"${checksum}\"/" \
  "$cask_path" > "$tmp_path"
if ! grep -q "sha256 \"${checksum}\"" "$tmp_path"; then
  echo "Could not replace the cask checksum safely" >&2
  rm -f "$tmp_path"
  exit 65
fi
mv "$tmp_path" "$cask_path"

echo "Updated ${cask_path}"
echo "Version:  ${version}"
echo "SHA-256:  ${checksum}"
echo "Next: commit the cask and push so burak-bilgen/tap users get the pinned checksum."
