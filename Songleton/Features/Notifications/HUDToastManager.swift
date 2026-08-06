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
            panel.isMovableByWindowBackground = true
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
        panel.ignoresMouseEvents = !isPermanent && !isPreview
        panel.isMovableByWindowBackground = isPermanent || isPreview
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

    // MARK: - Native Drag & Translucent Snap Overlay

    private var overlayWindow: SnapGuideOverlayWindow?
    private var currentNearestSnapPosition: TrackNotificationPosition?

    func handleNativeDragStart(window: NSWindow) {
        let pointerLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? window.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let isPermanent = SettingsModel.shared.permanentHUDMode
        let layout = TrackNotificationLayout.make(
            track: "Songleton",
            artist: "",
            in: screen.visibleFrame,
            isPermanent: isPermanent
        )

        let initialNearest = findNearestPosition(forWindowOrigin: window.frame.origin, windowSize: window.frame.size, on: screen)
        currentNearestSnapPosition = initialNearest

        let overlay = SnapGuideOverlayWindow(
            screen: screen,
            cardSize: layout.size,
            activePosition: initialNearest
        )
        overlay.orderFrontRegardless()
        self.overlayWindow = overlay
    }

    func handleNativeDragMoved(window: NSWindow) {
        let pointerLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? window.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let isPermanent = SettingsModel.shared.permanentHUDMode
        let layout = TrackNotificationLayout.make(
            track: "Songleton",
            artist: "",
            in: screen.visibleFrame,
            isPermanent: isPermanent
        )

        let nearest = findNearestPosition(forWindowOrigin: window.frame.origin, windowSize: window.frame.size, on: screen)

        if nearest != currentNearestSnapPosition {
            currentNearestSnapPosition = nearest
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            overlayWindow?.updateActivePosition(nearest, cardSize: layout.size)
        }
    }

    func handleNativeDragEnded(window: NSWindow) {
        defer {
            overlayWindow?.orderOut(nil)
            overlayWindow = nil
            currentNearestSnapPosition = nil
        }

        let pointerLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? window.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let isPermanent = SettingsModel.shared.permanentHUDMode
        let layout = TrackNotificationLayout.make(
            track: "Songleton",
            artist: "",
            in: screen.visibleFrame,
            isPermanent: isPermanent
        )

        let nearestPosition = findNearestPosition(forWindowOrigin: window.frame.origin, windowSize: window.frame.size, on: screen)

        let visibleFrame = screen.visibleFrame
        let cardOrigin = toastOrigin(in: visibleFrame, toastSize: layout.size, position: nearestPosition)
        let finalPanelFrame = NSRect(
            origin: NSPoint(x: cardOrigin.x - TrackNotificationLayout.shadowInset, y: cardOrigin.y - TrackNotificationLayout.shadowInset),
            size: layout.panelSize
        )

        // Haptic snap feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

        // Smooth spring magnetic snap animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.26
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(finalPanelFrame, display: true)
        }

        // Save position to settings
        SettingsModel.shared.trackNotificationPosition = nearestPosition
    }

    private func findNearestPosition(forWindowOrigin currentOrigin: NSPoint, windowSize: NSSize, on screen: NSScreen) -> TrackNotificationPosition {
        let visibleFrame = screen.visibleFrame
        let shadowInset = TrackNotificationLayout.shadowInset
        let cardSize = NSSize(width: windowSize.width - shadowInset * 2, height: windowSize.height - shadowInset * 2)

        var nearestPosition: TrackNotificationPosition = SettingsModel.shared.trackNotificationPosition
        var minDistance: CGFloat = .greatestFiniteMagnitude

        for pos in TrackNotificationPosition.allCases {
            let cardPosOrigin = toastOrigin(in: visibleFrame, toastSize: cardSize, position: pos)
            let posPanelOrigin = NSPoint(x: cardPosOrigin.x - shadowInset, y: cardPosOrigin.y - shadowInset)

            let dist = hypot(currentOrigin.x - posPanelOrigin.x, currentOrigin.y - posPanelOrigin.y)
            if dist < minDistance {
                minDistance = dist
                nearestPosition = pos
            }
        }
        return nearestPosition
    }

    private func toastOrigin(
        in frame: NSRect,
        toastSize: NSSize,
        position: TrackNotificationPosition
    ) -> NSPoint {
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

// MARK: - Custom Panel Subclass with Native Mouse Dragging

final class NonActivatingToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if self.isMovableByWindowBackground {
                HUDToastManager.shared.handleNativeDragStart(window: self)
            }
        case .leftMouseDragged:
            if self.isMovableByWindowBackground {
                HUDToastManager.shared.handleNativeDragMoved(window: self)
            }
        case .leftMouseUp:
            if self.isMovableByWindowBackground {
                HUDToastManager.shared.handleNativeDragEnded(window: self)
            }
        default:
            break
        }
        super.sendEvent(event)
    }
}

// MARK: - Translucent Ghost Snap Placeholders Window & View

final class SnapGuideOverlayWindow: NSPanel {
    private var hostingView: NSHostingView<SnapGuideOverlayView>?

    init(screen: NSScreen, cardSize: NSSize, activePosition: TrackNotificationPosition) {
        let frame = screen.frame
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let view = SnapGuideOverlayView(screenFrame: screen.visibleFrame, cardSize: cardSize, activePosition: activePosition)
        let hosting = NSHostingView(rootView: view)
        self.contentView = hosting
        self.hostingView = hosting
    }

    func updateActivePosition(_ position: TrackNotificationPosition, cardSize: NSSize) {
        guard let hostingView else { return }
        let currentFrame = hostingView.rootView.screenFrame
        hostingView.rootView = SnapGuideOverlayView(
            screenFrame: currentFrame,
            cardSize: cardSize,
            activePosition: position
        )
    }
}

struct SnapGuideOverlayView: View {
    let screenFrame: NSRect
    let cardSize: NSSize
    let activePosition: TrackNotificationPosition

    @ObservedObject private var model = NowPlayingModel.shared

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            ForEach(TrackNotificationPosition.allCases) { pos in
                let origin = ghostCardOrigin(for: pos)
                let isActive = (pos == activePosition)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isActive ? model.platformAccentColor.opacity(0.22) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isActive ? model.platformAccentColor : Color.white.opacity(0.28),
                                    style: StrokeStyle(
                                        lineWidth: isActive ? 2.5 : 1.5,
                                        dash: isActive ? [] : [6, 4]
                                    )
                                )
                        )
                        .shadow(color: isActive ? model.platformAccentColor.opacity(0.60) : .clear, radius: 14)

                    HStack(spacing: 8) {
                        Image(systemName: pos.iconName)
                            .font(.system(size: 14, weight: .bold))
                        Text(LocalizationManager.shared.string(pos.localizationKey))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(isActive ? .white : .white.opacity(0.55))
                }
                .frame(width: cardSize.width, height: cardSize.height)
                .position(
                    x: origin.x + cardSize.width / 2,
                    y: screenFrame.height - (origin.y + cardSize.height / 2)
                )
                .scaleEffect(isActive ? 1.04 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isActive)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
    }

    private func ghostCardOrigin(for pos: TrackNotificationPosition) -> NSPoint {
        let horizontalPadding = min(22, max(12, (screenFrame.width - cardSize.width) / 2))
        let verticalPadding = min(22, max(12, (screenFrame.height - cardSize.height) / 2))

        let x: CGFloat
        switch pos {
        case .topLeading, .leading, .bottomLeading:
            x = horizontalPadding
        case .top, .bottom:
            x = (screenFrame.width - cardSize.width) / 2
        case .topTrailing, .trailing, .bottomTrailing:
            x = screenFrame.width - cardSize.width - horizontalPadding
        }

        let y: CGFloat
        switch pos {
        case .topLeading, .top, .topTrailing:
            y = screenFrame.height - cardSize.height - verticalPadding
        case .leading, .trailing:
            y = (screenFrame.height - cardSize.height) / 2
        case .bottomLeading, .bottom, .bottomTrailing:
            y = verticalPadding
        }

        return NSPoint(x: x, y: y)
    }
}
