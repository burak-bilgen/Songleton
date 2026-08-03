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
        window.level = .normal
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: ambientView)

        self.window = window
        self.isPresented = true

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)

        // Local monitor for ESC key to exit
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.dismiss()
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
    }

    private func setupGlobalShortcutMonitor() {
        // Global monitor for Cmd + Option + F to toggle Ambient Mode anywhere
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains([.command, .option]) && event.keyCode == 3 { // 'f' key is keyCode 3
                Task { @MainActor in
                    self?.toggle()
                }
            }
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains([.command, .option]) && event.keyCode == 3 {
                Task { @MainActor in
                    self?.toggle()
                }
                return nil
            }
            return event
        }
    }
}
