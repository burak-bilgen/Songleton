import AppKit
import CoreText
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerCustomFonts()
        MenuBarManager.shared.setup()
        NowPlayingModel.shared.checkAutomationPermission(askUser: false)

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

    func applicationDidBecomeActive(_ notification: Notification) {
        MouseGestureManager.shared.start()
    }

    func reopenOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        NSApp.setActivationPolicy(.regular)
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        showOnboarding()
    }

    private func registerCustomFonts() {
        guard let url = Bundle.main.url(forResource: "Audiowide-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private func showOnboarding() {
        let content = OnboardingView(model: .shared) { [weak self] in
            self?.finishOnboarding()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 660),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Songleton"
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.delegate = self
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

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === onboardingWindow else { return }
        guard !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
