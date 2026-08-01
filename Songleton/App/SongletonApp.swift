import SwiftUI

@main
struct SongletonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = NowPlayingModel.shared
    @StateObject private var settings = SettingsModel.shared

    var body: some Scene {
        MenuBarExtra {
            PlayerPanelView(model: model)
        } label: {
            MenuBarLabelView(model: model, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}
