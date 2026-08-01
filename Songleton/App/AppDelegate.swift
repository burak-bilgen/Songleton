import AppKit
import CoreText
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerCustomFonts()
        MenuBarManager.shared.setup()

        // Silently check permission status
        NowPlayingModel.shared.checkAutomationPermission(askUser: false)

        // Show onboarding ONLY if never completed before
        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasOnboarded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showOnboarding()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // Called from SettingsView
    func reopenOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        showOnboarding()
    }

    // MARK: - Private

    private func registerCustomFonts() {
        guard let url = Bundle.main.url(forResource: "Audiowide-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private func showOnboarding() {
        let content = OnboardingView(model: .shared) { [weak self] in
            self?.finishOnboarding()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Songleton"
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        onboardingWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        if NowPlayingModel.shared.automationStatus == .granted {
            UserDefaults.standard.set(true, forKey: "hasGrantedAutomation")
        }

        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }

}
