import Foundation
import SwiftUI

@MainActor
final class NowPlayingModelTests {
    func runAllTests() async {
        await runTest(name: "testPlatformAccentColorDynamicToggle", test: testPlatformAccentColorDynamicToggle)
        await runTest(name: "testShowArtistInMenuBarSetting", test: testShowArtistInMenuBarSetting)
        await runTest(name: "testLyricsOffsetIntegration", test: testLyricsOffsetIntegration)
        await runTest(name: "testLyricsActiveLineSelection", test: testLyricsActiveLineSelection)
        await runTest(name: "testLanguageSelection", test: testLanguageSelection)
        await runTest(name: "testMediaValueSanitization", test: testMediaValueSanitization)
        await runTest(name: "testMediaValueBoundaries", test: testMediaValueBoundaries)
        await runTest(name: "testLyricsActiveLineBoundaries", test: testLyricsActiveLineBoundaries)
    }

    private func runTest(name: String, test: () async -> Void) async {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        await test()
    }

    func testPlatformAccentColorDynamicToggle() async {
        let settings = SettingsModel.shared

        settings.useDynamicColor = true
        assertTrue(settings.useDynamicColor)

        settings.useDynamicColor = false
        assertEqual(NowPlayingModel.shared.platformAccentColor, .white)

        // Reset
        settings.useDynamicColor = true
    }

    func testShowArtistInMenuBarSetting() async {
        let settings = SettingsModel.shared

        settings.showArtistInMenuBar = true
        assertTrue(SettingsModel.shared.showArtistInMenuBar)

        settings.showArtistInMenuBar = false
        assertFalse(SettingsModel.shared.showArtistInMenuBar)

        // Reset
        settings.showArtistInMenuBar = true
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
