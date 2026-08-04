import Foundation

final class SpotifyDiscoveryCatalogTests {
    func runAllTests() {
        runTest(name: "testEditorialCatalogHasFivePlayablePicks", test: testEditorialCatalogHasFivePlayablePicks)
        runTest(name: "testEditorialCatalogNeverUsesCommunityPlaylists", test: testEditorialCatalogNeverUsesCommunityPlaylists)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testEditorialCatalogHasFivePlayablePicks() {
        let playlists = SpotifyDiscoveryCatalog.playlists()
        assertEqual(playlists.count, 5)
        assertEqual(Set(playlists.map(\.id)).count, 5)
        assertTrue(playlists.allSatisfy { $0.uri.hasPrefix("spotify:playlist:") })
        assertTrue(playlists.allSatisfy { $0.startingTrackURI.hasPrefix("spotify:track:") })
    }

    private func testEditorialCatalogNeverUsesCommunityPlaylists() {
        let playlists = SpotifyDiscoveryCatalog.playlists()
        assertTrue(playlists.allSatisfy { $0.uri.hasPrefix("spotify:playlist:37i9") })
    }
}
