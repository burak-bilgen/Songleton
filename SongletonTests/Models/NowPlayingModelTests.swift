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
        await runTest(name: "testAutomationPermissionUsesCachedState", test: testAutomationPermissionUsesCachedState)
        await runTest(name: "testAutomationPermissionReportsMissingTarget", test: testAutomationPermissionReportsMissingTarget)
        await runTest(name: "testInstalledControllersOnlyReportsInstalledPlayers", test: testInstalledControllersOnlyReportsInstalledPlayers)
        await runTest(name: "testWindowTitleControllersUseSystemEventsPermission", test: testWindowTitleControllersUseSystemEventsPermission)
        await runTest(name: "testSystemEventsPermissionTargetIsAvailable", test: testSystemEventsPermissionTargetIsAvailable)
        await runTest(name: "testLyricsActiveLineBoundaries", test: testLyricsActiveLineBoundaries)
    }

    private func runTest(name: String, test: () async -> Void) async {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        await test()
    }

    func testShowArtistInMenuBarSetting() async {
        let settings = SettingsModel.shared
        let originalValue = settings.showArtistInMenuBar
        defer { settings.showArtistInMenuBar = originalValue }

        settings.showArtistInMenuBar = true
        assertTrue(SettingsModel.shared.showArtistInMenuBar)

        settings.showArtistInMenuBar = false
        assertFalse(SettingsModel.shared.showArtistInMenuBar)
    }

    func testLyricsOffsetIntegration() async {
        let settings = SettingsModel.shared
        let originalValue = settings.lyricsOffset
        defer { settings.lyricsOffset = originalValue }
        settings.lyricsOffset = 1.2
        assertEqual(SettingsModel.shared.lyricsOffset, 1.2)
    }

    func testLyricsActiveLineSelection() async {
        let settings = SettingsModel.shared
        let originalOffset = settings.lyricsOffset
        settings.lyricsOffset = 0
        let lyrics = LyricsModel.shared
        let originalLines = lyrics.lines
        defer {
            settings.lyricsOffset = originalOffset
            lyrics.lines = originalLines
        }
        lyrics.lines = [
            LyricLine(timestamp: 0, text: "One"),
            LyricLine(timestamp: 5, text: "Two"),
            LyricLine(timestamp: 10, text: "Three")
        ]
        assertEqual(lyrics.activeLineIndex(for: 6), 1)
        assertEqual(lyrics.activeLineIndex(for: 11), 2)
    }

    func testLanguageSelection() async {
        let localization = LocalizationManager.shared
        let originalLanguage = localization.language
        defer { localization.language = originalLanguage }
        localization.language = .english
        assertEqual(localization.resolvedLanguageCode, "en")
        localization.language = .turkish
        assertEqual(localization.resolvedLanguageCode, "tr")
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

    func testAutomationPermissionUsesCachedState() async {
        let bundleID = "bilgenworks.app.Songleton.tests.missing-player"
        let key = "permission_\(bundleID)"
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        assertFalse(AutomationPermission.isGranted(bundleID: bundleID))

        defaults.set(true, forKey: key)
        assertTrue(AutomationPermission.isGranted(bundleID: bundleID))

        defaults.set(false, forKey: key)
        assertFalse(AutomationPermission.isGranted(bundleID: bundleID))
    }

    func testAutomationPermissionReportsMissingTarget() async {
        assertEqual(
            AutomationPermission.status(bundleID: "bilgenworks.app.Songleton.tests.missing-player"),
            .targetNotRunning
        )
    }

    func testInstalledControllersOnlyReportsInstalledPlayers() async {
        let installed = NowPlayingModel.shared.installedControllers
        // Apple Music ships with every macOS install, so it must always appear.
        assertTrue(installed.contains { $0.bundleID == "com.apple.Music" }, "Apple Music should be detected as installed")
        // Apps that are not installed must never appear in the list.
        assertFalse(installed.contains { $0.bundleID == "bilgenworks.app.Songleton.tests.missing-player" })
    }

    func testWindowTitleControllersUseSystemEventsPermission() async {
        let windowTitlePlayers: Set<String> = [
            "com.tidal.desktop",
            "com.deezer.deezer-desktop",
            "com.amazon.music",
            "com.github.th-ch.youtube-music",
            "com.soundcloud.desktop",
            "com.qobuz.QobuzDesktop"
        ]
        for controller in NowPlayingModel.shared.controllers {
            if windowTitlePlayers.contains(controller.bundleID) {
                assertEqual(
                    controller.permissionBundleID,
                    AutomationPermission.systemEventsBundleID,
                    "\(controller.displayName) should be gated by the System Events permission"
                )
            } else {
                assertEqual(
                    controller.permissionBundleID,
                    controller.bundleID,
                    "\(controller.displayName) should be gated by its own permission"
                )
            }
        }
    }

    func testSystemEventsPermissionTargetIsAvailable() async {
        let status = AutomationPermission.status(bundleID: AutomationPermission.systemEventsBundleID)
        assertTrue(
            status != .targetNotRunning,
            "System Events is always running, so the permission probe must never report targetNotRunning"
        )
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
