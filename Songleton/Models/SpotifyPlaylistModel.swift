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
            name: "playlist.liked_songs",
            description: "playlist.library",
            uri: "spotify:user:spotify:collection",
            iconName: "heart.fill",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "todays-top-hits",
            name: "playlist.top_hits",
            description: "playlist.popular_worldwide",
            uri: "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M",
            iconName: "flame.fill",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "deep-focus",
            name: "playlist.deep_focus",
            description: "playlist.focus",
            uri: "spotify:playlist:37i9dQZF1DWZEtxA0PvYk2",
            iconName: "brain.head.profile",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "lofi-beats",
            name: "playlist.lofi_beats",
            description: "playlist.chill",
            uri: "spotify:playlist:37i9dQZF1DWWQRwWYiJsv0",
            iconName: "headphones",
            isUserAdded: false
        ),
        SpotifyPlaylist(
            id: "discover-weekly",
            name: "playlist.discover_weekly",
            description: "playlist.personalized",
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

    private let defaults: UserDefaults
    private let defaultsKey = "savedSpotifyPlaylists"

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        loadPlaylists()
    }

    func loadPlaylists() {
        if let data = defaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([SpotifyPlaylist].self, from: data) {
            playlists = saved.map { playlist in
                guard !playlist.isUserAdded,
                      let localizedDefault = SpotifyPlaylist.defaults.first(where: { $0.id == playlist.id }) else {
                    return playlist
                }
                return localizedDefault
            }
        } else {
            playlists = SpotifyPlaylist.defaults
            savePlaylists()
        }
    }

    func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    func addPlaylist(name: String, urlOrUri: String) -> Bool {
        let uri = parseURI(from: urlOrUri)
        guard !uri.isEmpty else { return false }

        let newPlaylist = SpotifyPlaylist(
            id: UUID().uuidString,
            name: name.isEmpty ? "playlist.custom_name" : name,
            description: "playlist.added",
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
        let escapedURI = playlist.uri
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let script = """
        tell application "Spotify"
            if it is running then
                play track "\(escapedURI)"
            end if
        end tell
        """
        Task.detached {
            do {
                try AppleScriptRunner.run(script)
            } catch {
                print("Playlist playback failed: \(error)")
            }
        }
    }

    private func parseURI(from input: String) -> String {
        Self.normalizedURI(from: input)
    }

    static func normalizedURI(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("spotify:playlist:") {
            let id = String(trimmed.dropFirst("spotify:playlist:".count))
            guard id.range(of: #"^[A-Za-z0-9]+$"#, options: .regularExpression) != nil else { return "" }
            return "spotify:playlist:\(id)"
        }
        if trimmed.hasPrefix("spotify:user:") {
            let parts = trimmed.split(separator: ":")
            guard parts.count == 4, parts[1] == "user", parts[3] == "collection",
                  parts[2].range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil else { return "" }
            return trimmed
        }
        if let components = URLComponents(string: trimmed),
           components.scheme == "https",
           ["open.spotify.com", "play.spotify.com"].contains(components.host?.lowercased()) {
            let pathParts = components.path.split(separator: "/")
            if let index = pathParts.firstIndex(of: "playlist"), index + 1 < pathParts.count {
                let playlistID = String(pathParts[index + 1])
                guard playlistID.range(of: #"^[A-Za-z0-9]+$"#, options: .regularExpression) != nil else { return "" }
                return "spotify:playlist:\(playlistID)"
            }
        }
        return ""
    }
}
