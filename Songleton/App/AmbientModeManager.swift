import AppKit
import Combine
import SwiftUI

@MainActor
final class AmbientModeManager: ObservableObject {
    static let shared = AmbientModeManager()

    @Published private(set) var isPresented = false
    private var window: NSWindow?
    private var keyMonitor: Any?
    private var activeObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?

    private init() {}

    func toggle() {
        if isPresented {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        guard !isPresented else { return }

        // Close the hover popover so it doesn't linger behind the ambient screen.
        MenuBarManager.shared.closeVolumePopoverImmediately()

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let ambientView = AmbientView { [weak self] in
            self?.dismiss()
        }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .participatesInCycle]
        window.contentView = NSHostingView(rootView: ambientView)
        window.setFrame(screen.frame, display: true)

        self.window = window
        self.isPresented = true

        NSApp.setActivationPolicy(.regular)
        hideSystemChrome()
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }

        setupKeyMonitor()
        setupFocusObservers()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false

        removeKeyMonitor()
        removeFocusObservers()

        if let win = window {
            win.orderOut(nil)
            win.contentView = nil
            win.close()
        }
        window = nil

        NSApp.setActivationPolicy(.accessory)
        showSystemChrome()
        MenuBarManager.shared.setStatusItemsVisible(true)
    }

    // While ambient is frontmost, hide the system menu bar and Dock (like fullscreen).
    private func hideSystemChrome() {
        NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
    }

    private func showSystemChrome() {
        NSApp.presentationOptions = []
    }

    // When we lose active status (e.g. Cmd+Tab to another app), immediately demote
    // the ambient window below every other app's windows so the screen is never
    // blocked while the user works elsewhere. Ambient state itself is preserved.
    private func demoteForInactiveApp() {
        guard isPresented, let win = window else { return }
        showSystemChrome()
        win.level = .normal
        win.orderBack(nil)
    }

    // When the user comes back via Cmd+Tab / Dock, restore full immersion and
    // reclaim key focus so keyboard shortcuts work immediately, no clicks needed.
    private func restoreActiveWindow() {
        guard isPresented, let win = window else { return }
        hideSystemChrome()
        win.level = .floating
        if !win.isVisible { win.orderFront(nil) }
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(win.contentView)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            win.animator().alphaValue = 1.0
        }
    }

    private func setupFocusObservers() {
        removeFocusObservers()
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restoreActiveWindow()
            }
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.demoteForInactiveApp()
            }
        }
    }

    private func removeFocusObservers() {
        if let obs = activeObserver {
            NotificationCenter.default.removeObserver(obs)
            activeObserver = nil
        }
        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
    }

    private func setupKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = event.keyCode
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("ambientKeyDown"),
                    object: nil,
                    userInfo: ["keyCode": code, "chars": chars]
                )
            }
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            keyMonitor = nil
            DispatchQueue.main.async {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
