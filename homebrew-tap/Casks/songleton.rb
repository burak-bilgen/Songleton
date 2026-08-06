cask "songleton" do
  version "1.0.0"
  # SHA-256 of the notarized Songleton.dmg published for this version.
  # Pinned automatically by ./scripts/release.sh or
  # ./scripts/update-homebrew-cask.sh; never use sha256 :no_check.
  sha256 "99b6e0828a77ba89372973b901a92bc49604d8f09d5bec122dfd7c4ef1f68167"

  url "https://github.com/burak-bilgen/Songleton/releases/download/v#{version}/Songleton.dmg",
      verified: "github.com/burak-bilgen/Songleton/"
  name "Songleton"
  desc "Menu bar, screen edge, and Ambient Mode controls for music apps"
  homepage "https://burak-bilgen.github.io/Songleton/"

  livecheck do
    url "https://github.com/burak-bilgen/Songleton/releases"
    regex(%r{/releases/tag/v?(\d+(?:\.\d+)+)}i)
  end

  depends_on macos: :sonoma

  app "Songleton.app"

  uninstall quit: "bilgenworks.app.Songleton"

  zap trash: [
    "~/Library/Caches/SongletonArtwork",
    "~/Library/HTTPStorages/bilgenworks.app.Songleton",
    "~/Library/Preferences/bilgenworks.app.Songleton.plist",
    "~/Library/Saved Application State/bilgenworks.app.Songleton.savedState",
  ]
end
