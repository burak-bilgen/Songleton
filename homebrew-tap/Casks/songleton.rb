cask "songleton" do
  version "1.0"

  # Release-blocking placeholder. Replace it with the checksum printed by:
  # shasum -a 256 Songleton-#{version}.dmg
  # The release helper at ../../scripts/update-homebrew-cask.sh does this.
  # All-zero SHA intentionally fails closed until a release is prepared.
  sha256 "187c1fc11449e465e6c604caed0eae9f8fcb765e631f374b0c3b1fd70bd97cd1"

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
