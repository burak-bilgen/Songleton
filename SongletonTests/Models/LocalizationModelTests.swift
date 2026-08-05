import Foundation

@MainActor
final class LocalizationModelTests {
    func runAllTests() {
        runTest(name: "testExplicitLanguageResolution", test: testExplicitLanguageResolution)
        runTest(name: "testLanguagePersistenceAndFallback", test: testLanguagePersistenceAndFallback)
        runTest(name: "testLocaleAndLanguageIdentifiers", test: testLocaleAndLanguageIdentifiers)
        runTest(name: "testCatalogHasCompleteTranslations", test: testCatalogHasCompleteTranslations)
        runTest(name: "testLocalizedFormatPlaceholdersMatch", test: testLocalizedFormatPlaceholdersMatch)
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
        let defaultLocalization = LocalizationManager(userDefaults: defaults)
        assertEqual(defaultLocalization.language, .system)
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

    private func testCatalogHasCompleteTranslations() {
        guard let strings = localizationCatalogStrings() else {
            assertTrue(false, "Could not read Localizable.xcstrings")
            return
        }

        for (key, rawValue) in strings {
            guard let value = rawValue as? [String: Any],
                  let localizations = value["localizations"] as? [String: Any] else {
                assertTrue(false, "Missing localization dictionary for \(key)")
                continue
            }
            assertEqual(value["extractionState"] as? String, "manual", "\(key) must be manually managed")
            for language in ["en", "tr"] {
                let localization = localizations[language] as? [String: Any]
                let stringUnit = localization?["stringUnit"] as? [String: Any]
                let translatedValue = stringUnit?["value"] as? String ?? ""
                assertFalse(translatedValue.isEmpty, "Missing \(language) translation for \(key)")
                assertEqual(stringUnit?["state"] as? String, "translated", "\(key) is not marked translated in \(language)")
            }
        }
    }

    private func testLocalizedFormatPlaceholdersMatch() {
        guard let strings = localizationCatalogStrings() else {
            assertTrue(false, "Could not read Localizable.xcstrings")
            return
        }

        for (key, rawValue) in strings {
            guard let value = rawValue as? [String: Any],
                  let localizations = value["localizations"] as? [String: Any],
                  let english = localizedValue(in: localizations, language: "en"),
                  let turkish = localizedValue(in: localizations, language: "tr") else { continue }
            assertEqual(
                formatPlaceholders(in: english),
                formatPlaceholders(in: turkish),
                "Format placeholders differ for \(key)"
            )
        }
    }

    private func localizationCatalogStrings() -> [String: Any]? {
        let url = URL(fileURLWithPath: "Songleton/Localizable.xcstrings")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return root["strings"] as? [String: Any]
    }

    private func localizedValue(in localizations: [String: Any], language: String) -> String? {
        let localization = localizations[language] as? [String: Any]
        let stringUnit = localization?["stringUnit"] as? [String: Any]
        return stringUnit?["value"] as? String
    }

    private func formatPlaceholders(in value: String) -> [String] {
        let pattern = "%((?:[0-9]+\\$)?(?:[-+0 #']*)?(?:[0-9]+|\\*)?(?:\\.(?:[0-9]+|\\*))?(?:hh|h|ll|l|q|L|z|t|j)?[@a-zA-Z%])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: value) else { return nil }
            return String(value[swiftRange])
        }.filter { $0 != "%%" }.sorted()
    }
}
