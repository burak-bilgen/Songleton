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

@MainActor
final class SettingsModel: ObservableObject {
    static var shared: SettingsModel { AppContainer.shared.settings }

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
        didSet {
            defaults.set(showTrackNotifications, forKey: "showTrackNotifications")
            if !showTrackNotifications {
                Task { @MainActor in
                    HUDToastManager.shared.dismiss()
                }
            }
        }
    }

    @Published var permanentHUDMode: Bool {
        didSet {
            defaults.set(permanentHUDMode, forKey: "permanentHUDMode")
            Task { @MainActor in
                HUDToastManager.shared.updatePermanentMode()
            }
        }
    }

    @Published var trackNotificationPosition: TrackNotificationPosition {
        didSet {
            defaults.set(trackNotificationPosition.rawValue, forKey: "trackNotificationPosition")
            Task { @MainActor in
                if self.permanentHUDMode {
                    HUDToastManager.shared.updatePermanentMode()
                }
            }
        }
    }

    @Published var horizontalGesturesEnabled: Bool {
        didSet {
            defaults.set(horizontalGesturesEnabled, forKey: "horizontalGesturesEnabled")
            Task { @MainActor in
                MouseGestureManager.shared.updateMonitoring()
                applyAutoNavButtonsVisibility()
            }
        }
    }

    @Published var verticalGesturesEnabled: Bool {
        didSet {
            defaults.set(verticalGesturesEnabled, forKey: "verticalGesturesEnabled")
            Task { @MainActor in
                MouseGestureManager.shared.updateMonitoring()
                applyAutoNavButtonsVisibility()
            }
        }
    }

    @Published var horizontalEdgeHoldDuration: Double {
        didSet { defaults.set(horizontalEdgeHoldDuration, forKey: "horizontalEdgeHoldDuration") }
    }

    @Published var topEdgeHoldDuration: Double {
        didSet { defaults.set(topEdgeHoldDuration, forKey: "topEdgeHoldDuration") }
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
    private var navButtonsUserOverride: Bool?
    private var gestureDependencyCancellable: AnyCancellable?

    init(
        userDefaults: UserDefaults = .standard,
        launchAtLoginApplier: ((Bool) throws -> Void)? = nil
    ) {
        self.defaults = userDefaults
        self.launchAtLoginApplier = launchAtLoginApplier
        userDefaults.register(defaults: [
            "showArtistInMenuBar": false,
            "menuBarWidth": 100.0,
            "menuBarFont": MenuBarFont.system.rawValue,
            "launchAtLogin": false,
            "showTrackNotifications": true,
            "permanentHUDMode": false,
            "trackNotificationPosition": TrackNotificationPosition.bottomTrailing.rawValue,
            "horizontalGesturesEnabled": true,
            "verticalGesturesEnabled": true,
            "lyricsOffset": 0.9
        ])
        showArtistInMenuBar = userDefaults.bool(forKey: "showArtistInMenuBar")
        let storedWidth = userDefaults.object(forKey: "menuBarWidth") != nil ? userDefaults.double(forKey: "menuBarWidth") : 100.0
        menuBarWidth = min(300, max(80, storedWidth))
        menuBarFont = MenuBarFont(rawValue: userDefaults.string(forKey: "menuBarFont") ?? "") ?? .system
        if launchAtLoginApplier != nil {
            launchAtLogin = userDefaults.bool(forKey: "launchAtLogin")
        } else {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        showTrackNotifications = userDefaults.bool(forKey: "showTrackNotifications")
        permanentHUDMode = userDefaults.bool(forKey: "permanentHUDMode")
        trackNotificationPosition = TrackNotificationPosition(
            rawValue: userDefaults.string(forKey: "trackNotificationPosition") ?? ""
        ) ?? .bottomTrailing
        horizontalGesturesEnabled = userDefaults.bool(forKey: "horizontalGesturesEnabled")
        verticalGesturesEnabled = userDefaults.bool(forKey: "verticalGesturesEnabled")
        // The single hold duration was split into per-zone settings. Migrate
        // any previously stored value so users keep their tuned timing.
        let legacyHoldDuration = userDefaults.double(forKey: "edgeGestureHoldDuration")
        let storedHorizontal = userDefaults.object(forKey: "horizontalEdgeHoldDuration") != nil
            ? userDefaults.double(forKey: "horizontalEdgeHoldDuration")
            : (userDefaults.object(forKey: "edgeGestureHoldDuration") != nil ? legacyHoldDuration : 0.65)
        let storedTop = userDefaults.object(forKey: "topEdgeHoldDuration") != nil
            ? userDefaults.double(forKey: "topEdgeHoldDuration")
            : (userDefaults.object(forKey: "edgeGestureHoldDuration") != nil ? legacyHoldDuration * 0.70 : 0.45)
        horizontalEdgeHoldDuration = min(2, max(0.2, storedHorizontal))
        topEdgeHoldDuration = min(2, max(0.2, storedTop))
        
        if let override = userDefaults.object(forKey: "menuBarNavButtonsUserOverride") as? Bool {
            navButtonsUserOverride = override
            showMenuBarNavButtons = override
        } else {
            navButtonsUserOverride = nil
            showMenuBarNavButtons = true
        }
        lyricsOffset = min(3, max(-3, userDefaults.double(forKey: "lyricsOffset")))
    }

    func wireGestureDependencies() {
        guard gestureDependencyCancellable == nil else { return }
        gestureDependencyCancellable = MouseGestureManager.shared.$isAccessibilityTrusted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyAutoNavButtonsVisibility()
            }
        applyAutoNavButtonsVisibility()
    }

    func setMenuBarNavButtonsUserChoice(_ value: Bool) {
        navButtonsUserOverride = value
        defaults.set(value, forKey: "menuBarNavButtonsUserOverride")
        if showMenuBarNavButtons != value {
            showMenuBarNavButtons = value
        }
    }

    func applyAutoNavButtonsVisibility() {
        guard navButtonsUserOverride == nil else { return }
        let gesturesActive = MouseGestureManager.shared.isAccessibilityTrusted
            && (horizontalGesturesEnabled || verticalGesturesEnabled)
        showMenuBarNavButtons = !gesturesActive
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
