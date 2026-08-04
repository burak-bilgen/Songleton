cask "songleton" do
  version "1.0"

  # Replace :no_check with the checksum printed by:
  # shasum -a 256 Songleton-#{version}.dmg
  # The release helper at ../../scripts/update-homebrew-cask.sh does this.
  sha256 :no_check

  url "https://github.com/burak-bilgen/Songleton/releases/download/v#{version}/Songleton-#{version}.dmg"
  name "Songleton"
  desc "Native macOS music controls for Spotify and Apple Music"
  homepage "https://burak-bilgen.github.io/Songleton/"

  depends_on macos: ">= :sonoma"

  app "Songleton.app"

  zap trash: [
    "~/Library/Containers/bilgenworks.app.Songleton",
    "~/Library/Preferences/bilgenworks.app.Songleton.plist",
    "~/Library/Caches/bilgenworks.app.Songleton",
    "~/Library/HTTPStorages/bilgenworks.app.Songleton",
    "~/Library/Saved Application State/bilgenworks.app.Songleton.savedState"
  ]
end
