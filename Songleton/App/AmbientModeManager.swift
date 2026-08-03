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
        window.level = .screenSaver
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = NSHostingView(rootView: ambientView)
        window.setFrame(screen.frame, display: true)

        self.window = window
        self.isPresented = true

        // Smooth window alpha fade-in entrance
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
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false

        removeKeyMonitor()

        if let win = window {
            win.orderOut(nil)
            win.contentView = nil
            win.close()
        }
        window = nil

        MenuBarManager.shared.setStatusItemsVisible(true)
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
