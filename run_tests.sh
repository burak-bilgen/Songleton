#!/bin/bash
set -euo pipefail

SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
TARGET_ARCH="$(uname -m)"
BUILD_DIR="${BUILD_DIR:-/tmp/SongletonTests}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 Compiling test suite..."

# Songleton files are discovered recursively: the Xcode project uses a
# file-system-synchronized root, so this must match the on-disk tree exactly.
shopt -s nullglob
SWIFT_FILES=()
while IFS= read -r file; do
  case "$file" in
    */SongletonApp.swift|*/AppDelegate.swift) continue ;;
  esac
  SWIFT_FILES+=("$file")
done < <(find Songleton SongletonTests -name '*.swift' -type f | sort)

EXTRA_FLAGS_VALUE="${SWIFT_EXTRA_FLAGS:-}"
SWIFTC_ARGS=(
  -sdk "$SDK_PATH"
  -target "${TARGET_ARCH}-apple-macos14.0" \
  -framework Foundation \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework ApplicationServices \
  -framework ImageIO \
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
