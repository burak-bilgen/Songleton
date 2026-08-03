import Foundation

final class SettingsModelTests {
    private var userDefaults: UserDefaults!
    private var settings: SettingsModel!

    func setUp() {
        userDefaults = UserDefaults(suiteName: "SongletonTestsSuite")!
        userDefaults.removePersistentDomain(forName: "SongletonTestsSuite")
        settings = SettingsModel(userDefaults: userDefaults, launchAtLoginApplier: { _ in })
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
        runTest(name: "testStoredValuesAreClamped", test: testStoredValuesAreClamped)
        runTest(name: "testEdgeGestureHoldDuration", test: testEdgeGestureHoldDuration)
        runTest(name: "testInvalidFontFallsBackToSystem", test: testInvalidFontFallsBackToSystem)
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
        assertTrue(settings.showTrackNotifications, "showTrackNotifications should default to true")
        assertTrue(settings.horizontalGesturesEnabled, "horizontalGesturesEnabled should default to true")
        assertTrue(settings.verticalGesturesEnabled, "verticalGesturesEnabled should default to true")
        assertAccuracy(settings.edgeGestureHoldDuration, 0.5, accuracy: 0.001, "edgeGestureHoldDuration should default to 0.5")
        assertAccuracy(settings.lyricsOffset, 0.9, accuracy: 0.001, "lyricsOffset should default to 0.9")
    }

    func testPersistence() {
        settings.showArtistInMenuBar = false
        settings.menuBarWidth = 150.0
        settings.menuBarFont = .audiowide
        settings.showTrackNotifications = false
        settings.horizontalGesturesEnabled = false
        settings.verticalGesturesEnabled = false
        settings.edgeGestureHoldDuration = 1.2
        settings.lyricsOffset = 1.5

        assertFalse(userDefaults.bool(forKey: "showArtistInMenuBar"))
        assertEqual(userDefaults.double(forKey: "menuBarWidth"), 150.0)
        assertEqual(userDefaults.string(forKey: "menuBarFont"), "audiowide")
        assertFalse(userDefaults.bool(forKey: "showTrackNotifications"))
        assertFalse(userDefaults.bool(forKey: "horizontalGesturesEnabled"))
        assertFalse(userDefaults.bool(forKey: "verticalGesturesEnabled"))
        assertAccuracy(userDefaults.double(forKey: "edgeGestureHoldDuration"), 1.2, accuracy: 0.001)
        assertAccuracy(userDefaults.double(forKey: "lyricsOffset"), 1.5, accuracy: 0.001)

        // Create new instance with same userDefaults
        let newSettings = SettingsModel(userDefaults: userDefaults, launchAtLoginApplier: { _ in })
        assertFalse(newSettings.showArtistInMenuBar)
        assertEqual(newSettings.menuBarWidth, 150.0)
        assertEqual(newSettings.menuBarFont, .audiowide)
        assertFalse(newSettings.showTrackNotifications)
        assertFalse(newSettings.horizontalGesturesEnabled)
        assertFalse(newSettings.verticalGesturesEnabled)
        assertAccuracy(newSettings.edgeGestureHoldDuration, 1.2, accuracy: 0.001)
        assertAccuracy(newSettings.lyricsOffset, 1.5, accuracy: 0.001)
    }

    func testLaunchAtLoginToggle() {
        var applied: [Bool] = []
        let mock = SettingsModel(userDefaults: userDefaults, launchAtLoginApplier: { applied.append($0) })
        mock.launchAtLogin = true
        mock.launchAtLogin = false
        assertEqual(applied, [true, false])
    }

    func testStoredValuesAreClamped() {
        userDefaults.set(999, forKey: "menuBarWidth")
        userDefaults.set(-999, forKey: "lyricsOffset")
        let clamped = SettingsModel(userDefaults: userDefaults)
        assertEqual(clamped.menuBarWidth, 300)
        assertEqual(clamped.lyricsOffset, -3)

        userDefaults.set(-1, forKey: "menuBarWidth")
        userDefaults.set(999, forKey: "lyricsOffset")
        let lowerClamped = SettingsModel(userDefaults: userDefaults)
        assertEqual(lowerClamped.menuBarWidth, 80)
        assertEqual(lowerClamped.lyricsOffset, 3)
    }

    func testEdgeGestureHoldDuration() {
        userDefaults.set(-1, forKey: "edgeGestureHoldDuration")
        let lowerClamped = SettingsModel(userDefaults: userDefaults)
        assertAccuracy(lowerClamped.edgeGestureHoldDuration, 0.2, accuracy: 0.001)

        userDefaults.set(3, forKey: "edgeGestureHoldDuration")
        let upperClamped = SettingsModel(userDefaults: userDefaults)
        assertAccuracy(upperClamped.edgeGestureHoldDuration, 2.0, accuracy: 0.001)
    }

    func testInvalidFontFallsBackToSystem() {
        userDefaults.set("invalid-font", forKey: "menuBarFont")
        let invalidFontSettings = SettingsModel(userDefaults: userDefaults)
        assertEqual(invalidFontSettings.menuBarFont, .system)
    }
}
