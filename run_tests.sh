#!/bin/bash
set -e

SDK_PATH=$(xcrun --show-sdk-path)
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

SWIFT_EXTRA_FLAGS=(${SWIFT_EXTRA_FLAGS:-})

swiftc -sdk "$SDK_PATH" \
  -target arm64-apple-macos14.0 \
  -framework Foundation \
  -framework SwiftUI \
  -framework AppKit \
  -framework ApplicationServices \
  -framework ServiceManagement \
  -parse-as-library \
  -emit-executable \
  -o "$BUILD_DIR/RunTests" \
  "${SWIFT_EXTRA_FLAGS[@]}" \
  "${SWIFT_FILES[@]}"

echo "🚀 Running tests..."
"$BUILD_DIR/RunTests"
