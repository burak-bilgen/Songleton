import AppKit
import SwiftUI

struct TrackNotificationLayout {
    static let minimumWidth: CGFloat = 270
    static let maximumPreferredWidth: CGFloat = 560
    static let minimumHeight: CGFloat = 64
    // The widest glow has a 46pt radius. Give it a generous transparent
    // runway instead of letting the hosting panel crop its soft falloff.
    static let shadowInset: CGFloat = 76

    let size: NSSize
    let textWidth: CGFloat

    var panelSize: NSSize {
        NSSize(
            width: size.width + Self.shadowInset * 2,
            height: size.height + Self.shadowInset * 2
        )
    }

    static func make(track: String, artist: String, in visibleFrame: NSRect) -> TrackNotificationLayout {
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 10
        let artworkSize: CGFloat = 44
        let contentSpacing: CGFloat = 12
        let titleFont = NSFont.systemFont(ofSize: 13, weight: .bold)
        let artistFont = NSFont.systemFont(ofSize: 11, weight: .medium)

        // Keep a usable margin even when the notification is centered on a
        // narrow display, but never force a fixed narrow card on normal ones.
        let maximumWidth = max(
            Self.minimumWidth,
            min(Self.maximumPreferredWidth, visibleFrame.width - 40)
        )
        let titleSingleLineWidth = measuredSize(track, font: titleFont).width
        let artistSingleLineWidth = artist.isEmpty ? 0 : measuredSize(artist, font: artistFont).width
        let naturalWidth = horizontalPadding * 2 + artworkSize + contentSpacing
            + max(titleSingleLineWidth, artistSingleLineWidth)
        let cardWidth = min(maximumWidth, max(Self.minimumWidth, ceil(naturalWidth)))
        let textWidth = max(80, cardWidth - horizontalPadding * 2 - artworkSize - contentSpacing)

        // A long title uses all available width, then wraps rather than ending
        // in an ellipsis. The panel grows vertically only when it needs to.
        let titleHeight = measuredSize(track, font: titleFont, constrainedTo: textWidth).height
        let artistHeight = artist.isEmpty ? 0 : measuredSize(artist, font: artistFont, constrainedTo: textWidth).height
        let textHeight = titleHeight + (artist.isEmpty ? 0 : 2 + artistHeight)
        let cardHeight = max(Self.minimumHeight, ceil(textHeight + verticalPadding * 2))

        return TrackNotificationLayout(
            size: NSSize(width: cardWidth, height: cardHeight),
            textWidth: textWidth
        )
    }

    private static func measuredSize(_ text: String, font: NSFont, constrainedTo width: CGFloat? = nil) -> NSSize {
        let constraint = NSSize(width: width ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        return (text as NSString).boundingRect(
            with: constraint,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        ).integral.size
    }
}

struct TrackNotificationMotion {
    static let offscreenGap: CGFloat = 18

    static func offscreenOrigin(
        finalOrigin: NSPoint,
        panelSize: NSSize,
        in visibleFrame: NSRect,
        position: TrackNotificationPosition
    ) -> NSPoint {
        var origin = finalOrigin

        switch position {
        case .topLeading, .top, .topTrailing:
            origin.y = visibleFrame.maxY + offscreenGap
        case .leading:
            origin.x = visibleFrame.minX - panelSize.width - offscreenGap
        case .trailing:
            origin.x = visibleFrame.maxX + offscreenGap
        case .bottomLeading, .bottom, .bottomTrailing:
            origin.y = visibleFrame.minY - panelSize.height - offscreenGap
        }

        return origin
    }
}

@MainActor
final class HUDToastManager: NSObject {
    static let shared = HUDToastManager()

    private var toastWindow: NonActivatingToastPanel?
    private var dismissTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func show(
        track: String,
        artist: String,
        artwork: NSImage?,
        accentColor: Color? = nil,
        isPreview: Bool = false
    ) {
        dismissTask?.cancel()

        // Close existing toast window immediately
        if let existing = toastWindow {
            existing.orderOut(nil)
            existing.close()
            toastWindow = nil
        }

        let pointerLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let layout = TrackNotificationLayout.make(track: track, artist: artist, in: visibleFrame)
        let position = SettingsModel.shared.trackNotificationPosition
        let cardOrigin = toastOrigin(
            in: visibleFrame,
            toastSize: layout.size,
            position: position
        )
        let panelOrigin = NSPoint(
            x: cardOrigin.x - TrackNotificationLayout.shadowInset,
            y: cardOrigin.y - TrackNotificationLayout.shadowInset
        )

        let finalPanelFrame = NSRect(origin: panelOrigin, size: layout.panelSize)
        let entryPanelFrame = NSRect(
            origin: TrackNotificationMotion.offscreenOrigin(
                finalOrigin: panelOrigin,
                panelSize: layout.panelSize,
                in: visibleFrame,
                position: position
            ),
            size: layout.panelSize
        )
        let panel = NonActivatingToastPanel(
            contentRect: entryPanelFrame,
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
            rootView: HUDToastView(
                track: track,
                artist: artist,
                artwork: artwork,
                layout: layout,
                accentColor: accentColor,
                isPreview: isPreview
            )
        )
        panel.alphaValue = 0

        self.toastWindow = panel

        // Display visually WITHOUT ever stealing keyboard focus from active application!
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.46
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(finalPanelFrame, display: true)
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled, let self, let panel else { return }
            if !Task.isCancelled {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.34
                    context.allowsImplicitAnimation = true
                    panel.animator().setFrame(entryPanelFrame, display: true)
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

    func showPreview() {
        show(
            track: LocalizationManager.shared.string("notification.preview_track"),
            artist: LocalizationManager.shared.string("notification.preview_artist"),
            artwork: nil,
            accentColor: SongletonTheme.cyan,
            isPreview: true
        )
    }

    private func toastOrigin(
        in frame: NSRect,
        toastSize: NSSize,
        position: TrackNotificationPosition
    ) -> NSPoint {
        // The panel still owns a large transparent runway for the glow, while
        // the visible card itself stays close enough to the display edge to
        // feel anchored to the selected placement.
        let horizontalPadding = min(22, max(12, (frame.width - toastSize.width) / 2))
        let verticalPadding = min(22, max(12, (frame.height - toastSize.height) / 2))

        let x: CGFloat
        switch position {
        case .topLeading, .leading, .bottomLeading:
            x = frame.minX + horizontalPadding
        case .top, .bottom:
            x = frame.midX - toastSize.width / 2
        case .topTrailing, .trailing, .bottomTrailing:
            x = frame.maxX - toastSize.width - horizontalPadding
        }

        let y: CGFloat
        switch position {
        case .topLeading, .top, .topTrailing:
            y = frame.maxY - toastSize.height - verticalPadding
        case .leading, .trailing:
            y = frame.midY - toastSize.height / 2
        case .bottomLeading, .bottom, .bottomTrailing:
            y = frame.minY + verticalPadding
        }

        return NSPoint(x: x, y: y)
    }
}

// Custom NSPanel subclass that NEVER steals key focus or main window status
final class NonActivatingToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
