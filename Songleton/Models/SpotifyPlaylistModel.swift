import AppKit
import Combine
import Foundation

// MARK: - SpotifyPlaylist

struct SpotifyPlaylist: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let uri: String
    let iconName: String
    let isUserAdded: Bool

    static let defaults: [SpotifyPlaylist] = [
        SpotifyPlaylist(
            id: "liked-songs",
            name: "Beğenilen Şarkılar",
            description: "Spotify Kitaplığın",
            uri: "spotify:user:spotify:collection",
            iconName: "heart.fill",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "todays-top-hits",
            name: "Today's Top Hits",
            description: "Dünya Çapında Popüler",
            uri: "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M",
            iconName: "flame.fill",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "deep-focus",
            name: "Deep Focus",
            description: "Odaklanma & Çalışma",
            uri: "spotify:playlist:37i9dQZF1DWZEtxA0PvYk2",
            iconName: "brain.head.profile",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "lofi-beats",
            name: "Lofi Beats",
            description: "Sakin & Chill Ritmler",
            uri: "spotify:playlist:37i9dQZF1DWWQRwWYiJsv0",
            iconName: "headphones",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "discover-weekly",
            name: "Haftalık Keşif",
            description: "Sana Özel Şarkılar",
            uri: "spotify:playlist:37i9dQZF1DXWj21xecL95e",
            iconName: "sparkles",
            isUserAdded: false
        )
    ]
}

// MARK: - SpotifyPlaylistModel

final class SpotifyPlaylistModel: ObservableObject {
    static let shared = SpotifyPlaylistModel()

    @Published var playlists: [SpotifyPlaylist] = []

    private let defaultsKey = "savedSpotifyPlaylists"

    private init() {
        loadPlaylists()
    }

    func loadPlaylists() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([SpotifyPlaylist].self, from: data) {
            playlists = saved
        } else {
            playlists = SpotifyPlaylist.defaults
            savePlaylists()
        }
    }

    func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    func addPlaylist(name: String, urlOrUri: String) -> Bool {
        let uri = parseURI(from: urlOrUri)
        guard !uri.isEmpty else { return false }

        let newPlaylist = SpotifyPlaylist(
            id: UUID().uuidString,
            name: name.isEmpty ? "Çalma Listesi" : name,
            description: "Eklenen Playlist",
            uri: uri,
            iconName: "music.note.list",
            isUserAdded: true
        )

        playlists.append(newPlaylist)
        savePlaylists()
        return true
    }

    func removePlaylist(at id: String) {
        playlists.removeAll { $0.id == id && $0.isUserAdded }
        savePlaylists()
    }

    func play(playlist: SpotifyPlaylist) {
        let script = """
        tell application "Spotify"
            if it is running then
                play track "\(playlist.uri)"
            end if
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    private func parseURI(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("spotify:playlist:") || trimmed.hasPrefix("spotify:user:") {
            return trimmed
        }
        if let url = URL(string: trimmed), url.host?.contains("spotify.com") == true {
            let pathComponents = url.pathComponents
            if let index = pathComponents.firstIndex(of: "playlist"), index + 1 < pathComponents.count {
                let playlistID = pathComponents[index + 1]
                return "spotify:playlist:\(playlistID)"
            }
        }
        return ""
    }
}
