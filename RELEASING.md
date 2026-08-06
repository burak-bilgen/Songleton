# Releasing Songleton

Songleton is distributed outside the Mac App Store as a **non-sandboxed**
Developer ID application. That means every public build must be:

1. Signed with the **Developer ID Application** certificate.
2. Built with **Hardened Runtime** enabled and **App Sandbox disabled**.
3. **Notarized by Apple** and have the notarization ticket **stapled**.

There is exactly one release pipeline: [`scripts/release.sh`](scripts/release.sh),
which is also run by the GitHub Actions workflow
[`.github/workflows/release.yml`](.github/workflows/release.yml). Never publish
a DMG that did not pass through it, and never publish an unsigned, ad-hoc, or
unnotarized build. The final downloadable asset is always named
`Songleton.dmg`.

## 1. Prerequisites

- A Mac with Xcode installed (`xcodebuild -version`).
- An [Apple Developer Program](https://developer.apple.com/programs/) membership
  with a **Developer ID Application** certificate.
- A clean Git working tree before each release.

## 2. Developer ID certificate

Your certificate is usually already in the keychain after you enable
distribution in Xcode → Settings → Accounts. Verify it:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

### Export the certificate as a .p12 (for CI)

1. Open **Keychain Access** → **My Certificates**.
2. Right-click the *Developer ID Application: …* certificate → **Export "…"**.
3. Choose a password. Do not use an empty password.

The CI workflow needs this as the `MACOS_CERTIFICATE` secret (base64 of the
`.p12` file) with the password in `MACOS_CERTIFICATE_PASSWORD`:

```bash
base64 -i DeveloperIDApplication.p12 | tr -d '\n' | pbcopy
```

## 3. App Store Connect API key for notarization

Notarization uses an App Store Connect API key (Apple App Store Connect →
**Users and Access** → **Integrations** → **API Keys**). Create a key with the
*App Manager* role (or a custom role granting notarization), download the
`AuthKey_<KEY_ID>.p8` file once, and note:

- **Key ID** (`APPLE_API_KEY_ID`)
- **Issuer ID** (`APPLE_API_ISSUER_ID`)
- The `.p8` private key file (`APPLE_API_PRIVATE_KEY_PATH` locally,
  `APPLE_API_PRIVATE_KEY` base64 secret in CI)

Store the key locally outside the repository (e.g. `~/Downloads/AuthKey_….p8`),
and in a password manager. You can also use `xcrun notarytool store-credentials`
to keep the key in your keychain instead (see the `.env.release.example`).

## 4. GitHub Actions secrets

In the `burak-bilgen/Songleton` repository: **Settings → Secrets and variables →
Actions** → **New repository secret**. Define all of:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE` | base64-encoded Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | password of the `.p12` |
| `TEMP_KEYCHAIN_PASSWORD` | a strong password used only for the temporary CI keychain |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API key issuer UUID |
| `APPLE_API_PRIVATE_KEY` | base64-encoded `AuthKey_<KEY_ID>.p8` file |
| `DEVELOPMENT_TEAM` | optional; overrides the project team id (defaults to the team id in the project) |
| `DEVELOPER_ID_APPLICATION` | optional; e.g. `Developer ID Application: Your Name (TEAMID)` |

`MACOS_CERTIFICATE` and `APPLE_API_PRIVATE_KEY` are only ever decoded inside
the ephemeral runner, written to `RUNNER_TEMP`, used by `codesign`/`notarytool`,
and deleted by the workflow's `trap` cleanup even when the job fails.

## 5. Local signed and notarized build

```bash
# 1. Make sure the marketing version matches the release you want.
xcodebuild -project Songleton.xcodeproj -scheme Songleton -showBuildSettings \
  | grep MARKETING_VERSION

# 2. Provide notarization credentials (see .env.release.example).
set -a; source .env.release; set +a

# 3. Run the pipeline. The identity is auto-detected from the keychain.
./scripts/release.sh 1.0.0
```

`scripts/release.sh` archives the Release configuration with manual
Developer ID signing, exports it (no `codesign --deep`), verifies Hardened
Runtime, the absence of `get-task-allow`/App Sandbox, nested signatures,
Gatekeeper assessment, Universal 2 architectures, then builds
`dist/Songleton.dmg`, signs and notarizes it, staples the ticket, and writes
`dist/Songleton.dmg.sha256`. It fails immediately on any error. It also pins
the version and SHA-256 in `homebrew-tap/Casks/songleton.rb`.

## 6. Unsigned development builds

For day-to-day work never confuse a Debug build with a release:

```bash
make run          # Debug build + launch, signed with your development identity
make quality      # Debug + Release builds, tests, security/site/localization audits
```

An unsigned Release artifact for validation only is produced by:

```bash
./scripts/release.sh 1.0.0 --allow-dirty
```

It exits with code 2 and prints `UNSIGNED VALIDATION BUILD — NOT DISTRIBUTABLE`.
It is never uploaded anywhere.

## 7. Creating a release tag

```bash
git tag v1.0.0 -m "Songleton 1.0.0"
git push origin v1.0.0
```

Pushing a `v*` tag triggers the `Release` workflow. GitHub Actions then checks
out the exact tagged commit, imports the certificate into a temporary keychain,
runs `scripts/release.sh` (which fails if the tag version does not match the
project `MARKETING_VERSION`), creates the GitHub Release, and uploads
`Songleton.dmg` + `Songleton.dmg.sha256`. A release can be triggered manually
at any time from **Actions → Release → Run workflow**.

## 8. Verifying the downloaded DMG

```bash
cd /tmp && gh release download v1.0.0 -R burak-bilgen/Songleton
shasum -a 256 Songleton.dmg                     # compare with Songleton.dmg.sha256
hdiutil verify Songleton.dmg
xcrun stapler validate Songleton.dmg
spctl --assess --type execute --verbose=4 /Volumes/Songleton/Songleton.app   # after mounting
```

A release that fails `spctl` or has a mismatched checksum must be treated as
broken: delete the release, fix, re-release.

## 9. Publishing the Homebrew tap

Users install with:

```bash
brew tap burak-bilgen/tap
brew install --cask songleton
```

The tap is the `burak-bilgen/homebrew-tap` repository holding
`Casks/songleton.rb`. CI does not commit the cask, so after CI publishes a
release, pin the checksum to the **exact released artifact** (a locally built
DMG is not byte-identical to the CI artifact):

```bash
gh release download v1.0.0 -p Songleton.dmg -D dist
./scripts/update-homebrew-cask.sh dist/Songleton.dmg 1.0.0
```

Then commit and push the updated cask in `burak-bilgen/homebrew-tap`
(until that repository exists, commit it in this repository and point the tap
at `https://raw.githubusercontent.com/burak-bilgen/Songleton/main/homebrew-tap/Casks/songleton.rb`).

The cask intentionally starts with a fail-closed all-zero checksum; it cannot
be installed until a release pins the real SHA-256. Never use `sha256 :no_check`.

## 10. Testing on a clean machine

- Create a fresh macOS user account (System Settings → Users & Groups) and
  install there, or test on a clean Mac / VM.
- Download `Songleton.dmg`, open it, verify the app launches with **no**
  Gatekeeper warning and shows *Verified by Apple* in System Settings →
  Privacy & Security.
- Exercise Spotify/Apple Music playback, screen-edge gestures
  (Accessibility prompt), and Automation (Apple Events) prompts.
- Deny a permission, then confirm the app degrades gracefully and offers the
  System Settings link instead of crashing.

## 11. Diagnosing a rejected notarization

If `scripts/release.sh` reports a rejection, the script prints the Apple
notarization log automatically. Manually:

```bash
xcrun notarytool submit dist/Songleton.dmg \
  --key AuthKey_XXXX.p8 --key-id XXXX --issuer XXXX --wait --output-format json
# note the submission "id", then:
xcrun notarytool log <submission-id> --key AuthKey_XXXX.p8 --key-id XXXX --issuer XXXX
```

Common causes: wrong bundle identifier, missing `com.apple.security.automation.apple-events`,
the app not being signed with the Developer ID certificate, or unsigned nested
code. Fix, bump the build, and re-run.

## 12. Rotating compromised credentials

- **`.p8` API key leaked**: revoke it immediately in App Store Connect →
  API Keys, generate a new one, update `APPLE_API_PRIVATE_KEY` and
  `APPLE_API_KEY_ID` secrets.
- **`.p12` leaked**: revoke the certificate at developer.apple.com, generate a
  new one, re-export, update `MACOS_CERTIFICATE` and
  `MACOS_CERTIFICATE_PASSWORD`.
- Rotate `TEMP_KEYCHAIN_PASSWORD` alongside.
- GitHub audit log shows who triggered which workflow run.

## 13. Revoking an accidentally published release

```bash
gh release delete v1.0.0 --repo burak-bilgen/Songleton --yes
git tag -d v1.0.0 && git push origin :refs/tags/v1.0.0
```

If a bad binary was widely distributed, also consider contacting Apple
(notarization revocation) — see Apple's developer documentation on revoking
notarization. A revoked release must also be removed from the cask: revert the
cask checksum to the fail-closed placeholder or pin the fixed version.

## 14. GitHub Pages download presentation

The website in `docs/` always points to the **stable, version-independent**
asset URL:

```text
https://github.com/burak-bilgen/Songleton/releases/latest/download/Songleton.dmg
```

The DMG is never stored inside the Pages deployment. After each release,
update the visible version badge in `docs/index.html`:

```html
<span class="rm-item">v<span id="release-version">1.0.0</span></span>
```

and, if they changed, the minimum-macOS/architecture/notarized claims in the
`release-meta` block and the matching strings in `docs/app.js`
(`releaseMinMac`, `releaseArch`, `releaseSigned`). The SHA-256 and release
notes links already point at the latest release and need no changes.

`make site` (scripts/site-audit.sh) fails the build if the download buttons
stop targeting the stable asset name.
