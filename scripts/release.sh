#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Songleton Release Script
# Builds, verifies, packages, and prepares Songleton for public distribution.
# ==============================================================================

VERSION=""
ALLOW_DIRTY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"
      fi
      shift
      ;;
  esac
done

echo "=================================================="
echo "🚀 Songleton Public Release Builder"
echo "=================================================="

# 1. Validate required tools
for tool in xcodebuild codesign security hdiutil xcrun shasum lipo; do
  command -v "$tool" >/dev/null || { echo "Error: Required tool '$tool' is not installed." >&2; exit 1; }
done

# 2. Check git status
if [[ "$ALLOW_DIRTY" != "true" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: Working directory has uncommitted changes. Use --allow-dirty to override for local testing." >&2
    exit 1
  fi
fi

# 3. Resolve version
PROJECT_VERSION="$(xcodebuild -showBuildSettings -configuration Release 2>/dev/null | sed -nE 's/^[[:space:]]*MARKETING_VERSION = (.*)$/\1/p' | head -n1)"

if [[ -z "$VERSION" ]]; then
  VERSION="$PROJECT_VERSION"
fi

if [[ -z "$VERSION" ]]; then
  echo "Error: Could not determine marketing version." >&2
  exit 1
fi

echo "📦 Release Version: ${VERSION}"

# 4. Clean output directories
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
BUILD_DIR="${ROOT_DIR}/build"

rm -rf "${DIST_DIR}" "${BUILD_DIR}"
mkdir -p "${DIST_DIR}" "${BUILD_DIR}"

# 5. Build Release Archive and Export
echo "🔨 Building Universal 2 (arm64 + x86_64) Release Bundle..."

ARCHIVE_PATH="${BUILD_DIR}/Songleton.xcarchive"
APP_EXPORT_DIR="${BUILD_DIR}/Export"
APP_PATH="${APP_EXPORT_DIR}/Songleton.app"

# Determine signing strategy
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -n "${SIGNING_IDENTITY}" ]]; then
  echo "🔑 Signing with Developer ID: ${SIGNING_IDENTITY}"
  xcodebuild -project "${ROOT_DIR}/Songleton.xcodeproj" \
    -scheme "Songleton" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    ARCHS="arm64 x86_64" \
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-Z8P38BHKU6}" \
    CODE_SIGN_STYLE="Manual" \
    archive -quiet
else
  echo "⚠️  DEVELOPER_ID_APPLICATION not provided. Building unsigned/development Release archive for local validation."
  xcodebuild -project "${ROOT_DIR}/Songleton.xcodeproj" \
    -scheme "Songleton" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    ARCHS="arm64 x86_64" \
    CODE_SIGNING_ALLOWED=NO \
    archive -quiet
fi

# Export application from archive
mkdir -p "${APP_EXPORT_DIR}"
cp -R "${ARCHIVE_PATH}/Products/Applications/Songleton.app" "${APP_EXPORT_DIR}/"

# Re-sign with timestamp if identity is present
if [[ -n "${SIGNING_IDENTITY}" ]]; then
  echo "🔏 Signing exported application bundle with timestamp..."
  codesign --force --deep --options runtime --timestamp \
    --sign "${SIGNING_IDENTITY}" \
    --entitlements "${ROOT_DIR}/Songleton/Songleton.entitlements" \
    "${APP_PATH}"
fi

# 6. Security and Entitlement Guardrails Verification
echo "🛡️  Validating security and entitlement boundaries..."

ENTITLEMENTS="$(codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null || cat "${ROOT_DIR}/Songleton/Songleton.entitlements")"

if grep -q "com.apple.security.app-sandbox" <<< "${ENTITLEMENTS}"; then
  echo "Error: App Sandbox MUST be disabled for non-sandboxed Developer ID release." >&2
  exit 1
fi

if grep -q "com.apple.security.get-task-allow" <<< "${ENTITLEMENTS}"; then
  echo "Error: get-task-allow entitlement present in Release build!" >&2
  exit 1
fi

# Verify architectures
ARCHS="$(lipo -archs "${APP_PATH}/Contents/MacOS/Songleton")"
echo "📐 Binary Architectures: ${ARCHS}"
if [[ "$ARCHS" != *"arm64"* || "$ARCHS" != *"x86_64"* ]]; then
  echo "Warning: Expected Universal 2 binary (arm64 x86_64), got: ${ARCHS}"
fi

# 7. Create Distribution DMG
echo "💿 Creating Songleton.dmg..."

STAGING_DIR="${BUILD_DIR}/DMGStaging"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

DMG_PATH="${DIST_DIR}/Songleton.dmg"

hdiutil create -volname "Songleton" \
  -srcfolder "${STAGING_DIR}" \
  -ov -format UDZO \
  "${DMG_PATH}" -quiet

if [[ -n "${SIGNING_IDENTITY}" ]]; then
  echo "🔏 Signing DMG..."
  codesign --force --sign "${SIGNING_IDENTITY}" --timestamp "${DMG_PATH}"
fi

# 8. Notarization step if credentials present
if [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" && -n "${APPLE_API_PRIVATE_KEY_PATH:-}" ]]; then
  echo "📬 Submitting DMG for Apple Notarization..."
  xcrun notarytool submit "${DMG_PATH}" \
    --key "${APPLE_API_PRIVATE_KEY_PATH}" \
    --key-id "${APPLE_API_KEY_ID}" \
    --issuer "${APPLE_API_ISSUER_ID}" \
    --wait

  echo "📌 Stapling Notarization ticket..."
  xcrun stapler staple "${DMG_PATH}"
  xcrun stapler validate "${DMG_PATH}"
else
  echo "ℹ️  Notarization credentials not present in environment. Skipping Apple Notarization."
fi

# 9. Verification & Checksum
echo "🔍 Validating final DMG..."
hdiutil verify "${DMG_PATH}" -quiet

SHA256="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
echo "${SHA256}  Songleton.dmg" > "${DIST_DIR}/Songleton.dmg.sha256"

# Update Homebrew Cask
CASK_PATH="${ROOT_DIR}/homebrew-tap/Casks/songleton.rb"
if [[ -f "${CASK_PATH}" ]]; then
  sed -i '' -E "s/version \"[0-9.]+\"/version \"${VERSION}\"/" "${CASK_PATH}"
  sed -i '' -E "s/sha256 \"[0-9a-f]{64}\"/sha256 \"${SHA256}\"/" "${CASK_PATH}"
  echo "🍺 Updated Homebrew Cask: ${CASK_PATH}"
fi

echo "=================================================="
echo "✅ Build Complete!"
echo "📍 DMG Asset:      ${DMG_PATH}"
echo "📍 Checksum File:  ${DIST_DIR}/Songleton.dmg.sha256"
echo "🔑 SHA-256 Digest: ${SHA256}"
echo "=================================================="
