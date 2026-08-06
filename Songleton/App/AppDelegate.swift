import AppKit
import CoreText
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate?

    private var onboardingWindow: NSWindow?
    private var setupRecoveryWindow: NSWindow?
    private var isFinishingOnboarding = false
    private var isClosingSetupRecovery = false

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerCustomFonts()
        AppContainer.shared.bootstrap()

        NotificationCenter.default.addObserver(
            forName: .songletonShowOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showOnboarding()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .songletonShowGestureTutorial,
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
            UserDefaults.standard.removeObject(forKey: "hasCompletedGestureTutorial")
            UserDefaults.standard.removeObject(forKey: "gestureTutorialResolution")
        }

        let hasOnboarded = forceReset ? false : UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasOnboarded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showOnboarding()
            }
        } else if !GestureTutorialManager.shared.hasCompletedTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                GestureTutorialManager.shared.show(askFirst: true)
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NowPlayingModel.shared.checkAutomationPermission()
        MouseGestureManager.shared.refreshAccessibilityStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppContainer.shared.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func registerCustomFonts() {
        guard let url = Bundle.main.url(forResource: "Audiowide-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private func centerWindow(_ window: NSWindow) {
        let pointerLocation = NSEvent.mouseLocation
        let pointerScreen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
        guard let screen = window.screen ?? pointerScreen ?? NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let x = screenFrame.minX + (screenFrame.width - windowSize.width) / 2
        let y = screenFrame.minY + (screenFrame.height - windowSize.height) / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showOnboarding() {
        closeSetupRecoveryWindow()
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

        let content = OnboardingView(
            model: .shared,
            onFinish: { [weak self] in self?.finishOnboarding() },
            onAbort: { [weak self] in self?.abortOnboarding() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 590, height: 740),
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
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            self.centerWindow(window)
        }
        MouseGestureManager.shared.updateMonitoring()
    }

    private func finishOnboarding() {
        isFinishingOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        closeSetupRecoveryWindow()

        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
        MouseGestureManager.shared.updateMonitoring()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            GestureTutorialManager.shared.show(askFirst: true)
        }
    }

    private func abortOnboarding() {
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            onboardingWindow?.close()
            onboardingWindow = nil
            return
        }

        onboardingWindow?.close()
    }

    private func showSetupRecovery() {
        if let window = setupRecoveryWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = SetupRecoveryView(
            onContinue: { [weak self] in self?.showOnboarding() },
            onQuit: { NSApp.terminate(nil) }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("setupRecoveryWindow")
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Songleton"
        window.contentView = NSHostingView(rootView: content)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        setupRecoveryWindow = window

        NSApp.setActivationPolicy(.regular)
        centerWindow(window)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        MouseGestureManager.shared.updateMonitoring()
    }

    private func closeSetupRecoveryWindow() {
        guard let window = setupRecoveryWindow else { return }
        isClosingSetupRecovery = true
        window.close()
        setupRecoveryWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window === setupRecoveryWindow {
            setupRecoveryWindow = nil
            if isClosingSetupRecovery {
                isClosingSetupRecovery = false
            } else {
                NSApp.terminate(nil)
            }
            return
        }

        guard window === onboardingWindow else { return }
        onboardingWindow = nil

        if !isFinishingOnboarding && !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showSetupRecovery()
            return
        }

        isFinishingOnboarding = false
        NSApp.setActivationPolicy(.accessory)
        MouseGestureManager.shared.updateMonitoring()
    }
}
