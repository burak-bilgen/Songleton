# Release flow

1. Verify the working tree is clean and run `make quality`.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode.
3. Provide the Developer ID Application certificate via `DEVELOPER_IDENTITY` and run `make archive`.
4. Run `make dmg` to create the local distribution package.
5. Set the Apple ID, team ID, and app-specific password environment variables and run `make notarize`.
6. Open the stapled DMG on a clean macOS user account and manually verify Spotify, Apple Music, Automation, and Accessibility flows.

`make archive` and `make dmg` require `DEVELOPER_IDENTITY`. `make notarize` additionally requires `APPLE_ID`, `TEAM_ID`, and `APP_PASSWORD`.

Notarization is required for every DMG distributed outside the repository. CI never uses these credentials and does not produce releases.
