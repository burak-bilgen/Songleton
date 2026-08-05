# Security

## Reporting a vulnerability

Do not disclose security or privacy vulnerabilities in a public issue. Contact the project owner privately and include the affected version, reproduction steps, impact, and a suggested fix when possible. Do not include real credentials, private listening data, or other users' data in the report.

## Security model

Songleton is a local macOS menu bar app. Its privileged capabilities are intentionally narrow:

- Apple Events control is limited in code to the Spotify and Apple Music bundle identifiers.
- The global event tap is listen-only and receives only the mouse events needed for edge gestures. It is activated after onboarding and Accessibility permission, not at launch without context.
- Release builds use Hardened Runtime and a minimal release entitlement file. Debug-only inspection entitlements must never ship.
- Remote lyric requests are restricted to `https://lrclib.net`. Remote artwork requests are restricted to Spotify CDN hosts. Redirects are checked against the same allowlist.
- Remote responses use an ephemeral session, strict timeouts, MIME checks, byte limits, and bounded image dimensions before decoding.
- Track metadata received from media apps is treated as untrusted display and query input. Control characters, bidirectional overrides, and excessive lengths are removed.

Songleton is currently distributed outside the Mac App Store. App Sandbox is intentionally not enabled because the app's global listen-only event tap and cross-app media control are core functionality. This is an accepted architectural risk, not permission to broaden filesystem, network, or process access. Any new capability must be reviewed against the entitlement and network guardrails in `scripts/security-audit.sh`.

## Data handling

Songleton stores settings locally in the app's own `UserDefaults` domain. It does not store Spotify or Music credentials and does not capture audio. Lyric lookup sends the current track title, artist, optional album, and duration to LRCLIB. Artwork is downloaded only from the URL supplied by the active supported media app and only when it belongs to an allowed Spotify CDN host.

No analytics, advertising, tracking SDK, or tracking domain is included. If that changes, the privacy documentation, network allowlist, and release review must change before shipping.

## Release invariants

Run `make quality` before packaging. A release must fail if GitHub Actions use mutable references, the Homebrew cask disables SHA-256 verification, an unsafe release entitlement appears, ATS is weakened, or the website loses its Content Security Policy. Notarization credentials must be supplied through a Keychain profile, never as command-line password arguments.
