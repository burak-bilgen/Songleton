#!/usr/bin/env bash
# ==============================================================================
# Songleton Public Release Builder
#
# Builds, signs, notarizes, and staples a Universal 2 Songleton.dmg ready for
# public distribution outside the Mac App Store, and generates the checksum
# file and Homebrew Cask update used by the burak-bilgen/tap repository.
#
# Usage:
#   ./scripts/release.sh 1.0.0
#   ./scripts/release.sh 1.0.0 --allow-dirty     # local testing with dirty tree
#   ./scripts/release.sh 1.0.0 --skip-cask       # CI: never touch the cask
#
# Credentials (never passed on the command line):
#   DEVELOPER_ID_APPLICATION   "Developer ID Application: Name (TEAMID)"
#                              If unset, the identity is auto-detected from the
#                              keychain (must contain exactly one Developer ID).
#   DEVELOPMENT_TEAM           Team identifier (defaults to the project team).
#
# Notarization credentials — provide EITHER:
#   NOTARY_PROFILE             keychain profile name from:
#                              xcrun notarytool store-credentials <profile>
#   OR the three App Store Connect API key values:
#   APPLE_API_KEY_ID           App Store Connect API key ID
#   APPLE_API_ISSUER_ID        App Store Connect API issuer ID
#   APPLE_API_PRIVATE_KEY_PATH path to the .p8 private key file
#
# Never pass passwords, keys, or key paths on the command line. The script
# fails immediately on the first error and never produces a release artifact
# when signing, notarization, or verification fails.
# ==============================================================================

set -euo pipefail

# --- Argument parsing ---------------------------------------------------------

VERSION=""
ALLOW_DIRTY=false
SKIP_CASK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty) ALLOW_DIRTY=true; shift ;;
    --skip-cask) SKIP_CASK=true; shift ;;
    *)
      if [[ -z "$VERSION" ]]; then VERSION="$1"; shift; else
        echo "Error: unexpected argument: $1" >&2
        exit 64
      fi
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
BUILD_DIR="${ROOT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/Songleton.xcarchive"
EXPORT_DIR="${BUILD_DIR}/Export"
APP_PATH="${EXPORT_DIR}/Songleton.app"
STAGING_DIR="${BUILD_DIR}/DMGStaging"
DMG_PATH="${DIST_DIR}/Songleton.dmg"
SHA_FILE="${DIST_DIR}/Songleton.dmg.sha256"
EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"

log()  { printf '\n==> %s\n' "$*"; }
die()  { echo "Error: $*" >&2; exit 1; }

# --- 1. Validate required tools -----------------------------------------------

log "Validating required tools..."
for tool in xcodebuild codesign security hdiutil xcrun spctl stapler shasum lipo plutil python3; do
  command -v "$tool" >/dev/null 2>&1 || die "Required tool '$tool' is not installed."
done
command -v xcrun >/dev/null && xcrun notarytool --help >/dev/null 2>&1 || die "xcrun notarytool is unavailable."

# --- 2. Working tree must be clean -------------------------------------------

if [[ "$ALLOW_DIRTY" != "true" ]]; then
  if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
    die "Working tree has uncommitted changes. Commit or stash them, or pass --allow-dirty for local testing only."
  fi
fi

# --- 3. Validate the semantic version -----------------------------------------

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){2}$ ]] || die "Version must be semantic X.Y.Z, got: '${VERSION:-<empty>}'"

# --- 4. Detect project, scheme, bundle ID, and build settings ------------------

PROJECT_NAME="$(find "${ROOT_DIR}" -maxdepth 1 -name '*.xcodeproj' -print -quit 2>/dev/null | xargs -n1 basename 2>/dev/null)"
[[ -n "$PROJECT_NAME" ]] || die "No .xcodeproj found."
PROJECT_PATH="${ROOT_DIR}/${PROJECT_NAME}"
PROJECT_FORMAT="$(sed -nE 's/^[[:space:]]*objectVersion = ([0-9]+);/\1/p' "${PROJECT_PATH}/project.pbxproj" | head -n1)"
[[ -n "$PROJECT_FORMAT" && "$PROJECT_FORMAT" -le 77 ]] || die "Project format ${PROJECT_FORMAT:-?} is newer than this machine's Xcode supports (77). Downgrade objectVersion in project.pbxproj (e.g. after opening the project in a newer Xcode) and commit."
SCHEME="$(xcodebuild -list -project "${PROJECT_PATH}" 2>/dev/null | sed -nE 's/^[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*$/\1/p' | head -n1)"
[[ -n "$SCHEME" ]] || die "Could not detect the Xcode scheme."

BUILD_SETTINGS="$(xcodebuild -project "${PROJECT_PATH}" -scheme "${SCHEME}" -configuration Release -showBuildSettings 2>/dev/null)"
PROJECT_VERSION="$(sed -nE 's/^[[:space:]]*MARKETING_VERSION = (.*)$/\1/p' <<<"${BUILD_SETTINGS}" | head -n1)"
PROJECT_BUILD="$(sed -nE 's/^[[:space:]]*CURRENT_PROJECT_VERSION = (.*)$/\1/p' <<<"${BUILD_SETTINGS}" | head -n1)"
BUNDLE_ID="$(sed -nE 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = (.*)$/\1/p' <<<"${BUILD_SETTINGS}" | head -n1)"
DEPLOYMENT_TARGET="$(sed -nE 's/^[[:space:]]*MACOSX_DEPLOYMENT_TARGET = (.*)$/\1/p' <<<"${BUILD_SETTINGS}" | head -n1)"
PROJECT_TEAM="$(sed -nE 's/^[[:space:]]*DEVELOPMENT_TEAM = (.*)$/\1/p' <<<"${BUILD_SETTINGS}" | head -n1)"
PROJECT_ARCHS="$(sed -nE 's/^[[:space:]]*ARCHS = (.*)$/\1/p' <<<"${BUILD_SETTINGS}" | head -n1)"
ENTITLEMENTS_PATH="${ROOT_DIR}/Songleton/Songleton.entitlements"

log "Project:     ${PROJECT_NAME}"
log "Scheme:      ${SCHEME}"
log "Bundle ID:   ${BUNDLE_ID}"
log "Project ver: ${PROJECT_VERSION} (${PROJECT_BUILD})"
log "Deployment:  macOS ${DEPLOYMENT_TARGET}"
log "Configured:  ${PROJECT_ARCHS}"

# --- 5. Marketing version must match the requested release version ------------

if [[ "${PROJECT_VERSION}" != "${VERSION}" ]]; then
  die "Requested version ${VERSION} does not match MARKETING_VERSION ${PROJECT_VERSION} in the project. Update MARKETING_VERSION in Xcode (or Songleton.xcodeproj/project.pbxproj) and commit first."
fi

# --- 6. Clean the dedicated build and output directories -----------------------

log "Cleaning ${BUILD_DIR} and ${DIST_DIR}..."
rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

# --- 7. Resolve the signing identity -------------------------------------------

SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep 'Developer ID Application' | head -n1 | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]*([^"]+).*/\1/' | sed 's/[[:space:]]*$//')"
  [[ -n "$SIGNING_IDENTITY" ]] || SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep 'Developer ID' | head -n1 | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]*([^"]+).*/\1/' | sed 's/[[:space:]]*$//')"
fi
TEAM_ID="${DEVELOPMENT_TEAM:-${PROJECT_TEAM}}"

UNSIGNED_ONLY=false
if [[ -z "$SIGNING_IDENTITY" ]]; then
  UNSIGNED_ONLY=true
  log "WARNING: No Developer ID Application identity found in the keychain."
  log "         Building an UNSIGNED archive for local validation only."
  log "         This artifact must NOT be distributed publicly."
fi

# --- 8. Archive with the Release configuration ----------------------------------

log "Archiving ${SCHEME} (Release, ${PROJECT_ARCHS})..."
if [[ "$UNSIGNED_ONLY" == "true" ]]; then
  xcodebuild -project "${PROJECT_PATH}" -scheme "${SCHEME}" -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    ARCHS="arm64 x86_64" \
    CODE_SIGNING_ALLOWED=NO \
    archive -quiet
else
  xcodebuild -project "${PROJECT_PATH}" -scheme "${SCHEME}" -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    ARCHS="arm64 x86_64" \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    archive -quiet
fi

# --- 9. Export a Developer ID signed application --------------------------------

# Xcode's archive export signs every nested component itself; we never re-sign
# with `codesign --deep` after export.
if [[ "$UNSIGNED_ONLY" == "true" ]]; then
  log "Exporting unsigned app (validation only)..."
  mkdir -p "${EXPORT_DIR}"
  cp -R "${ARCHIVE_PATH}/Products/Applications/Songleton.app" "${APP_PATH}"
else
  cat > "${EXPORT_OPTIONS}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>stripSwiftSymbols</key>
  <true/>
</dict>
</plist>
PLIST
  log "Exporting Developer ID signed app..."
  xcodebuild -archivePath "${ARCHIVE_PATH}" \
    -exportArchive \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -exportPath "${EXPORT_DIR}" -quiet
  [[ -d "${APP_PATH}" ]] || die "Export did not produce ${APP_PATH}"
fi

# --- 10-13. Security, entitlement, and signature verification --------------------

log "Verifying signature, entitlements, and security boundaries..."

if [[ "$UNSIGNED_ONLY" == "true" ]]; then
  log "SKIP: codesign/spctl checks not applicable to the unsigned validation artifact."
else
  codesign --verify --deep --strict --verbose=2 "${APP_PATH}" 2>&1 \
    || die "codesign verification failed"
  CODESIGN_INFO="$(codesign --display --verbose=4 "${APP_PATH}" 2>&1 || true)"
  grep -q 'flags=.*runtime' <<<"${CODESIGN_INFO}" \
    || die "Hardened Runtime is not enabled on the exported app"
fi

ENTITLEMENTS_XML="$(codesign -d --entitlements - "${APP_PATH}" 2>/dev/null || true)"
for forbidden in com.apple.security.app-sandbox com.apple.security.get-task-allow \
  com.apple.security.cs.allow-dyld-environment-variables \
  com.apple.security.cs.disable-library-validation \
  com.apple.security.cs.allow-unsigned-executable-memory \
  com.apple.security.cs.disable-executable-page-protection; do
  if grep -q "${forbidden}" <<<"${ENTITLEMENTS_XML}"; then
    die "Forbidden entitlement present in the exported app: ${forbidden}"
  fi
done
log "Confirmed: App Sandbox disabled, get-task-allow absent, no weakened security entitlements."
# Note: spctl assessment of the exported app is intentionally deferred until
# after notarization, where the mounted-DMG Gatekeeper check runs below. An
# unnotarized Developer ID app is always "rejected" by spctl, so checking
# here would only produce a false alarm.

ARCHS="$(lipo -archs "${APP_PATH}/Contents/MacOS/Songleton")"
log "Binary architectures: ${ARCHS}"
[[ "$ARCHS" == *"arm64"* && "$ARCHS" == *"x86_64"* ]] \
  || die "Expected Universal 2 (arm64 x86_64) binary, got: ${ARCHS}"

# --- 14-15. Create the distribution DMG ------------------------------------------

log "Creating Songleton.dmg..."
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -volname "Songleton" -srcfolder "${STAGING_DIR}" \
  -ov -format UDZO "${DMG_PATH}" -quiet

if [[ "$UNSIGNED_ONLY" == "true" ]]; then
  log "SKIP: DMG signing and notarization skipped for the unsigned validation artifact."
else
  log "Signing DMG with secure timestamp..."
  codesign --force --sign "${SIGNING_IDENTITY}" --timestamp --options runtime "${DMG_PATH}" \
    || die "DMG signing failed"
fi

# --- 16-20. Notarization, stapling, and validation -------------------------------

if [[ "$UNSIGNED_ONLY" == "true" ]]; then
  log "SKIP: Notarization requires a Developer ID and Apple credentials."
else
  NOTARY_ARGS=()
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    NOTARY_ARGS+=(--keychain-profile "${NOTARY_PROFILE}")
  elif [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" && -n "${APPLE_API_PRIVATE_KEY_PATH:-}" ]]; then
    NOTARY_ARGS+=(--key "${APPLE_API_PRIVATE_KEY_PATH}" --key-id "${APPLE_API_KEY_ID}" --issuer "${APPLE_API_ISSUER_ID}")
  elif [[ -n "${APPLE_ID_EMAIL:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    NOTARY_ARGS+=(--apple-id "${APPLE_ID_EMAIL}" --password "${APPLE_APP_PASSWORD}" --team-id "${TEAM_ID}")
  else
    die "Notarization required but no credentials found. Set NOTARY_PROFILE, or APPLE_API_KEY_ID + APPLE_API_ISSUER_ID + APPLE_API_PRIVATE_KEY_PATH, or APPLE_ID_EMAIL + APPLE_APP_PASSWORD."
  fi

  log "Submitting DMG for Apple notarization..."
  SUBMIT_OUTPUT="$(xcrun notarytool submit "${DMG_PATH}" "${NOTARY_ARGS[@]}" --wait --output-format json 2>&1)"
  echo "${SUBMIT_OUTPUT}"
  SUBMISSION_ID="$(python3 -c 'import json,sys
d=json.loads(sys.stdin.read()); print(d.get("id",""))' <<<"${SUBMIT_OUTPUT}")"
  STATUS="$(python3 -c 'import json,sys
d=json.loads(sys.stdin.read()); print(d.get("status",""))' <<<"${SUBMIT_OUTPUT}")"
  if [[ "${STATUS}" != "Accepted" ]]; then
    echo "Error: Notarization was rejected (status: ${STATUS:-unknown})." >&2
    if [[ -n "${SUBMISSION_ID}" ]]; then
      echo "Fetching notarization log..." >&2
      xcrun notarytool log "${SUBMISSION_ID}" "${NOTARY_ARGS[@]}" >&2 || true
    fi
    exit 1
  fi
  log "Notarization accepted (submission ${SUBMISSION_ID})."

  log "Stapling the notarization ticket to the DMG..."
  xcrun stapler staple "${DMG_PATH}" || die "Stapling the DMG failed"
  xcrun stapler validate "${DMG_PATH}" || die "Staple validation failed for the DMG"

  # The app inside the DMG must also pass Gatekeeper; mount and assess it.
  log "Assessing the app inside the notarized DMG..."
  MOUNT_OUTPUT="$(hdiutil attach "${DMG_PATH}" -nobrowse -readonly)"
  MOUNT_POINT="$(awk '/\/dev\/disk/{for (i = 1; i <= NF; i++) if ($i ~ /^\/Volumes\//) print $i}' <<<"${MOUNT_OUTPUT}" | tail -n1)"
  [[ -n "$MOUNT_POINT" ]] || die "Could not mount the DMG for assessment"
  if spctl --assess --type execute --verbose=4 "${MOUNT_POINT}/Songleton.app" 2>&1; then
    log "App inside DMG passed Gatekeeper assessment."
  else
    hdiutil detach "${MOUNT_POINT}" -quiet
    die "App inside the DMG failed Gatekeeper assessment"
  fi
  hdiutil detach "${MOUNT_POINT}" -quiet
fi

# --- 21-22. Final validation and checksum -----------------------------------------

log "Validating the final DMG..."
hdiutil verify "${DMG_PATH}" -quiet || die "hdiutil verification failed"

SHA256="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
printf '%s  Songleton.dmg\n' "${SHA256}" > "${SHA_FILE}"

# --- 23. Homebrew Cask update (local flow only) -----------------------------------

if [[ "${SKIP_CASK}" != "true" && "${UNSIGNED_ONLY}" != "true" ]]; then
  CASK_PATH="${ROOT_DIR}/homebrew-tap/Casks/songleton.rb"
  if [[ -f "${CASK_PATH}" ]]; then
    log "Pinning ${CASK_PATH} to version ${VERSION} (SHA-256 ${SHA256})..."
    tmp="$(mktemp)"
    sed -E \
      -e "s/version \"[0-9.]+\"/version \"${VERSION}\"/" \
      -e "s/sha256 \"[0-9a-f]{64}\"/sha256 \"${SHA256}\"/" \
      "${CASK_PATH}" > "${tmp}"
    grep -q "sha256 \"${SHA256}\"" "${tmp}" || { rm -f "${tmp}"; die "Could not pin the cask checksum safely."; }
    mv "${tmp}" "${CASK_PATH}"
  else
    echo "Warning: Cask not found at ${CASK_PATH}; skipping cask update." >&2
  fi
fi

log "Release artifacts ready:"
log "  DMG:      ${DMG_PATH}"
log "  Checksum: ${SHA_FILE}"
log "  SHA-256:  ${SHA256}"
if [[ "$UNSIGNED_ONLY" == "true" ]]; then
  echo ""
  echo "!!! UNSIGNED VALIDATION BUILD — NOT DISTRIBUTABLE !!!" >&2
  echo "!!! Install a Developer ID Application identity and Apple credentials, then rerun." >&2
  exit 2
fi
echo "Release build complete."
