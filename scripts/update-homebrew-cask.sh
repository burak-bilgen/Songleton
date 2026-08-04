#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/Songleton-<version>.dmg" >&2
  exit 64
fi

dmg_path="$1"
if [[ ! -f "$dmg_path" ]]; then
  echo "DMG not found: $dmg_path" >&2
  exit 66
fi

file_name="$(basename "$dmg_path")"
if [[ ! "$file_name" =~ ^Songleton-([0-9]+(\.[0-9]+)*)\.dmg$ ]]; then
  echo "Expected a file named Songleton-<version>.dmg, got: $file_name" >&2
  exit 65
fi

version="${BASH_REMATCH[1]}"
checksum="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
cask_path="homebrew-tap/Casks/songleton.rb"

if [[ ! -f "$cask_path" ]]; then
  echo "Cask not found: $cask_path" >&2
  exit 66
fi

tmp_path="$(mktemp)"
sed -E \
  -e "s/version \"[0-9.]+\"/version \"${version}\"/" \
  -e "s/sha256 (:no_check|\"[0-9a-f]+\")/sha256 \"${checksum}\"/" \
  "$cask_path" > "$tmp_path"
mv "$tmp_path" "$cask_path"

echo "Updated ${cask_path}"
echo "Version:  ${version}"
echo "SHA-256:  ${checksum}"
echo "Next: attach ${file_name} to GitHub Release v${version}."
