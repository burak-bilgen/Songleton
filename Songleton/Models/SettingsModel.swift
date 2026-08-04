import Combine
import ServiceManagement
import SwiftUI

enum TrackNotificationPosition: String, CaseIterable, Identifiable {
    case topLeading
    case top
    case topTrailing
    case leading
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .topLeading: "arrow.up.left"
        case .top: "arrow.up"
        case .topTrailing: "arrow.up.right"
        case .leading: "arrow.left"
        case .trailing: "arrow.right"
        case .bottomLeading: "arrow.down.left"
        case .bottom: "arrow.down"
        case .bottomTrailing: "arrow.down.right"
        }
    }

    var localizationKey: String { "settings.notification_position.\(rawValue)" }

}

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

    @Published var trackNotificationPosition: TrackNotificationPosition {
        didSet { defaults.set(trackNotificationPosition.rawValue, forKey: "trackNotificationPosition") }
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

    @Published var edgeGestureHoldDuration: Double {
        didSet { defaults.set(edgeGestureHoldDuration, forKey: "edgeGestureHoldDuration") }
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
    private let launchAtLoginApplier: ((Bool) throws -> Void)?

    init(
        userDefaults: UserDefaults = .standard,
        launchAtLoginApplier: ((Bool) throws -> Void)? = nil
    ) {
        self.defaults = userDefaults
        self.launchAtLoginApplier = launchAtLoginApplier
        userDefaults.register(defaults: [
            "showArtistInMenuBar": false,
            "menuBarWidth": 80.0,
            "menuBarFont": MenuBarFont.system.rawValue,
            "launchAtLogin": false,
            "showTrackNotifications": true,
            "trackNotificationPosition": TrackNotificationPosition.bottomTrailing.rawValue,
            "horizontalGesturesEnabled": true,
            "verticalGesturesEnabled": true,
            "edgeGestureHoldDuration": 0.65,
            "showMenuBarNavButtons": true,
            "lyricsOffset": 0.9
        ])
        showArtistInMenuBar = userDefaults.bool(forKey: "showArtistInMenuBar")
        menuBarWidth = min(300, max(80, userDefaults.double(forKey: "menuBarWidth")))
        menuBarFont = MenuBarFont(rawValue: userDefaults.string(forKey: "menuBarFont") ?? "") ?? .system
        if launchAtLoginApplier != nil {
            launchAtLogin = userDefaults.bool(forKey: "launchAtLogin")
        } else {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        showTrackNotifications = userDefaults.bool(forKey: "showTrackNotifications")
        trackNotificationPosition = TrackNotificationPosition(
            rawValue: userDefaults.string(forKey: "trackNotificationPosition") ?? ""
        ) ?? .bottomTrailing
        horizontalGesturesEnabled = userDefaults.bool(forKey: "horizontalGesturesEnabled")
        verticalGesturesEnabled = userDefaults.bool(forKey: "verticalGesturesEnabled")
        edgeGestureHoldDuration = min(2, max(0.2, userDefaults.double(forKey: "edgeGestureHoldDuration")))
        showMenuBarNavButtons = userDefaults.bool(forKey: "showMenuBarNavButtons")
        lyricsOffset = min(3, max(-3, userDefaults.double(forKey: "lyricsOffset")))
    }

    func applyLaunchAtLogin() {
        do {
            if let launchAtLoginApplier {
                try launchAtLoginApplier(launchAtLogin)
            } else if launchAtLogin {
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
