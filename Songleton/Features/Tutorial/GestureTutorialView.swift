import SwiftUI
import AppKit

enum TutorialStage: Int, CaseIterable, Identifiable {
    case cancelDemo = 0
    case rightEdgeSkip = 1
    case topEdgePlayPause = 2
    case volumeControl = 3
    case leftClickToggle = 4
    case hoverMenu = 5
    case ambientMode = 6
    case permanentMiniPlayer = 7

    var id: Int { rawValue }
}

enum TutorialPointerMotion {
    static func minimumJerk(_ value: CGFloat) -> CGFloat {
        let t = min(max(value, 0), 1)
        return t * t * t * (10 + t * (-15 + 6 * t))
    }

    static func duration(distance: CGFloat, requested: Double) -> Double {
        let distanceDriven = 0.32 + Double(max(distance, 0)) / 920
        return min(0.92, max(requested, distanceDriven))
    }

    static func controlPoints(
        from start: CGPoint,
        to end: CGPoint,
        sequence: Int
    ) -> (first: CGPoint, second: CGPoint) {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let distance = hypot(delta.x, delta.y)
        guard distance > 0.5 else { return (start, end) }

        let direction = CGPoint(x: delta.x / distance, y: delta.y / distance)
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let bendDirection: CGFloat = sequence.isMultiple(of: 2) ? 1 : -1
        let bend = min(48, max(10, distance * 0.09)) * bendDirection
        let overshoot = min(9, max(1.5, distance * 0.018))

        return (
            CGPoint(
                x: start.x + delta.x * 0.30 + normal.x * bend,
                y: start.y + delta.y * 0.30 + normal.y * bend
            ),
            CGPoint(
                x: end.x + direction.x * overshoot - normal.x * bend * 0.18,
                y: end.y + direction.y * overshoot - normal.y * bend * 0.18
            )
        )
    }

    static func point(
        from start: CGPoint,
        to end: CGPoint,
        firstControl: CGPoint,
        secondControl: CGPoint,
        progress: CGFloat
    ) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * inverse * start.x
                + 3 * inverse * inverse * t * firstControl.x
                + 3 * inverse * t * t * secondControl.x
                + t * t * t * end.x,
            y: inverse * inverse * inverse * start.y
                + 3 * inverse * inverse * t * firstControl.y
                + 3 * inverse * t * t * secondControl.y
                + t * t * t * end.y
        )
    }
}

struct GestureTutorialView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onComplete: () -> Void
    var onDismiss: () -> Void

    @State private var currentStage: TutorialStage = .cancelDemo
    @State private var cursorPosition: CGPoint = .zero
    @State private var isStageAnimationRunning = true
    @State private var isPlaybackPaused = false
    @State private var isPlaybackResuming = false
    @State private var isHoverPanelVisible = false
    @State private var isTrackRightClicking = false
    @State private var isAmbientPreviewVisible = false
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var cursorScale: CGFloat = 1
    @State private var cursorRotation: Double = -5
    @State private var isCursorPressed = false
    @State private var cursorMoveSequence = 0
    @State private var isCmdOptKeyPressed = false
    @State private var isDualMousePressed = false
    @State private var isTutorialComplete = false
    @State private var completionPop = false

    // Mock MouseGestureManager for real overlay component
    @StateObject private var mockManager = MouseGestureManager()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Dark Ambient Background Overlay with Subtle Radial Glow
                Color.black.opacity(0.90)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [SongletonTheme.cyan.opacity(0.14), .black.opacity(0.94)],
                    center: .center,
                    startRadius: 160,
                    endRadius: 900
                )
                .ignoresSafeArea()

                // 2. Animated Demonstration Canvas
                ZStack {
                    if isEdgeGestureStage {
                        edgeHotspotIndicators(size: geo.size)
                        edgeGestureStatus
                            .position(x: geo.size.width / 2, y: edgeDemoY(for: geo.size) - 108)
                            .zIndex(5)
                    }

                    if currentStage == .volumeControl {
                        volumeControlCanvas
                            .position(x: geo.size.width / 2, y: demoCenterY(for: geo.size))
                            .zIndex(20)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }

                    if currentStage == .leftClickToggle || currentStage == .hoverMenu || currentStage == .ambientMode {
                        FullMacOSMenuBarPreview(isRightClicking: isTrackRightClicking, isPlaying: !isPlaybackPaused)
                            .frame(width: geo.size.width)
                            .position(x: geo.size.width / 2, y: menuBarCenterY(for: geo.size))
                            .zIndex(25)
                    }

                    if currentStage == .hoverMenu && isHoverPanelVisible {
                        TutorialHoverPanelPreview()
                            .scaleEffect(0.88)
                            .allowsHitTesting(false)
                            .position(x: songletonMenuBarX(for: geo.size), y: menuBarCenterY(for: geo.size) + 152)
                            .zIndex(24)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }

                    if isAmbientPreviewVisible {
                        AmbientView(onClose: {})
                            .frame(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea()
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            .zIndex(30)
                    }

                    // REAL APP EDGE GESTURE OVERLAY COMPONENT (Left / Right / Top)
                    if currentStage == .cancelDemo || currentStage == .rightEdgeSkip || currentStage == .topEdgePlayPause {
                        CursorGestureOverlayView(
                            manager: mockManager,
                            zone: currentZone(for: currentStage)
                        )
                        .position(edgeOverlayPosition(for: currentStage, size: geo.size))
                        .zIndex(15)
                    }

                    if currentStage == .permanentMiniPlayer {
                        let layout = TrackNotificationLayout.make(
                            track: localization.string("notification.preview_track"),
                            artist: localization.string("notification.preview_artist"),
                            in: NSRect(origin: .zero, size: geo.size),
                            isPermanent: true
                        )
                        HUDToastView(
                            track: localization.string("notification.preview_track"),
                            artist: localization.string("notification.preview_artist"),
                            artwork: nil,
                            layout: layout,
                            accentColor: SongletonTheme.cyan,
                            isPreview: true
                        )
                        .position(x: geo.size.width / 2, y: demoCenterY(for: geo.size))
                        .zIndex(20)
                    }

                    animatedMouseCursor(size: geo.size)
                        .zIndex(45)

                    if currentStage == .topEdgePlayPause && isPlaybackPaused {
                        Label(localization.string("tutorial.playback_paused"), systemImage: "pause.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.orange.opacity(0.82), in: Capsule())
                            .position(x: geo.size.width / 2, y: edgeDemoY(for: geo.size) - 158)
                    }

                    if currentStage == .topEdgePlayPause && isPlaybackResuming {
                        Label(localization.string("tutorial.playback_resuming"), systemImage: "play.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(SongletonTheme.cyan.opacity(0.85), in: Capsule())
                            .position(x: geo.size.width / 2, y: edgeDemoY(for: geo.size) - 158)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                if isTutorialComplete {
                    tutorialCompletionView
                        .zIndex(200)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else if !isAmbientPreviewVisible {
                    tutorialChrome(size: geo.size)
                        .zIndex(60)
                }
            }
            .onAppear {
                cursorPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                TutorialAudioService.shared.beginSession()
                runStageAnimation(stage: currentStage, size: geo.size)
            }
            .onDisappear {
                animationTask?.cancel()
                TutorialAudioService.shared.stop()
            }
        }
    }

    private func menuBarCenterY(for size: CGSize) -> CGFloat {
        min(84, max(66, size.height * 0.10))
    }

    private func songletonMenuBarX(for size: CGSize) -> CGFloat {
        // Right side of the menu bar mockup holds, from the right edge:
        // ~145pt of system icons (wifi, battery, control center, search, clock)
        // + 14pt gap + half of the ~150pt Songleton item. The track title sits
        // near the item's center, so the cursor tip should land at this x.
        let rightOffset: CGFloat = 145 + 14 + (150 / 2)
        return max(180, size.width - rightOffset)
    }

    private func controlClearance(for size: CGSize) -> CGFloat {
        let compact = size.width < 720 || size.height < 760
        let cardHeight: CGFloat = compact ? 262 : 306
        return cardHeight + max(20, size.height * 0.045)
    }

    private func demoCenterY(for size: CGSize) -> CGFloat {
        let preferred = max(224, size.height * 0.36)
        // Largest demo element is 268pt tall (volume canvas). Reserve its half
        // height plus a margin so the card never overlaps the demo on short windows.
        let bounds = size.height - controlClearance(for: size) - 148
        return min(preferred, bounds)
    }

    private func edgeDemoY(for size: CGSize) -> CGFloat {
        let bounds = size.height - controlClearance(for: size) - 70
        return min(size.height * 0.44, bounds)
    }

    // MARK: - Completion Screen ("You're all set!")

    private var tutorialCompletionView: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            RadialGradient(
                colors: [SongletonTheme.cyan.opacity(0.16), .black.opacity(0.96)],
                center: .center,
                startRadius: 120,
                endRadius: 760
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(SongletonTheme.cyan.opacity(0.15))
                        .frame(width: 150, height: 150)
                        .blur(radius: 22)

                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [SongletonTheme.cyan, .clear, SongletonTheme.violet, SongletonTheme.pink.opacity(0.5), .clear],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 132, height: 132)
                        .rotationEffect(.degrees(completionPop ? 360 : 0))
                        .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: completionPop)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SongletonTheme.cyan, SongletonTheme.violet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 78, height: 78)
                        .shadow(color: SongletonTheme.cyan.opacity(0.55), radius: 18)
                        .scaleEffect(completionPop ? 1 : 0.4)
                        .opacity(completionPop ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.6), value: completionPop)

                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(.black)
                        .scaleEffect(completionPop ? 1 : 0.4)
                        .opacity(completionPop ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.08), value: completionPop)
                }
                .frame(height: 150)

                VStack(spacing: 9) {
                    Text(localization.string("tutorial.complete_title"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: completionPop ? 0 : 14)
                        .opacity(completionPop ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.12), value: completionPop)

                    Text(localization.string("tutorial.complete_desc"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .offset(y: completionPop ? 0 : 12)
                        .opacity(completionPop ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.18), value: completionPop)
                }

                Button(action: onComplete) {
                    HStack(spacing: 9) {
                        Text(localization.string("tutorial.complete_start"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [SongletonTheme.cyan, SongletonTheme.violet.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: SongletonTheme.cyan.opacity(0.4), radius: 14, y: 6)
                    .scaleEffect(completionPop ? 1 : 0.85)
                    .opacity(completionPop ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.24), value: completionPop)
                }
                .buttonStyle(.plain)
            }
            .padding(30)
        }
        .onAppear {
            completionPop = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    completionPop = true
                }
            }
        }
    }

    @ViewBuilder
    private func tutorialChrome(size: CGSize) -> some View {
        VStack(spacing: 0) {
            topBarView
                .padding(.horizontal, size.width < 700 ? 20 : 36)
                .padding(.top, size.height < 700 ? 18 : 28)

            Spacer(minLength: 0)

            stageControlCard(size: size)
                .padding(.horizontal, size.width < 700 ? 16 : 28)
                .padding(.bottom, max(20, size.height * 0.045))
        }
    }

    private var volumeControlCanvas: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Label(localization.string("tutorial.volume_control_header"), systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(localization.string("tutorial.volume_control_desc"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .frame(width: 260, alignment: .leading)

                HStack(spacing: 8) {
                    tutorialInputPill(symbol: "⌘", label: localization.string("key.command"), isPressed: isCmdOptKeyPressed)
                    tutorialInputPill(symbol: "⌥", label: localization.string("key.option"), isPressed: isCmdOptKeyPressed)
                    Image(systemName: "arrow.up.and.down")
                        .foregroundStyle(isCmdOptKeyPressed ? SongletonTheme.cyan : .white.opacity(0.6))
                    Text(localization.string("tutorial.volume_drag_short"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isCmdOptKeyPressed ? .white : .white.opacity(0.75))
                }

                tutorialMousePill(isPressed: isDualMousePressed)
            }

            VolumeGestureHUDView(manager: mockManager, visualMaximum: 20)
                .shadow(color: SongletonTheme.cyan.opacity(0.35), radius: 20)
        }
        .padding(24)
        .background(SongletonTheme.card.opacity(0.90), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isCmdOptKeyPressed || isDualMousePressed ? SongletonTheme.cyan : Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    private func tutorialInputPill(symbol: String, label: String, isPressed: Bool) -> some View {
        VStack(spacing: 2) {
            Text(symbol)
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(isPressed ? Color.black : SongletonTheme.cyan)
        .frame(width: 58, height: 46)
        .background(
            isPressed
                ? LinearGradient(colors: [SongletonTheme.cyan, .white], startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isPressed ? SongletonTheme.cyan : Color.white.opacity(0.14), lineWidth: isPressed ? 2 : 1)
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .shadow(color: isPressed ? SongletonTheme.cyan.opacity(0.8) : .clear, radius: 10)
        .animation(.easeInOut(duration: 0.16), value: isPressed)
    }

    private func tutorialMousePill(isPressed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isPressed ? Color.black : SongletonTheme.cyan)
            Text(localization.string("tutorial.volume_mouse_alternative"))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isPressed ? Color.black : .white.opacity(0.82))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isPressed
                ? LinearGradient(colors: [SongletonTheme.cyan, .white], startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isPressed ? SongletonTheme.cyan : Color.white.opacity(0.14), lineWidth: isPressed ? 2 : 1)
        )
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .shadow(color: isPressed ? SongletonTheme.cyan.opacity(0.8) : .clear, radius: 10)
        .animation(.easeInOut(duration: 0.16), value: isPressed)
    }

    private var tutorialMenuBarPreview: some View {
        TutorialMenuBarPreview(isRightClicking: isTrackRightClicking)
    }

    // MARK: - Zone Mapping for Real App Overlay

    private func currentZone(for stage: TutorialStage) -> MouseGestureManager.EdgeZone {
        switch stage {
        case .cancelDemo: return .previous
        case .rightEdgeSkip: return .next
        case .topEdgePlayPause: return .playPause
        default: return .next
        }
    }

    private var isEdgeGestureStage: Bool {
        currentStage == .cancelDemo
            || currentStage == .rightEdgeSkip
            || currentStage == .topEdgePlayPause
    }

    private var edgeGestureStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: edgeStatusIcon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SongletonTheme.cyan)
                .frame(width: 30, height: 30)
                .background(SongletonTheme.cyan.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(localization.string("tutorial.edge_gesture_live"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(SongletonTheme.cyan)
                Text(edgeStatusText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var edgeStatusIcon: String {
        switch currentStage {
        case .cancelDemo: "arrow.left"
        case .rightEdgeSkip: "arrow.right"
        case .topEdgePlayPause: "arrow.up"
        default: "cursorarrow.rays"
        }
    }

    private var edgeStatusText: String {
        switch currentStage {
        case .cancelDemo: localization.string("tutorial.edge_status_cancel")
        case .rightEdgeSkip: localization.string("tutorial.edge_status_next")
        case .topEdgePlayPause: localization.string("tutorial.edge_status_playpause")
        default: ""
        }
    }

    private func edgeOverlayPosition(for stage: TutorialStage, size: CGSize) -> CGPoint {
        switch stage {
        case .cancelDemo:
            return CGPoint(x: 56, y: edgeDemoY(for: size))
        case .rightEdgeSkip:
            return CGPoint(x: size.width - 56, y: edgeDemoY(for: size))
        case .topEdgePlayPause:
            return CGPoint(x: size.width / 2, y: 56)
        default:
            return CGPoint(x: size.width - 56, y: edgeDemoY(for: size))
        }
    }

    // MARK: - Screen Edge Hotspot Indicators

    private func edgeHotspotIndicators(size: CGSize) -> some View {
        ZStack {
            // Left Edge Guide
            Rectangle()
                .fill(currentStage == .cancelDemo ? Color(red: 0.98, green: 0.28, blue: 0.31).opacity(0.6) : Color.white.opacity(0.1))
                .frame(width: 4, height: size.height)
                .position(x: 2, y: size.height / 2)
                .shadow(color: currentStage == .cancelDemo ? Color(red: 0.98, green: 0.28, blue: 0.31) : .clear, radius: 12)

            // Right Edge Guide
            Rectangle()
                .fill(currentStage == .rightEdgeSkip ? SongletonTheme.cyan.opacity(0.6) : Color.white.opacity(0.1))
                .frame(width: 4, height: size.height)
                .position(x: size.width - 2, y: size.height / 2)
                .shadow(color: currentStage == .rightEdgeSkip ? SongletonTheme.cyan : .clear, radius: 12)

            // Top Edge Guide
            Rectangle()
                .fill(currentStage == .topEdgePlayPause ? SongletonTheme.violet.opacity(0.6) : Color.white.opacity(0.1))
                .frame(width: size.width, height: 4)
                .position(x: size.width / 2, y: 2)
                .shadow(color: currentStage == .topEdgePlayPause ? SongletonTheme.violet : .clear, radius: 12)
        }
    }

    // MARK: - Animated Mouse Cursor Element

    private func animatedMouseCursor(size: CGSize) -> some View {
        ZStack {
            if currentStage == .volumeControl && isCursorPressed {
                VStack(spacing: 4) {
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SongletonTheme.cyan)
                        .opacity(0.8)
                    Rectangle()
                        .fill(LinearGradient(colors: [SongletonTheme.cyan, SongletonTheme.violet], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2, height: 90)
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SongletonTheme.violet)
                        .opacity(0.8)
                }
                .shadow(color: SongletonTheme.cyan.opacity(0.6), radius: 8)

                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.and.down.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SongletonTheme.cyan)
                    Text(localization.string("tutorial.volume_drag_short"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.88), in: Capsule())
                .overlay(Capsule().stroke(SongletonTheme.cyan.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 10)
                .offset(x: 75, y: -24)
            }

            Circle()
                .fill((isTrackRightClicking ? SongletonTheme.violet : SongletonTheme.cyan).opacity(isCursorPressed ? 0.28 : 0.0))
                .frame(width: 42, height: 42)
                .blur(radius: 4)

            Image(systemName: "cursorarrow")
                .font(.system(size: 31, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.82)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.78), radius: 7, x: 2, y: 4)
                .shadow(
                    color: (isTrackRightClicking ? SongletonTheme.violet : SongletonTheme.cyan)
                        .opacity(isCursorPressed ? 0.65 : 0.18),
                    radius: isCursorPressed ? 12 : 4
                )
                .scaleEffect(cursorScale, anchor: .topLeading)
                .rotationEffect(.degrees(cursorRotation), anchor: .topLeading)
                // cursorarrow's tip is its top-left corner; shift the glyph so the
                // tip lands exactly on cursorPosition (menu bar track name etc.).
                .offset(x: 15.5, y: 15.5)
        }
        .position(cursorPosition)
        .accessibilityHidden(true)
    }

    // MARK: - Top Header Bar

    private var topBarView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SongletonTheme.cyan)
                Text(localization.string("tutorial.title"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Text(verbatim: "ESC")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    Text(localization.string("ambient.exit"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localization.string("ambient.exit"))
            .accessibilityHint(localization.string("tutorial.close_hint"))
        }
    }

    // MARK: - Stage Control Card Panel

    private func stageControlCard(size: CGSize) -> some View {
        let compact = size.width < 720 || size.height < 760
        let short = size.height < 720

        return VStack(spacing: compact ? 12 : 16) {
            HStack {
                Text(String(
                    format: localization.string("tutorial.step_progress_format"),
                    currentStage.rawValue + 1,
                    TutorialStage.allCases.count
                ))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(SongletonTheme.cyan)
                Spacer()
                Text(stageTitle(currentStage))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            ProgressView(value: Double(currentStage.rawValue + 1), total: Double(TutorialStage.allCases.count))
                .tint(SongletonTheme.cyan)

            VStack(spacing: 7) {
                Text(stageHeader(currentStage))
                    .font(.system(size: compact ? 18 : 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(stageDescription(currentStage))
                    .font(.system(size: compact ? 12.5 : 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 560)

            if !short {
                HStack(spacing: 8) {
                    Image(systemName: isStageAnimationRunning ? "sparkles" : "checkmark.circle.fill")
                        .foregroundStyle(SongletonTheme.cyan)
                    Text(isStageAnimationRunning
                        ? localization.string("tutorial.demo_running")
                        : localization.string("tutorial.continue_hint"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                }
            }

            Group {
                if compact {
                    VStack(spacing: 8) {
                        replayButton(size: size)
                        primaryStageButton(size: size)
                    }
                } else {
                    HStack(spacing: 12) {
                        replayButton(size: size)
                        primaryStageButton(size: size)
                    }
                }
            }
        }
        .padding(.horizontal, compact ? 18 : 28)
        .padding(.vertical, compact ? 12 : 22)
        .frame(maxWidth: 680)
        .background(SongletonTheme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.62), radius: 24, y: 12)
    }

    private func replayButton(size: CGSize) -> some View {
        Button {
            runStageAnimation(stage: currentStage, size: size)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                Text(localization.string("common.try_again"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(minWidth: 168, maxWidth: .infinity, minHeight: 48)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isStageAnimationRunning)
        .accessibilityLabel(localization.string("common.try_again"))
    }

    @ViewBuilder
    private func primaryStageButton(size: CGSize) -> some View {
        if currentStage.rawValue < TutorialStage.allCases.count - 1 {
            Button {
                if let next = TutorialStage(rawValue: currentStage.rawValue + 1) {
                    switchStage(to: next, size: size)
                }
            } label: {
                HStack(spacing: 5) {
                    Text(isStageAnimationRunning ? localization.string("tutorial.demo_running") : localization.string("common.continue"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(minWidth: 210, maxWidth: .infinity, minHeight: 48)
                .background(SongletonTheme.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isStageAnimationRunning)
            .accessibilityLabel(localization.string("common.continue"))
        } else {
            Button {
                onComplete()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(localization.string("common.start"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(minWidth: 210, maxWidth: .infinity, minHeight: 48)
                .background(SongletonTheme.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isStageAnimationRunning)
            .accessibilityLabel(localization.string("common.start"))
        }
    }

    // MARK: - Animation Controller & Sound Triggers

    private func switchStage(to stage: TutorialStage, size: CGSize) {
        currentStage = stage
        runStageAnimation(stage: stage, size: size)
    }

    private func prepareAudio(for stage: TutorialStage) {
        switch stage {
        case .cancelDemo:
            TutorialAudioService.shared.start()
        case .rightEdgeSkip:
            // Stage 2 demonstrates the transition at the end of the gesture.
            if TutorialAudioService.shared.currentTrack != 1 {
                TutorialAudioService.shared.start()
            } else {
                TutorialAudioService.shared.resume(fadeIn: true)
            }
        case .topEdgePlayPause, .volumeControl, .leftClickToggle, .hoverMenu, .ambientMode, .permanentMiniPlayer:
            if TutorialAudioService.shared.currentTrack != 2 {
                TutorialAudioService.shared.switchToSecondTrack()
            } else {
                TutorialAudioService.shared.resume(fadeIn: true)
            }
        }
    }

    private func moveCursor(
        to point: CGPoint,
        duration: Double,
        rotation: Double = -5,
        scale: CGFloat = 1
    ) async {
        if reduceMotion {
            withAnimation(.linear(duration: min(duration, 0.18))) {
                cursorPosition = point
                cursorRotation = rotation
                cursorScale = scale
            }
            try? await Task.sleep(for: .seconds(min(duration, 0.18)))
            return
        }

        let start = cursorPosition
        let startRotation = cursorRotation
        let startScale = cursorScale
        let delta = CGPoint(x: point.x - start.x, y: point.y - start.y)
        let distance = hypot(delta.x, delta.y)
        guard distance > 0.5 else {
            cursorPosition = point
            cursorRotation = rotation
            cursorScale = scale
            return
        }

        cursorMoveSequence += 1
        let controls = TutorialPointerMotion.controlPoints(
            from: start,
            to: point,
            sequence: cursorMoveSequence
        )
        let naturalDuration = TutorialPointerMotion.duration(distance: distance, requested: duration)
        let frameCount = max(12, Int(naturalDuration * 60))
        let frameDuration = naturalDuration / Double(frameCount)

        for frame in 1...frameCount {
            guard !Task.isCancelled else { return }
            let linearT = CGFloat(frame) / CGFloat(frameCount)
            let t = TutorialPointerMotion.minimumJerk(linearT)
            cursorPosition = TutorialPointerMotion.point(
                from: start,
                to: point,
                firstControl: controls.first,
                secondControl: controls.second,
                progress: t
            )
            cursorRotation = startRotation + (rotation - startRotation) * Double(t)
            cursorScale = startScale + (scale - startScale) * t
            try? await Task.sleep(for: .seconds(frameDuration))
        }

        if !Task.isCancelled {
            cursorPosition = point
            cursorRotation = rotation
            cursorScale = scale
        }
    }

    private func setCursorPressed(_ pressed: Bool, rightClick: Bool = false) async {
        withAnimation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.62)) {
            isCursorPressed = pressed
            cursorScale = pressed ? (rightClick ? 0.90 : 0.86) : 1
            cursorRotation = pressed ? (rightClick ? -9 : -1) : -5
        }
        try? await Task.sleep(for: .milliseconds(pressed ? 120 : 90))
    }

    private func animateVolume(
        from start: Int,
        to end: Int,
        cursorTarget: CGPoint,
        duration: Double
    ) async {
        let origin = cursorPosition
        let delta = CGPoint(x: cursorTarget.x - origin.x, y: cursorTarget.y - origin.y)
        let distance = max(hypot(delta.x, delta.y), 1)
        let normal = CGPoint(x: -delta.y / distance, y: delta.x / distance)
        let control = CGPoint(
            x: origin.x + delta.x * 0.52 + normal.x * min(18, distance * 0.06),
            y: origin.y + delta.y * 0.52 + normal.y * min(18, distance * 0.06)
        )
        let frameCount = reduceMotion ? 6 : max(12, Int(duration * 60))
        let frameDuration = duration / Double(frameCount)
        var lastValue: Int?

        for frame in 1...frameCount {
            guard !Task.isCancelled else { return }
            let linearT = CGFloat(frame) / CGFloat(frameCount)
            let t = TutorialPointerMotion.minimumJerk(linearT)
            let inverse = 1 - t
            cursorPosition = CGPoint(
                x: inverse * inverse * origin.x + 2 * inverse * t * control.x + t * t * cursorTarget.x,
                y: inverse * inverse * origin.y + 2 * inverse * t * control.y + t * t * cursorTarget.y
            )
            let value = Int((Double(start) + Double(end - start) * Double(t)).rounded())
            if value != lastValue {
                mockManager.simulateGestureVolume(value)
                TutorialAudioService.shared.setDemoVolume(value)
                lastValue = value
            }
            try? await Task.sleep(for: .seconds(frameDuration))
        }
        cursorPosition = cursorTarget
    }

    private func runStageAnimation(stage: TutorialStage, size: CGSize) {
        animationTask?.cancel()
        isStageAnimationRunning = true
        isPlaybackPaused = false
        isPlaybackResuming = false
        isHoverPanelVisible = false
        isTrackRightClicking = false
        isAmbientPreviewVisible = false
        isTutorialComplete = false
        completionPop = false
        mockManager.simulateEdgeGestureProgress(0)
        mockManager.simulateGestureVolume(8)
        TutorialAudioService.shared.setDemoVolume(8)
        prepareAudio(for: stage)

        cursorScale = 1
        cursorRotation = -5
        isCursorPressed = false

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            switch stage {
            case .cancelDemo:
                let edgeY = edgeDemoY(for: size)
                await moveCursor(
                    to: CGPoint(x: 10, y: edgeY),
                    duration: 0.64,
                    rotation: -13,
                    scale: 0.94
                )
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }

                for p in 0...45 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(14))
                }

                await moveCursor(
                    to: CGPoint(x: 164, y: edgeY + 18),
                    duration: 0.28,
                    rotation: 3,
                    scale: 1.08
                )
                mockManager.simulateEdgeGestureCancelBurst()
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false

            case .rightEdgeSkip:
                let edgeY = edgeDemoY(for: size)
                await moveCursor(
                    to: CGPoint(x: size.width - 10, y: edgeY),
                    duration: 0.68,
                    rotation: 10,
                    scale: 0.94
                )
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }

                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(9))
                }

                // The track change lands exactly when the ring completes, so the
                // audio transition is heard at the same instant as the burst.
                TutorialAudioService.shared.switchToSecondTrack()
                mockManager.simulateEdgeGestureBurst()
                await moveCursor(
                    to: CGPoint(x: size.width - 74, y: edgeY - 12),
                    duration: 0.22,
                    rotation: 3,
                    scale: 1.04
                )
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false

            case .topEdgePlayPause:
                let pauseY = min(edgeDemoY(for: size) - 122, 160)
                await moveCursor(
                    to: CGPoint(x: size.width / 2, y: 10),
                    duration: 0.70,
                    rotation: -6,
                    scale: 0.94
                )
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }

                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(9))
                }

                mockManager.simulateEdgeGestureBurst()
                mockManager.simulateEdgeGestureProgress(0)
                TutorialAudioService.shared.pause()
                isPlaybackPaused = true
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                await moveCursor(
                    to: CGPoint(x: size.width * 0.48, y: pauseY),
                    duration: 0.34,
                    rotation: 2
                )
                try? await Task.sleep(for: .milliseconds(760))
                guard !Task.isCancelled else { return }

                await moveCursor(
                    to: CGPoint(x: size.width / 2, y: 10),
                    duration: 0.52,
                    rotation: -6,
                    scale: 0.94
                )
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }

                isPlaybackResuming = true
                isPlaybackPaused = false
                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(8))
                }

                TutorialAudioService.shared.resume(fadeIn: true)
                isPlaybackPaused = false
                mockManager.simulateEdgeGestureProgress(0)
                mockManager.simulateEdgeGestureBurst()
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                isPlaybackResuming = false
                isStageAnimationRunning = false

            case .volumeControl:
                let volumeCenterY = demoCenterY(for: size)
                // Cursor lands 40pt right of the HUD column center so the drag
                // animation plays over the slider's own track, not its label.
                let volumeX = min(size.width - 25, size.width / 2 + 290)
                let topY = volumeCenterY - 82
                let bottomY = volumeCenterY + 72

                // --- METHOD 1: KEYBOARD SHORTCUT (⌘ + ⌥ + DRAG) ---
                withAnimation {
                    isCmdOptKeyPressed = true
                    isDualMousePressed = false
                }
                await moveCursor(
                    to: CGPoint(x: volumeX, y: topY),
                    duration: 0.52,
                    rotation: -4,
                    scale: 0.96
                )
                await setCursorPressed(true)
                guard !Task.isCancelled else { return }

                await animateVolume(
                    from: 8,
                    to: 0,
                    cursorTarget: CGPoint(x: volumeX, y: bottomY),
                    duration: 0.74
                )
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                await animateVolume(
                    from: 0,
                    to: 20,
                    cursorTarget: CGPoint(x: volumeX, y: topY),
                    duration: 0.95
                )
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }

                await setCursorPressed(false)
                withAnimation { isCmdOptKeyPressed = false }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }

                // --- METHOD 2: DUAL MOUSE BUTTON HOLD & DRAG ---
                withAnimation {
                    isDualMousePressed = true
                    isCmdOptKeyPressed = false
                }
                await moveCursor(
                    to: CGPoint(x: volumeX, y: topY),
                    duration: 0.45,
                    rotation: -6,
                    scale: 0.96
                )
                await setCursorPressed(true, rightClick: true)
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }

                // Drag DOWN (20 -> 5)
                await animateVolume(
                    from: 20,
                    to: 5,
                    cursorTarget: CGPoint(x: volumeX, y: bottomY),
                    duration: 0.75
                )
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                // Drag UP (5 -> 14)
                await animateVolume(
                    from: 5,
                    to: 14,
                    cursorTarget: CGPoint(x: volumeX, y: topY),
                    duration: 0.75
                )
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                await setCursorPressed(false)
                withAnimation { isDualMousePressed = false }
                isStageAnimationRunning = false

            case .leftClickToggle:
                let menuBarX = songletonMenuBarX(for: size)
                let menuBarY = menuBarCenterY(for: size)
                await moveCursor(
                    to: CGPoint(x: menuBarX, y: menuBarY),
                    duration: 0.66,
                    rotation: -5,
                    scale: 0.95
                )
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled else { return }

                // 1st Click: Pause song
                await setCursorPressed(true)
                TutorialAudioService.shared.pause()
                withAnimation { isPlaybackPaused = true }
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await setCursorPressed(false)
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }

                // 2nd Click: Resume song
                await setCursorPressed(true)
                TutorialAudioService.shared.resume(fadeIn: true)
                withAnimation { isPlaybackPaused = false }
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await setCursorPressed(false)
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false

            case .hoverMenu:
                let menuBarX = songletonMenuBarX(for: size)
                let menuBarY = menuBarCenterY(for: size)
                await moveCursor(
                    to: CGPoint(x: menuBarX, y: menuBarY),
                    duration: 0.66,
                    rotation: -5,
                    scale: 0.95
                )
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    isHoverPanelVisible = true
                }
                try? await Task.sleep(for: .milliseconds(1200))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false

            case .ambientMode:
                let menuBarX = songletonMenuBarX(for: size)
                let menuBarY = menuBarCenterY(for: size)
                await moveCursor(
                    to: CGPoint(x: menuBarX, y: menuBarY),
                    duration: 0.62,
                    rotation: -5,
                    scale: 0.95
                )
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }

                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    isTrackRightClicking = true
                }
                await setCursorPressed(true, rightClick: true)
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                await setCursorPressed(false, rightClick: true)

                // Populate mock now playing data and open FULL SCREEN Ambient Mode!
                NowPlayingModel.shared.setMockStateForTutorial()
                withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) {
                    isAmbientPreviewVisible = true
                }

                // Let Ambient breathe on screen for a moment, then crossfade
                // into the Permanent Mini Player stage.
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                    isAmbientPreviewVisible = false
                }
                switchStage(to: .permanentMiniPlayer, size: size)

            case .permanentMiniPlayer:
                let demoY = demoCenterY(for: size)
                let startPoint = CGPoint(x: size.width / 2, y: demoY)
                let targetPoint = CGPoint(x: size.width * 0.70, y: demoY - 45)

                await moveCursor(
                    to: startPoint,
                    duration: 0.65,
                    rotation: -5,
                    scale: 0.96
                )
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }

                await setCursorPressed(true)
                await moveCursor(
                    to: targetPoint,
                    duration: 0.85,
                    rotation: -2,
                    scale: 0.94
                )
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                await setCursorPressed(false)
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }

                isStageAnimationRunning = false
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.55)) {
                    isTutorialComplete = true
                }
            }
        }
    }

    // MARK: - Helpers & Localized Strings

    private func stageTitle(_ stage: TutorialStage) -> String {
        let title: String
        switch stage {
        case .cancelDemo: title = localization.string("tutorial.stage_cancel")
        case .rightEdgeSkip: title = localization.string("menu.next_track")
        case .topEdgePlayPause: title = localization.string("tutorial.stage_playpause")
        case .volumeControl: title = localization.string("tutorial.stage_volume_control")
        case .leftClickToggle: title = localization.string("tutorial.stage_left_click")
        case .hoverMenu: title = localization.string("tutorial.stage_hover_menu")
        case .ambientMode: title = localization.string("tutorial.stage_ambient_mode")
        case .permanentMiniPlayer: title = localization.string("tutorial.stage_permanent_mini_player")
        }
        return String(
            format: localization.string("tutorial.stage_title_format"),
            stage.rawValue + 1,
            title
        )
    }

    private func stageHeader(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_header")
        case .rightEdgeSkip: localization.string("tutorial.next_header")
        case .topEdgePlayPause: localization.string("tutorial.playpause_header")
        case .volumeControl: localization.string("tutorial.volume_control_header")
        case .leftClickToggle: localization.string("tutorial.left_click_header")
        case .hoverMenu: localization.string("tutorial.hover_menu_header")
        case .ambientMode: localization.string("tutorial.ambient_mode_header")
        case .permanentMiniPlayer: localization.string("tutorial.permanent_mini_player_header")
        }
    }

    private func stageDescription(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_desc")
        case .rightEdgeSkip: localization.string("tutorial.next_desc")
        case .topEdgePlayPause: localization.string("tutorial.playpause_desc")
        case .volumeControl: localization.string("tutorial.volume_control_desc")
        case .leftClickToggle: localization.string("tutorial.left_click_desc")
        case .hoverMenu: localization.string("tutorial.hover_menu_desc")
        case .ambientMode: localization.string("tutorial.ambient_mode_desc")
        case .permanentMiniPlayer: localization.string("tutorial.permanent_mini_player_desc")
        }
    }
}
