import AppKit
import SwiftUI

@MainActor
final class HUDToastManager: NSObject {
    static let shared = HUDToastManager()

    private var toastWindow: NonActivatingToastPanel?
    private var dismissTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func show(track: String, artist: String, artwork: NSImage?) {
        dismissTask?.cancel()

        // Close existing toast window immediately
        if let existing = toastWindow {
            existing.orderOut(nil)
            existing.close()
            toastWindow = nil
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let toastWidth: CGFloat = 270
        let toastHeight: CGFloat = 64
        let paddingRight: CGFloat = 20
        let paddingTop: CGFloat = 12

        // Top-Right Corner Position (Aligned right below menu bar)
        let toastX = visibleFrame.maxX - toastWidth - paddingRight
        let toastY = visibleFrame.maxY - toastHeight - paddingTop

        let panel = NonActivatingToastPanel(
            contentRect: NSRect(x: toastX, y: toastY, width: toastWidth, height: toastHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(
            rootView: HUDToastView(track: track, artist: artist, artwork: artwork)
        )

        self.toastWindow = panel

        // Display visually WITHOUT ever stealing keyboard focus from active application!
        panel.orderFrontRegardless()

        dismissTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled, let self, let panel else { return }
            if !Task.isCancelled {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.35
                    panel.animator().alphaValue = 0.0
                } completionHandler: { [weak self, weak panel] in
                    guard let panel else { return }
                    panel.orderOut(nil)
                    panel.close()
                    Task { @MainActor [weak self, weak panel] in
                        guard let self, self.toastWindow === panel else { return }
                        self.toastWindow = nil
                    }
                }
            }
        }
    }
}

// Custom NSPanel subclass that NEVER steals key focus or main window status
final class NonActivatingToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
