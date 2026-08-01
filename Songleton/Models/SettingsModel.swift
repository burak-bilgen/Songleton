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

    enum PanelStyle: String, CaseIterable {
        case full
        case compact

        var displayName: String {
            switch self {
            case .full: "Tam"
            case .compact: "Kompakt"
            }
        }
    }

    @Published var showArtistInMenuBar: Bool {
        didSet { defaults.set(showArtistInMenuBar, forKey: "showArtistInMenuBar") }
    }

    @Published var menuBarWidth: Double {
        didSet { defaults.set(menuBarWidth, forKey: "menuBarWidth") }
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

    @Published var panelStyle: PanelStyle {
        didSet { defaults.set(panelStyle.rawValue, forKey: "panelStyle") }
    }

    @Published var showProgressBar: Bool {
        didSet { defaults.set(showProgressBar, forKey: "showProgressBar") }
    }

    @Published var useDynamicColor: Bool {
        didSet { defaults.set(useDynamicColor, forKey: "useDynamicColor") }
    }

    @Published var showMenuBarControls: Bool {
        didSet { defaults.set(showMenuBarControls, forKey: "showMenuBarControls") }
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            "showArtistInMenuBar": true,
            "menuBarWidth": 200.0,
            "menuBarFont": MenuBarFont.system.rawValue,
            "launchAtLogin": false,
            "panelStyle": PanelStyle.full.rawValue,
            "showProgressBar": true,
            "useDynamicColor": true,
            "showMenuBarControls": true
        ])
        showArtistInMenuBar = defaults.bool(forKey: "showArtistInMenuBar")
        menuBarWidth = defaults.double(forKey: "menuBarWidth")
        menuBarFont = MenuBarFont(rawValue: defaults.string(forKey: "menuBarFont") ?? "") ?? .system
        launchAtLogin = SMAppService.mainApp.status == .enabled
        panelStyle = PanelStyle(rawValue: defaults.string(forKey: "panelStyle") ?? "") ?? .full
        showProgressBar = defaults.bool(forKey: "showProgressBar")
        useDynamicColor = defaults.bool(forKey: "useDynamicColor")
        showMenuBarControls = defaults.bool(forKey: "showMenuBarControls")
    }

    private func applyLaunchAtLogin() {
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
