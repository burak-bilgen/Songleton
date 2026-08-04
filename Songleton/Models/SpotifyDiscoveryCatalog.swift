import Foundation

nonisolated struct SpotifyDiscoveryPlaylist: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let uri: String
    let startingTrackURI: String
    let accentIndex: Int
}

nonisolated enum SpotifyDiscoveryCatalog {
    // Spotify's public discovery endpoints are no longer a reliable feed for
    // desktop apps without an authenticated service. Keep only verified
    // Spotify editorial playlist URIs here. Never substitute community lists
    // just to fill a country-specific slot.
    static func playlists() -> [SpotifyDiscoveryPlaylist] {
        editorialPicks
    }

    private static let editorialPicks: [SpotifyDiscoveryPlaylist] = [
        SpotifyDiscoveryPlaylist(
            id: "top-50-global",
            title: "Top 50 - Global",
            subtitle: "Dünyada şu an en çok çalanlar",
            uri: "spotify:playlist:37i9dQZEVXbMDoHDwVN2tF",
            startingTrackURI: "spotify:track:3iy2QuCtCzpWnR6tia39AB",
            accentIndex: 0
        ),
        SpotifyDiscoveryPlaylist(
            id: "today-top-hits",
            title: "Today's Top Hits",
            subtitle: "Günün en büyük hitleri",
            uri: "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M",
            startingTrackURI: "spotify:track:70pVCVMGjmIWPbWXDwf11e",
            accentIndex: 1
        ),
        SpotifyDiscoveryPlaylist(
            id: "new-music-friday",
            title: "New Music Friday",
            subtitle: "Yeni çıkanlar, her cuma",
            uri: "spotify:playlist:37i9dQZF1DX4JAvHpjipBk",
            startingTrackURI: "spotify:track:70pVCVMGjmIWPbWXDwf11e",
            accentIndex: 2
        ),
        SpotifyDiscoveryPlaylist(
            id: "pop-rising",
            title: "Pop Rising",
            subtitle: "Yükselen pop parçaları",
            uri: "spotify:playlist:37i9dQZF1DX1ngEVM0lKrb",
            startingTrackURI: "spotify:track:3qhlB30KknSejmIvZZLjOD",
            accentIndex: 3
        ),
        SpotifyDiscoveryPlaylist(
            id: "rap-caviar",
            title: "RapCaviar",
            subtitle: "Rap'in nabzı",
            uri: "spotify:playlist:37i9dQZF1DX0XUsuxWHRQd",
            startingTrackURI: "spotify:track:514joG57v4yKTsfQmz7stz",
            accentIndex: 4
        )
    ]
}
