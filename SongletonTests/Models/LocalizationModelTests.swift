import Foundation

@MainActor
final class LocalizationModelTests {
    func runAllTests() {
        runTest(name: "testExplicitLanguageResolution", test: testExplicitLanguageResolution)
        runTest(name: "testLanguagePersistenceAndFallback", test: testLanguagePersistenceAndFallback)
        runTest(name: "testLocaleAndLanguageIdentifiers", test: testLocaleAndLanguageIdentifiers)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testExplicitLanguageResolution() {
        let defaults = UserDefaults(suiteName: "SongletonLocalizationTests")!
        defaults.removePersistentDomain(forName: "SongletonLocalizationTests")
        let localization = LocalizationManager(userDefaults: defaults)
        localization.language = .english
        assertEqual(localization.resolvedLanguageCode, "en")
        localization.language = .turkish
        assertEqual(localization.resolvedLanguageCode, "tr")
        assertEqual(LocalizationManager.Language.english.id, "en")
        defaults.removePersistentDomain(forName: "SongletonLocalizationTests")
    }

    private func testLanguagePersistenceAndFallback() {
        let defaults = UserDefaults(suiteName: "SongletonLocalizationTests")!
        defaults.removePersistentDomain(forName: "SongletonLocalizationTests")
        defaults.set("invalid", forKey: "language")
        let localization = LocalizationManager(userDefaults: defaults)
        assertEqual(localization.language, .system)
        localization.language = .turkish
        assertEqual(defaults.string(forKey: "language"), "tr")
        defaults.removePersistentDomain(forName: "SongletonLocalizationTests")
    }

    private func testLocaleAndLanguageIdentifiers() {
        let localization = LocalizationManager(userDefaults: UserDefaults(suiteName: "SongletonLocalizationTests")!)
        localization.language = .english
        assertEqual(localization.locale.identifier, "en")
        localization.language = .turkish
        assertEqual(localization.locale.identifier, "tr")
    }
}
