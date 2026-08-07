cask "songleton" do
  version "1.0.2"
  # SHA-256 of the notarized Songleton.dmg published for this version.
  # Pinned automatically by ./scripts/release.sh or
  # ./scripts/update-homebrew-cask.sh; never disable checksum verification.
  sha256 "8b4d58e9187a1bbfe7cbe1fbfe743993768e093eb7742f97fdfb3107d30d13c7"

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
