import AppKit
import Combine
import SwiftUI

@MainActor
final class GestureTutorialManager: ObservableObject {
    static let shared = GestureTutorialManager()

    private static let completionKey = "hasCompletedGestureTutorial"

    @Published private(set) var isPresented = false
    private var window: NSWindow?
    private var keyMonitor: Any?

    private init() {}

    var hasCompletedTutorial: Bool {
        UserDefaults.standard.bool(forKey: Self.completionKey)
    }

    func show(askFirst: Bool = false) {
        guard !isPresented else { return }

        // Close any open popovers or panels before starting tutorial
        MenuBarManager.shared.closeVolumePopoverImmediately()

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let containerView = TutorialContainerView(askFirst: askFirst) { [weak self] in
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
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .transient]
        window.contentView = NSHostingView(rootView: containerView)
        window.setFrame(screen.frame, display: true)

        self.window = window
        self.isPresented = true
        MouseGestureManager.shared.updateMonitoring()

        NSApp.setActivationPolicy(.regular)
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)
        setupKeyMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
    }

    func dismiss() {
        guard isPresented else { return }
        UserDefaults.standard.set(true, forKey: Self.completionKey)
        isPresented = false

        if let win = window {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                win.animator().alphaValue = 0.0
            } completionHandler: {
                win.orderOut(nil)
                win.contentView = nil
                win.close()
            }
        }
        window = nil

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        TutorialAudioService.shared.stop()

        NSApp.setActivationPolicy(.accessory)
        MenuBarManager.shared.setStatusItemsVisible(true)
        MouseGestureManager.shared.updateMonitoring()
    }

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.isPresented == true else { return event }
            self?.dismiss()
            return nil
        }
    }
}

private struct TutorialContainerView: View {
    let askFirst: Bool
    let onClose: () -> Void
    @State private var showingPrompt: Bool

    init(askFirst: Bool, onClose: @escaping () -> Void) {
        self.askFirst = askFirst
        self.onClose = onClose
        self._showingPrompt = State(initialValue: askFirst)
    }

    var body: some View {
        ZStack {
            if showingPrompt {
                TutorialPromptView(
                    onStart: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            showingPrompt = false
                        }
                    },
                    onSkip: onClose
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                GestureTutorialView(onClose: onClose)
                    .transition(.opacity)
            }
        }
    }
}
