import SwiftUI

@main
struct SongletonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsModel.shared

    var body: some Scene {
        Settings {
            SettingsView(settings: settings)
        }
    }
}
