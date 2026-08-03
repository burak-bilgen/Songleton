import Foundation

final class SpotifyPlaylistModelTests {
    private var defaults: UserDefaults!
    private var model: SpotifyPlaylistModel!

    func runAllTests() {
        runTest(name: "testURIValidationMatrix", test: testURIValidationMatrix)
        runTest(name: "testAddAndRemoveUserPlaylist", test: testAddAndRemoveUserPlaylist)
        runTest(name: "testCorruptSavedDataFallsBackToDefaults", test: testCorruptSavedDataFallsBackToDefaults)
    }

    private func runTest(name: String, test: () -> Void) {
        defaults = UserDefaults(suiteName: "SongletonPlaylistTests")!
        defaults.removePersistentDomain(forName: "SongletonPlaylistTests")
        model = SpotifyPlaylistModel(userDefaults: defaults)
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
        defaults.removePersistentDomain(forName: "SongletonPlaylistTests")
        model = nil
        defaults = nil
    }

    private func testURIValidationMatrix() {
        assertEqual(SpotifyPlaylistModel.normalizedURI(from: "  https://play.spotify.com/playlist/abc123#x "), "spotify:playlist:abc123")
        assertEqual(SpotifyPlaylistModel.normalizedURI(from: "spotify:user:test_user:collection"), "spotify:user:test_user:collection")
        assertEqual(SpotifyPlaylistModel.normalizedURI(from: "spotify:user:bad-user:collection"), "")
        assertEqual(SpotifyPlaylistModel.normalizedURI(from: "http://open.spotify.com/playlist/abc"), "")
        assertEqual(SpotifyPlaylistModel.normalizedURI(from: "https://open.spotify.com/album/abc"), "")
        assertEqual(SpotifyPlaylistModel.normalizedURI(from: "spotify:playlist:"), "")
    }

    private func testAddAndRemoveUserPlaylist() {
        let initialCount = model.playlists.count
        assertFalse(model.addPlaylist(name: "", urlOrUri: "not spotify"))
        assertTrue(model.addPlaylist(name: "My Mix", urlOrUri: "https://open.spotify.com/playlist/abc123"))
        assertEqual(model.playlists.count, initialCount + 1)
        guard let added = model.playlists.last else {
            assertTrue(false, "Added playlist should exist")
            return
        }
        assertEqual(added.name, "My Mix")
        assertTrue(added.isUserAdded)
        model.removePlaylist(at: added.id)
        assertEqual(model.playlists.count, initialCount)
        model.removePlaylist(at: SpotifyPlaylist.defaults[0].id)
        assertEqual(model.playlists.count, initialCount)
    }

    private func testCorruptSavedDataFallsBackToDefaults() {
        defaults.set(Data("bad".utf8), forKey: "savedSpotifyPlaylists")
        let fresh = SpotifyPlaylistModel(userDefaults: defaults)
        assertEqual(fresh.playlists, SpotifyPlaylist.defaults)
    }
}
