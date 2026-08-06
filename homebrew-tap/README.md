# Songleton Homebrew Tap

This directory keeps the Songleton cask next to the app source. It is
published as the `burak-bilgen/tap` Homebrew tap (repository
`burak-bilgen/homebrew-tap`, file `Casks/songleton.rb`) so users can install
with:

```bash
brew tap burak-bilgen/tap
brew install --cask songleton
```

or directly from this repository until the tap exists:

```bash
brew install --cask https://raw.githubusercontent.com/burak-bilgen/Songleton/main/homebrew-tap/Casks/songleton.rb
```

## Releasing

The cask is pinned to the versioned GitHub Release asset:

```text
https://github.com/burak-bilgen/Songleton/releases/download/v1.0.0/Songleton.dmg
```

The `version` and `sha256` fields are updated by the release pipeline:

1. `./scripts/release.sh 1.0.0` builds, signs, notarizes, and staples the DMG,
   then pins the version and SHA-256 in this cask. CI runs the same script with
   `--skip-cask` and publishes the assets to the GitHub Release.
2. After CI publishes, download the exact released DMG and pin the checksum
   (a locally built DMG is not byte-identical to the CI artifact):

   ```bash
   gh release download v1.0.0 -p Songleton.dmg -D dist
   ./scripts/update-homebrew-cask.sh dist/Songleton.dmg 1.0.0
   ```

3. Commit the cask change to the `burak-bilgen/homebrew-tap` repository
   (or to this repository until the tap exists) and push.

The checked-in all-zero checksum is a fail-closed staging value: installation
fails until a real release pins the digest. Never use `sha256 :no_check`; a
pinned checksum is the integrity check Homebrew users receive.
