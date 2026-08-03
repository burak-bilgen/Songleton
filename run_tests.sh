#!/bin/bash
set -euo pipefail

SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
TARGET_ARCH="$(uname -m)"
BUILD_DIR="${BUILD_DIR:-/tmp/SongletonTests}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 Compiling test suite..."

shopt -s nullglob
SWIFT_FILES=()
for file in Songleton/*.swift Songleton/App/*.swift Songleton/Controllers/*.swift Songleton/Models/*.swift Songleton/Services/*.swift Songleton/Views/*.swift SongletonTests/*.swift SongletonTests/Controllers/*.swift SongletonTests/Models/*.swift SongletonTests/Services/*.swift SongletonTests/Support/*.swift SongletonTests/Views/*.swift; do
  case "$file" in
    */SongletonApp.swift|*/AppDelegate.swift) continue ;;
  esac
  SWIFT_FILES+=("$file")
done

EXTRA_FLAGS_VALUE="${SWIFT_EXTRA_FLAGS:-}"
SWIFTC_ARGS=(
  -sdk "$SDK_PATH"
  -target "${TARGET_ARCH}-apple-macos14.0" \
  -framework Foundation \
  -framework SwiftUI \
  -framework AppKit \
  -framework ApplicationServices \
  -framework ServiceManagement \
  -parse-as-library \
  -emit-executable \
  -o "$BUILD_DIR/RunTests"
)

if [[ -n "$EXTRA_FLAGS_VALUE" ]]; then
  SWIFTC_ARGS+=( $EXTRA_FLAGS_VALUE )
fi

swiftc "${SWIFTC_ARGS[@]}" "${SWIFT_FILES[@]}"

echo "🚀 Running tests..."
"$BUILD_DIR/RunTests"
