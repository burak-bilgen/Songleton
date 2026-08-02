#!/bin/bash
set -e

SDK_PATH=$(xcrun --show-sdk-path)
BUILD_DIR="/tmp/SongletonTests"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 Compiling test suite..."

SWIFT_FILES=$(find Songleton SongletonTests -name "*.swift" | grep -v "SongletonApp.swift" | grep -v "AppDelegate.swift" | sort -u)

swiftc -sdk "$SDK_PATH" \
  -target arm64-apple-macos14.0 \
  -framework Foundation \
  -framework SwiftUI \
  -framework AppKit \
  -framework ServiceManagement \
  -parse-as-library \
  -emit-executable \
  -o "$BUILD_DIR/RunTests" \
  $SWIFT_FILES

echo "🚀 Running tests..."
"$BUILD_DIR/RunTests"
