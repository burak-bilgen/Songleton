# Release flow

1. Verify the working tree is clean and run `make quality`. This audits security boundaries, localization, the website, tests, and warning-free Debug and universal Release builds.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode.
3. Provide the Developer ID Application certificate via `DEVELOPER_IDENTITY` and run `make archive`.
4. Run `make dmg` to create the local distribution package.
5. Store notarization credentials once with `xcrun notarytool store-credentials <profile>`.
6. Set `NOTARY_PROFILE=<profile>` and run `make notarize`.
7. Run `scripts/update-homebrew-cask.sh build/Songleton-<version>.dmg` and verify the cask contains the real release checksum, not the fail-closed placeholder.
8. Open the stapled DMG on a clean macOS user account and manually verify Spotify, Apple Music, Automation, and Accessibility flows.

`make archive` and `make dmg` require `DEVELOPER_IDENTITY`. `make notarize` requires the Keychain profile named by `NOTARY_PROFILE`. Passwords are never accepted as command-line arguments or environment-variable fallbacks.

Notarization is required for every DMG distributed outside the repository. CI never uses these credentials and does not produce releases.
