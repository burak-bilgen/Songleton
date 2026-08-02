import Foundation

final class SettingsModelTests {
    private var userDefaults: UserDefaults!
    private var settings: SettingsModel!

    func setUp() {
        userDefaults = UserDefaults(suiteName: "SongletonTestsSuite")!
        userDefaults.removePersistentDomain(forName: "SongletonTestsSuite")
        settings = SettingsModel(userDefaults: userDefaults)
    }

    func tearDown() {
        userDefaults.removePersistentDomain(forName: "SongletonTestsSuite")
        userDefaults = nil
        settings = nil
    }

    func runAllTests() {
        runTest(name: "testDefaultValues", test: testDefaultValues)
        runTest(name: "testPersistence", test: testPersistence)
        runTest(name: "testLaunchAtLoginToggle", test: testLaunchAtLoginToggle)
    }

    private func runTest(name: String, test: () -> Void) {
        setUp()
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
        tearDown()
    }

    func testDefaultValues() {
        assertTrue(settings.showArtistInMenuBar, "showArtistInMenuBar should default to true")
        assertEqual(settings.menuBarWidth, 80.0, "menuBarWidth should default to 80.0")
        assertEqual(settings.menuBarFont, .system, "menuBarFont should default to .system")
        assertTrue(settings.showProgressBar, "showProgressBar should default to true")
        assertTrue(settings.useDynamicColor, "useDynamicColor should default to true")
        assertAccuracy(settings.lyricsOffset, 0.9, accuracy: 0.001, "lyricsOffset should default to 0.9")
    }

    func testPersistence() {
        settings.showArtistInMenuBar = false
        settings.menuBarWidth = 150.0
        settings.menuBarFont = .audiowide
        settings.showProgressBar = false
        settings.useDynamicColor = false
        settings.lyricsOffset = 1.5

        assertFalse(userDefaults.bool(forKey: "showArtistInMenuBar"))
        assertEqual(userDefaults.double(forKey: "menuBarWidth"), 150.0)
        assertEqual(userDefaults.string(forKey: "menuBarFont"), "audiowide")
        assertFalse(userDefaults.bool(forKey: "showProgressBar"))
        assertFalse(userDefaults.bool(forKey: "useDynamicColor"))
        assertAccuracy(userDefaults.double(forKey: "lyricsOffset"), 1.5, accuracy: 0.001)

        // Create new instance with same userDefaults
        let newSettings = SettingsModel(userDefaults: userDefaults)
        assertFalse(newSettings.showArtistInMenuBar)
        assertEqual(newSettings.menuBarWidth, 150.0)
        assertEqual(newSettings.menuBarFont, .audiowide)
        assertFalse(newSettings.showProgressBar)
        assertFalse(newSettings.useDynamicColor)
        assertAccuracy(newSettings.lyricsOffset, 1.5, accuracy: 0.001)
    }

    func testLaunchAtLoginToggle() {
        let currentStatus = settings.launchAtLogin
        settings.launchAtLogin = !currentStatus
        assertEqual(userDefaults.bool(forKey: "launchAtLogin"), !currentStatus)
    }
}
