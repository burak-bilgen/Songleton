import AppKit
import CoreText
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var menuBarControls: MenuBarControls?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerCustomFonts()
        menuBarControls = MenuBarControls(model: .shared)

        // Silently check permission status (no dialog yet)
        NowPlayingModel.shared.checkAutomationPermission(askUser: false)

        // Show onboarding if:
        // 1. Never completed before, OR
        // 2. Completed before but permission was never granted (reset so user can grant)
        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasGranted   = UserDefaults.standard.bool(forKey: "hasGrantedAutomation")

        if !hasOnboarded || !hasGranted {
            // Small delay so MenuBarExtra is set up first and doesn't compete
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Songleton"
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        onboardingWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Mark as granted if automation is granted at this point
        if NowPlayingModel.shared.automationStatus == .granted {
            UserDefaults.standard.set(true, forKey: "hasGrantedAutomation")
        }

        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
