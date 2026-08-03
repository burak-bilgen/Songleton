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

    @Published var showTrackNotifications: Bool {
        didSet { defaults.set(showTrackNotifications, forKey: "showTrackNotifications") }
    }

    @Published var horizontalGesturesEnabled: Bool {
        didSet {
            defaults.set(horizontalGesturesEnabled, forKey: "horizontalGesturesEnabled")
            Task { @MainActor in
                MouseGestureManager.shared.updateMonitoring()
            }
        }
    }

    @Published var verticalGesturesEnabled: Bool {
        didSet {
            defaults.set(verticalGesturesEnabled, forKey: "verticalGesturesEnabled")
            Task { @MainActor in
                MouseGestureManager.shared.updateMonitoring()
            }
        }
    }

    @Published var showMenuBarNavButtons: Bool {
        didSet {
            defaults.set(showMenuBarNavButtons, forKey: "showMenuBarNavButtons")
            Task { @MainActor in
                MenuBarManager.shared.refreshNavButtonVisibility()
            }
        }
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
            "showTrackNotifications": true,
            "horizontalGesturesEnabled": true,
            "verticalGesturesEnabled": true,
            "showMenuBarNavButtons": true,
            "lyricsOffset": 0.9
        ])
        showArtistInMenuBar = userDefaults.bool(forKey: "showArtistInMenuBar")
        menuBarWidth = min(300, max(80, userDefaults.double(forKey: "menuBarWidth")))
        menuBarFont = MenuBarFont(rawValue: userDefaults.string(forKey: "menuBarFont") ?? "") ?? .system
        launchAtLogin = SMAppService.mainApp.status == .enabled
        showTrackNotifications = userDefaults.bool(forKey: "showTrackNotifications")
        horizontalGesturesEnabled = userDefaults.bool(forKey: "horizontalGesturesEnabled")
        verticalGesturesEnabled = userDefaults.bool(forKey: "verticalGesturesEnabled")
        showMenuBarNavButtons = userDefaults.bool(forKey: "showMenuBarNavButtons")
        lyricsOffset = min(3, max(-3, userDefaults.double(forKey: "lyricsOffset")))
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let actualValue = SMAppService.mainApp.status == .enabled
            defaults.set(actualValue, forKey: "launchAtLogin")
            if launchAtLogin != actualValue {
                launchAtLogin = actualValue
            }
        }
    }
}
