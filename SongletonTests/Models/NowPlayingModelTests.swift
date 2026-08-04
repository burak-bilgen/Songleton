import Foundation
import SwiftUI

@MainActor
final class NowPlayingModelTests {
    func runAllTests() async {
        await runTest(name: "testShowArtistInMenuBarSetting", test: testShowArtistInMenuBarSetting)
        await runTest(name: "testLyricsOffsetIntegration", test: testLyricsOffsetIntegration)
        await runTest(name: "testLyricsActiveLineSelection", test: testLyricsActiveLineSelection)
        await runTest(name: "testLanguageSelection", test: testLanguageSelection)
        await runTest(name: "testMediaValueSanitization", test: testMediaValueSanitization)
        await runTest(name: "testMediaValueBoundaries", test: testMediaValueBoundaries)
        await runTest(name: "testResolverPrefersPlayingController", test: testResolverPrefersPlayingController)
        await runTest(name: "testResolverUsesPausedControllerAsFallback", test: testResolverUsesPausedControllerAsFallback)
        await runTest(name: "testResolverReportsPermissionDenied", test: testResolverReportsPermissionDenied)
        await runTest(name: "testLyricsActiveLineBoundaries", test: testLyricsActiveLineBoundaries)
    }

    private func runTest(name: String, test: () async -> Void) async {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        await test()
    }

    func testShowArtistInMenuBarSetting() async {
        let settings = SettingsModel.shared

        settings.showArtistInMenuBar = true
        assertTrue(SettingsModel.shared.showArtistInMenuBar)

        settings.showArtistInMenuBar = false
        assertFalse(SettingsModel.shared.showArtistInMenuBar)

        // Reset to the app default.
        settings.showArtistInMenuBar = false
    }

    func testLyricsOffsetIntegration() async {
        let settings = SettingsModel.shared
        settings.lyricsOffset = 1.2
        assertEqual(SettingsModel.shared.lyricsOffset, 1.2)
    }

    func testLyricsActiveLineSelection() async {
        let settings = SettingsModel.shared
        settings.lyricsOffset = 0
        let lyrics = LyricsModel.shared
        lyrics.lines = [
            LyricLine(timestamp: 0, text: "One"),
            LyricLine(timestamp: 5, text: "Two"),
            LyricLine(timestamp: 10, text: "Three")
        ]
        assertEqual(lyrics.activeLineIndex(for: 6), 1)
        assertEqual(lyrics.activeLineIndex(for: 11), 2)
        lyrics.lines = []
    }

    func testLanguageSelection() async {
        let localization = LocalizationManager.shared
        localization.language = .english
        assertEqual(localization.resolvedLanguageCode, "en")
        localization.language = .turkish
        assertEqual(localization.resolvedLanguageCode, "tr")
        localization.language = .system
    }

    func testMediaValueSanitization() async {
        assertEqual(MediaValue.position(.nan), 0)
        assertEqual(MediaValue.position(-10), 0)
        assertEqual(MediaValue.position(.infinity), 0)
        assertEqual(MediaValue.volume(-1), 0)
        assertEqual(MediaValue.volume(150), 100)
        assertEqual(MediaValue.volume(.infinity), 0)
        assertEqual(MediaValue.duration(.nan), 0)
    }

    func testMediaValueBoundaries() async {
        assertEqual(MediaValue.position(7 * 24 * 60 * 60 + 1), 7 * 24 * 60 * 60)
        assertEqual(MediaValue.duration(0), 0)
        assertEqual(MediaValue.duration(-1), 0)
        assertEqual(MediaValue.duration(7 * 24 * 60 * 60 + 1), 7 * 24 * 60 * 60)
        assertEqual(MediaValue.volume(42.4), 42)
        assertEqual(MediaValue.volume(42.6), 43)
        assertEqual(MediaValue.volume(-10.0), 0)
        assertEqual(MediaValue.volume(120.0), 100)
    }

    func testResolverPrefersPlayingController() async {
        let paused = StubMediaController(name: "Paused", response: .success(makeInfo(isPlaying: false)))
        let playing = StubMediaController(name: "Playing", response: .success(makeInfo(isPlaying: true)))

        guard case .loaded(let info, let controller) = MediaControllerResolver.resolve(controllers: [paused, playing]) else {
            assertTrue(false, "Expected a loaded controller")
            return
        }
        assertTrue(info.isPlaying)
        assertEqual(controller.displayName, "Playing")
    }

    func testResolverUsesPausedControllerAsFallback() async {
        let paused = StubMediaController(name: "Paused", response: .success(makeInfo(isPlaying: false)))
        let notRunning = StubMediaController(name: "Not running", isRunning: false, response: .success(makeInfo(isPlaying: true)))

        guard case .loaded(let info, let controller) = MediaControllerResolver.resolve(controllers: [paused, notRunning]) else {
            assertTrue(false, "Expected paused fallback")
            return
        }
        assertFalse(info.isPlaying)
        assertEqual(controller.displayName, "Paused")
    }

    func testResolverReportsPermissionDenied() async {
        let denied = StubMediaController(name: "Denied", response: .failure(.permissionDenied))
        let result = MediaControllerResolver.resolve(controllers: [denied])
        if case .permissionDenied = result {
            assertTrue(true)
        } else {
            assertTrue(false, "Expected a permission-denied result")
        }
    }

    func testLyricsActiveLineBoundaries() async {
        let settings = SettingsModel.shared
        let oldOffset = settings.lyricsOffset
        let lyrics = LyricsModel.shared
        lyrics.lines = [
            LyricLine(timestamp: 2, text: "Two"),
            LyricLine(timestamp: 5, text: "Five")
        ]
        settings.lyricsOffset = 0
        assertEqual(lyrics.activeLineIndex(for: 1.99), nil)
        assertEqual(lyrics.activeLineIndex(for: 2), 0)
        assertEqual(lyrics.activeLineIndex(for: 5), 1)
        settings.lyricsOffset = 1
        assertEqual(lyrics.activeLineIndex(for: 1), 0)
        lyrics.lines = []
        assertEqual(lyrics.activeLineIndex(for: 10), nil)
        settings.lyricsOffset = oldOffset
    }
}

private struct StubMediaController: MediaController {
    let bundleID = "com.songleton.tests"
    let displayName: String
    let scriptAppName = "SongletonTests"
    let isRunning: Bool
    let response: Result<NowPlayingInfo, MediaControllerError>

    init(name: String, isRunning: Bool = true, response: Result<NowPlayingInfo, MediaControllerError>) {
        displayName = name
        self.isRunning = isRunning
        self.response = response
    }

    func fetchNowPlaying() throws -> NowPlayingInfo {
        try response.get()
    }

    func togglePlayPause() throws {}
    func nextTrack() throws {}
    func previousTrack() throws {}
    func setVolume(_ volume: Int) throws {}
    func seekTo(_ position: Double) throws {}
    func toggleShuffle() throws {}
    func setRepeatMode(_ mode: RepeatMode) throws {}
}

private func makeInfo(isPlaying: Bool) -> NowPlayingInfo {
    NowPlayingInfo(
        track: "Track",
        artist: "Artist",
        album: "Album",
        isPlaying: isPlaying,
        volume: 50,
        artworkURL: nil,
        artworkData: nil,
        position: 0,
        duration: 180,
        isShuffleEnabled: false,
        repeatMode: .off
    )
}
