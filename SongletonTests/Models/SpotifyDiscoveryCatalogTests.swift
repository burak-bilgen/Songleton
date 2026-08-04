import Foundation

final class SpotifyDiscoveryCatalogTests {
    func runAllTests() {
        runTest(name: "testTurkeyCatalogHasFivePlayablePicks", test: testTurkeyCatalogHasFivePlayablePicks)
        runTest(name: "testFallbackCatalogHasFivePlayablePicks", test: testFallbackCatalogHasFivePlayablePicks)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testTurkeyCatalogHasFivePlayablePicks() {
        let playlists = SpotifyDiscoveryCatalog.playlists(for: Locale(identifier: "tr_TR"))
        assertEqual(playlists.count, 5)
        assertEqual(Set(playlists.map(\.id)).count, 5)
        assertTrue(playlists.allSatisfy { $0.uri.hasPrefix("spotify:playlist:") })
        assertTrue(playlists.allSatisfy { $0.startingTrackURI.hasPrefix("spotify:track:") })
    }

    private func testFallbackCatalogHasFivePlayablePicks() {
        let playlists = SpotifyDiscoveryCatalog.playlists(for: Locale(identifier: "nl_NL"))
        assertEqual(playlists.count, 5)
        assertEqual(Set(playlists.map(\.id)).count, 5)
        assertTrue(playlists.allSatisfy { $0.uri.hasPrefix("spotify:playlist:") })
        assertTrue(playlists.allSatisfy { $0.startingTrackURI.hasPrefix("spotify:track:") })
    }
}
