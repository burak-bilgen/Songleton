import AppKit
import CoreText
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate?

    private var onboardingWindow: NSWindow?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerCustomFonts()
        MenuBarManager.shared.setup()
        NowPlayingModel.shared.checkAutomationPermission(askUser: false)

        NotificationCenter.default.addObserver(
            forName: Notification.Name("showOnboardingGuide"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOnboarding()
            }
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name("showGestureTutorial"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                GestureTutorialManager.shared.show()
            }
        }

        let forceReset = CommandLine.arguments.contains("--reset-onboarding")
            || ProcessInfo.processInfo.environment["RESET_ONBOARDING"] == "1"
        if forceReset {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        }

        let hasOnboarded = forceReset ? false : UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasOnboarded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showOnboarding()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func registerCustomFonts() {
        guard let url = Bundle.main.url(forResource: "Audiowide-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private func centerWindow(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let x = screenFrame.minX + (screenFrame.width - windowSize.width) / 2
        let y = screenFrame.minY + (screenFrame.height - windowSize.height) / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    var isOnboardingWindowOpen: Bool {
        onboardingWindow != nil
    }

    func showOnboarding() {
        if let window = onboardingWindow {
            NSApp.setActivationPolicy(.regular)
            centerWindow(window)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                self.centerWindow(window)
            }
            MouseGestureManager.shared.updateMonitoring()
            return
        }

        let content = OnboardingView(model: .shared) { [weak self] in
            self?.finishOnboarding()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 680),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("onboardingWindow")
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Songleton"
        window.contentView = NSHostingView(rootView: content)
        centerWindow(window)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.delegate = self
        onboardingWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            self.centerWindow(window)
        }
        MouseGestureManager.shared.updateMonitoring()
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        if NowPlayingModel.shared.automationStatus == .granted {
            UserDefaults.standard.set(true, forKey: "hasGrantedAutomation")
        }

        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
        MouseGestureManager.shared.updateMonitoring()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            GestureTutorialManager.shared.show(askFirst: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === onboardingWindow else { return }
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
        MouseGestureManager.shared.updateMonitoring()
    }
}
