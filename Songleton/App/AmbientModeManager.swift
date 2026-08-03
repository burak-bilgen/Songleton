import AppKit
import Combine
import SwiftUI

@MainActor
final class AmbientModeManager: ObservableObject {
    static let shared = AmbientModeManager()

    @Published private(set) var isPresented = false
    private var window: NSWindow?
    private var keyMonitor: Any?

    private init() {}

    func toggle() {
        if isPresented {
            dismiss()
        } else {
            show()
        }
    }

    private var activeObserver: NSObjectProtocol?

    func show() {
        guard !isPresented else { return }

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
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }

        setupKeyMonitor()
        setupFocusObserver()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false

        removeKeyMonitor()
        removeFocusObserver()

        if let win = window {
            win.orderOut(nil)
            win.contentView = nil
            win.close()
        }
        window = nil

        NSApp.setActivationPolicy(.accessory)
        MenuBarManager.shared.setStatusItemsVisible(true)
    }

    private func setupFocusObserver() {
        removeFocusObserver()
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let win = self.window else { return }
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(win.contentView)
        }
    }

    private func removeFocusObserver() {
        if let obs = activeObserver {
            NotificationCenter.default.removeObserver(obs)
            activeObserver = nil
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
