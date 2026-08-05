import AppKit
import Combine
import SwiftUI

@MainActor
final class GestureTutorialManager: ObservableObject {
    static let shared = GestureTutorialManager()

    private static let completionKey = "hasCompletedGestureTutorial"
    private static let resolutionKey = "gestureTutorialResolution"

    enum Resolution: String {
        case notStarted
        case completed
        case skipped
        case dismissed

        var unlocksControls: Bool {
            self == .completed || self == .skipped
        }
    }

    @Published private(set) var isPresented = false
    private var window: NSWindow?
    private var keyMonitor: Any?

    private init() {}

    var resolution: Resolution {
        if let rawValue = UserDefaults.standard.string(forKey: Self.resolutionKey),
           let resolution = Resolution(rawValue: rawValue) {
            return resolution
        }
        // Keep existing installations working after the state migration.
        return UserDefaults.standard.bool(forKey: Self.completionKey) ? .completed : .notStarted
    }

    var hasResolvedTutorial: Bool {
        resolution.unlocksControls
    }

    var hasCompletedTutorial: Bool {
        hasResolvedTutorial
    }

    func show(askFirst: Bool = false) {
        guard !isPresented else { return }

        // Close any open popovers or panels before starting tutorial
        MenuBarManager.shared.closeVolumePopoverImmediately()

        // The guide demonstrates screen edges. It must open on the screen the
        // person is actively using, not whichever display macOS calls main.
        let pointerLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let containerView = TutorialContainerView(
            askFirst: askFirst,
            onComplete: { [weak self] in self?.dismiss(outcome: .completed) },
            onSkip: { [weak self] in self?.dismiss(outcome: .skipped) },
            onDismiss: { [weak self] in self?.dismiss(outcome: .dismissed) }
        )

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

    func dismiss(outcome: Resolution = .dismissed) {
        guard isPresented else { return }
        UserDefaults.standard.set(true, forKey: Self.completionKey)
        UserDefaults.standard.set(outcome.rawValue, forKey: Self.resolutionKey)
        isPresented = false

        if let win = window {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                win.animator().alphaValue = 0.0
            } completionHandler: {
                Task { @MainActor in
                    win.orderOut(nil)
                    win.contentView = nil
                    win.close()
                }
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
            self?.dismiss(outcome: .dismissed)
            return nil
        }
    }
}

private struct TutorialContainerView: View {
    let askFirst: Bool
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void
    @State private var showingPrompt: Bool

    init(
        askFirst: Bool,
        onComplete: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.askFirst = askFirst
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onDismiss = onDismiss
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
                    onSkip: onSkip
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                GestureTutorialView(onComplete: onComplete, onDismiss: onDismiss)
                    .transition(.opacity)
            }
        }
    }
}
