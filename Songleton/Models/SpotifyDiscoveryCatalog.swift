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
    // Spotify no longer exposes a stable, public per-market discovery feed for
    // desktop apps without running our own authenticated service. Keep this
    // small catalog explicit, widely available, and easy to refresh rather
    // than scraping Spotify's private web endpoints.
    static func playlists(for locale: Locale = .autoupdatingCurrent) -> [SpotifyDiscoveryPlaylist] {
        let region = locale.region?.identifier.uppercased() ?? "US"
        return region == "TR" ? turkeyPicks : globalPicks
    }

    static func marketName(for locale: Locale = .autoupdatingCurrent) -> String {
        let region = locale.region?.identifier ?? "US"
        return locale.localizedString(forRegionCode: region) ?? region
    }

    private static let turkeyPicks: [SpotifyDiscoveryPlaylist] = [
        SpotifyDiscoveryPlaylist(
            id: "turkey-chart",
            title: "Türkiye Top 50",
            subtitle: "Türkiye'de güncel hitler",
            uri: "spotify:playlist:60fh5U635d9tVOuNpYdGpW",
            startingTrackURI: "spotify:track:4eBE6hpwm7aJxIY4iwgwU8",
            accentIndex: 0
        ),
        SpotifyDiscoveryPlaylist(
            id: "today-top-hits",
            title: "Today's Top Hits",
            subtitle: "Dünyada en çok çalanlar",
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
            id: "mint",
            title: "mint",
            subtitle: "Elektronikte yeni favoriler",
            uri: "spotify:playlist:37i9dQZF1DX4dyzvuaRJ0n",
            startingTrackURI: "spotify:track:263Ecah3YA4hVZHxR2Ex9p",
            accentIndex: 4
        )
    ]

    private static let globalPicks: [SpotifyDiscoveryPlaylist] = [
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
            id: "RapCaviar",
            title: "RapCaviar",
            subtitle: "Rap'in nabzı",
            uri: "spotify:playlist:37i9dQZF1DX0XUsuxWHRQd",
            startingTrackURI: "spotify:track:514joG57v4yKTsfQmz7stz",
            accentIndex: 4
        )
    ]
}
