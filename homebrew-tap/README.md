# Songleton Homebrew Cask

This directory keeps the Songleton cask next to the app source until there is
a separate `homebrew-tap` repository. It can be installed directly from GitHub
after the first release is published:

```bash
brew install --cask https://raw.githubusercontent.com/burak-bilgen/Songleton/main/homebrew-tap/Casks/songleton.rb
```

Before publishing a release, create the signed and notarized DMG, then pin its
SHA-256 in the cask:

```bash
make notarize
./scripts/update-homebrew-cask.sh build/Songleton-1.0.dmg
```

Commit the updated cask, create the matching `v1.0` GitHub Release, and attach
`Songleton-1.0.dmg` to that release. The Cask URL and version must match the
release asset exactly.

The checked-in `sha256 :no_check` is intentionally a staging value. Do not
publish it as an official cask. A pinned checksum is the integrity check that
Homebrew users should receive.
