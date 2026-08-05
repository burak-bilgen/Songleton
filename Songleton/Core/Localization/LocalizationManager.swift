import Combine
import Foundation

@MainActor
final class LocalizationManager: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case system
        case english = "en"
        case turkish = "tr"

        var id: String { rawValue }
    }

    static let shared = AppContainer.shared.localization

    @Published var language: Language {
        didSet {
            defaults.set(language.rawValue, forKey: "language")
        }
    }

    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        language = Language(rawValue: userDefaults.string(forKey: "language") ?? Language.system.rawValue) ?? .system
    }

    var locale: Locale {
        Locale(identifier: resolvedLanguageCode)
    }

    var resolvedLanguageCode: String {
        switch language {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("tr") ? "tr" : "en"
        case .english:
            return "en"
        case .turkish:
            return "tr"
        }
    }

    func string(_ key: String) -> String {
        L10n.string(key, locale: locale)
    }
}

enum L10n {
    static func string(_ key: String, locale: Locale) -> String {
        let languageCode = locale.identifier.split(separator: "_").first.map(String.init) ?? "en"
        let bundle = Bundle.main.path(forResource: languageCode, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
