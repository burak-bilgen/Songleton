import Foundation
import SwiftUI

@MainActor
final class NowPlayingModelTests {
    func runAllTests() async {
        await runTest(name: "testPlatformAccentColorDynamicToggle", test: testPlatformAccentColorDynamicToggle)
        await runTest(name: "testShowArtistInMenuBarSetting", test: testShowArtistInMenuBarSetting)
        await runTest(name: "testLyricsOffsetIntegration", test: testLyricsOffsetIntegration)
        await runTest(name: "testYouTubeControllerIntegration", test: testYouTubeControllerIntegration)
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

    func testYouTubeControllerIntegration() async {
        let ytController = YouTubeController()
        assertEqual(ytController.displayName, "YouTube")
        assertEqual(ytController.scriptAppName, "YouTube")
    }
}
