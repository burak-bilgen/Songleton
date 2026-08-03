import AppKit
import Combine
import SwiftUI

@MainActor
final class AmbientModeManager: ObservableObject {
    static let shared = AmbientModeManager()

    @Published private(set) var isPresented = false
    private var window: NSWindow?
    private var localEventMonitor: Any?

    private init() {
        setupGlobalShortcutMonitor()
    }

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

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)

        // Local monitor for ESC key to exit via smooth CRT closing animation
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC
                NotificationCenter.default.post(name: Notification.Name("triggerAmbientCloseAnimation"), object: nil)
                return nil
            }
            return event
        }
    }

    func dismiss() {
        guard isPresented else { return }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        window?.close()
        window = nil
        isPresented = false
        NSApp.setActivationPolicy(.accessory)
        MenuBarManager.shared.setStatusItemsVisible(true)
    }

    private func setupGlobalShortcutMonitor() {
        // Shortcut monitor removed per user preference. Ambient Mode is accessed via Menu Bar and Hover Panel.
    }
}
