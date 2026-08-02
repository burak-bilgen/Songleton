import Combine
import ServiceManagement
import SwiftUI

final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()

    enum MenuBarFont: String, CaseIterable {
        case system
        case audiowide

        func font(size: CGFloat) -> Font {
            switch self {
            case .system: .system(size: size, weight: .medium, design: .rounded)
            case .audiowide: .custom("Audiowide", size: size - 1)
            }
        }
    }

    @Published var showArtistInMenuBar: Bool {
        didSet { defaults.set(showArtistInMenuBar, forKey: "showArtistInMenuBar") }
    }

    @Published var menuBarWidth: Double {
        didSet {
            defaults.set(menuBarWidth, forKey: "menuBarWidth")
            Task { @MainActor in
                MenuBarManager.shared.updateWidth()
            }
        }
    }

    @Published var menuBarFont: MenuBarFont {
        didSet { defaults.set(menuBarFont.rawValue, forKey: "menuBarFont") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    @Published var showProgressBar: Bool {
        didSet { defaults.set(showProgressBar, forKey: "showProgressBar") }
    }

    @Published var useDynamicColor: Bool {
        didSet { defaults.set(useDynamicColor, forKey: "useDynamicColor") }
    }

    @Published var lyricsOffset: Double {
        didSet { defaults.set(lyricsOffset, forKey: "lyricsOffset") }
    }

    let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        userDefaults.register(defaults: [
            "showArtistInMenuBar": true,
            "menuBarWidth": 80.0,
            "menuBarFont": MenuBarFont.system.rawValue,
            "launchAtLogin": false,
            "showProgressBar": true,
            "useDynamicColor": true,
            "lyricsOffset": 0.9
        ])
        showArtistInMenuBar = userDefaults.bool(forKey: "showArtistInMenuBar")
        menuBarWidth = userDefaults.double(forKey: "menuBarWidth")
        menuBarFont = MenuBarFont(rawValue: userDefaults.string(forKey: "menuBarFont") ?? "") ?? .system
        launchAtLogin = SMAppService.mainApp.status == .enabled
        showProgressBar = userDefaults.bool(forKey: "showProgressBar")
        useDynamicColor = userDefaults.bool(forKey: "useDynamicColor")
        lyricsOffset = userDefaults.double(forKey: "lyricsOffset")
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
