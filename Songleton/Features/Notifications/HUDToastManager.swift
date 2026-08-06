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

    static func make(
        track: String,
        artist: String,
        in visibleFrame: NSRect,
        isPermanent: Bool = false
    ) -> TrackNotificationLayout {
        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 10
        let artworkSize: CGFloat = 44
        let contentSpacing: CGFloat = 12
        let controlsSpacing: CGFloat = 10
        let controlsWidth: CGFloat = isPermanent ? 96 : 0
        let titleFont = NSFont.systemFont(ofSize: 13, weight: .bold)
        let artistFont = NSFont.systemFont(ofSize: 11, weight: .medium)

        if isPermanent {
            let permanentCardWidth: CGFloat = 350
            let textWidth = permanentCardWidth - horizontalPadding * 2 - artworkSize - contentSpacing - controlsSpacing - controlsWidth
            return TrackNotificationLayout(
                size: NSSize(width: permanentCardWidth, height: 64),
                textWidth: max(120, textWidth)
            )
        }

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
    static let shared = AppContainer.shared.hudToasts

    private var toastWindow: NonActivatingToastPanel?
    private var dismissTask: Task<Void, Never>?

    override init() {
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

        let isPermanent = SettingsModel.shared.permanentHUDMode && !isPreview

        let pointerLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let layout = TrackNotificationLayout.make(
            track: track,
            artist: artist,
            in: visibleFrame,
            isPermanent: isPermanent
        )
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

        // --- 1. PERMANENT HUD MODE (Stationary card, in-place cross-fade, zero offscreen motion) ---
        if isPermanent {
            if let existing = toastWindow {
                existing.ignoresMouseEvents = false
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.35
                    context.allowsImplicitAnimation = true
                    existing.animator().setFrame(finalPanelFrame, display: true)
                    existing.animator().alphaValue = 1.0
                }
                return
            }

            // Initial appearance when permanent mode is enabled: create window directly at final position!
            let panel = NonActivatingToastPanel(
                contentRect: finalPanelFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
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
            panel.alphaValue = 0.0
            self.toastWindow = panel

            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.40
                context.allowsImplicitAnimation = true
                panel.animator().alphaValue = 1.0
            }
            return
        }

        // --- 2. TRANSIENT MODE (Permanent Mode disabled: entry/exit motion animations work as before) ---
        if let existing = toastWindow {
            existing.orderOut(nil)
            existing.close()
            toastWindow = nil
        }

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
        panel.alphaValue = 0.0

        self.toastWindow = panel

        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.46
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(finalPanelFrame, display: true)
            panel.animator().alphaValue = 1.0
        }

        if !isPreview {
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
                        Task { @MainActor [weak self, weak panel] in
                            guard let panel else { return }
                            panel.orderOut(nil)
                            panel.close()
                            guard let self, self.toastWindow === panel else { return }
                            self.toastWindow = nil
                        }
                    }
                }
            }
        }
    }

    func updatePermanentMode() {
        if SettingsModel.shared.permanentHUDMode && SettingsModel.shared.showTrackNotifications {
            if case .loaded(let info, _) = NowPlayingModel.shared.state {
                show(
                    track: info.track,
                    artist: info.artist,
                    artwork: NowPlayingModel.shared.artwork
                )
            } else {
                show(
                    track: "Songleton",
                    artist: LocalizationManager.shared.string("notification.preview_artist"),
                    artwork: nil,
                    accentColor: SongletonTheme.cyan
                )
            }
        } else {
            dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        guard let panel = toastWindow else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.34
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0.0
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor [weak self, weak panel] in
                guard let panel else { return }
                panel.orderOut(nil)
                panel.close()
                guard let self, self.toastWindow === panel else { return }
                self.toastWindow = nil
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
