import SwiftUI

@main
struct SongletonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsModel.shared
    @StateObject private var localization = LocalizationManager.shared

    var body: some Scene {
        Settings {
            SettingsView(settings: settings)
        }
        .environment(\.locale, localization.locale)
    }
}
