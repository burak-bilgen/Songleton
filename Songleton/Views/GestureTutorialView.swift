import SwiftUI
import AppKit

enum TutorialStage: Int, CaseIterable, Identifiable {
    case cancelDemo = 0
    case rightEdgeSkip = 1
    case topEdgePlayPause = 2
    case volumeControl = 3
    case hoverMenu = 4
    case ambientMode = 5

    var id: Int { rawValue }
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
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 - 115)
                            .zIndex(5)
                    }

                    if currentStage == .volumeControl {
                        volumeControlCanvas
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 - 145)
                            .zIndex(20)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }

                    if currentStage == .hoverMenu || currentStage == .ambientMode {
                        tutorialMenuBarPreview
                            .position(x: geo.size.width / 2, y: 54)
                            .zIndex(25)
                    }

                    if currentStage == .hoverMenu && isHoverPanelVisible {
                        TutorialHoverPanelPreview()
                            .scaleEffect(0.88)
                            .allowsHitTesting(false)
                            .position(x: geo.size.width / 2, y: tutorialPreviewCenterY(for: geo.size))
                            .zIndex(24)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }

                    if isAmbientPreviewVisible {
                        TutorialAmbientPreview()
                            .frame(
                                width: min(680, geo.size.width - 96),
                                height: min(410, max(280, geo.size.height * 0.43))
                            )
                            .allowsHitTesting(false)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.60), radius: 30, y: 16)
                            .position(x: geo.size.width / 2, y: tutorialPreviewCenterY(for: geo.size))
                            .zIndex(24)
                    }

                    // REAL APP EDGE GESTURE OVERLAY COMPONENT (Left / Right / Top)
                    if currentStage == .cancelDemo || currentStage == .rightEdgeSkip || currentStage == .topEdgePlayPause {
                        CursorGestureOverlayView(
                            manager: mockManager,
                            zone: currentZone(for: currentStage)
                        )
                        .position(edgeOverlayPosition(for: currentStage, size: geo.size))
                    }

                    animatedMouseCursor(size: geo.size)

                    if currentStage == .topEdgePlayPause && isPlaybackPaused {
                        Label(localization.string("tutorial.playback_paused"), systemImage: "pause.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.orange.opacity(0.82), in: Capsule())
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 - 190)
                    }

                    if currentStage == .topEdgePlayPause && isPlaybackResuming {
                        Label(localization.string("tutorial.playback_resuming"), systemImage: "play.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(SongletonTheme.cyan.opacity(0.85), in: Capsule())
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 - 190)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                tutorialChrome(size: geo.size)
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

    private var usesBottomAnchoredControls: Bool {
        currentStage == .hoverMenu || currentStage == .ambientMode
    }

    private func tutorialPreviewCenterY(for size: CGSize) -> CGFloat {
        min(size.height * 0.34, 330)
    }

    @ViewBuilder
    private func tutorialChrome(size: CGSize) -> some View {
        if usesBottomAnchoredControls {
            VStack(spacing: 0) {
                topBarView
                    .padding(.horizontal, 36)
                    .padding(.top, 28)

                Spacer(minLength: 0)

                stageControlCard(size: size)
                    .padding(.horizontal, 28)
                    .padding(.bottom, max(34, size.height * 0.055))
                    .zIndex(30)
            }
        } else {
            VStack {
                topBarView
                    .padding(.horizontal, 36)
                    .padding(.top, 28)

                Spacer()

                stageControlCard(size: size)
                    .zIndex(30)

                Spacer()
            }
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
                    .frame(width: 250, alignment: .leading)

                HStack(spacing: 8) {
                    tutorialInputPill(symbol: "⌘", label: "Command")
                    tutorialInputPill(symbol: "⌥", label: "Option")
                    Image(systemName: "arrow.up.and.down")
                        .foregroundStyle(SongletonTheme.cyan)
                    Text(localization.string("tutorial.volume_drag_short"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Label(localization.string("tutorial.volume_mouse_alternative"), systemImage: "computermouse.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            VolumeGestureHUDView(manager: mockManager, visualMaximum: 20)
                .shadow(color: SongletonTheme.cyan.opacity(0.35), radius: 20)
        }
        .padding(24)
        .background(SongletonTheme.card.opacity(0.90), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SongletonTheme.cyan.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    private func tutorialInputPill(symbol: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(symbol)
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(SongletonTheme.cyan)
        .frame(width: 58, height: 46)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
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
        case .volumeControl, .hoverMenu, .ambientMode: return .next
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
        case .volumeControl, .hoverMenu, .ambientMode: "cursorarrow.rays"
        }
    }

    private var edgeStatusText: String {
        switch currentStage {
        case .cancelDemo: localization.string("tutorial.edge_status_cancel")
        case .rightEdgeSkip: localization.string("tutorial.edge_status_next")
        case .topEdgePlayPause: localization.string("tutorial.edge_status_playpause")
        case .volumeControl, .hoverMenu, .ambientMode: ""
        }
    }

    private func edgeOverlayPosition(for stage: TutorialStage, size: CGSize) -> CGPoint {
        switch stage {
        case .cancelDemo:
            return CGPoint(x: 56, y: size.height / 2)
        case .rightEdgeSkip:
            return CGPoint(x: size.width - 56, y: size.height / 2)
        case .topEdgePlayPause:
            return CGPoint(x: size.width / 2, y: 56)
        case .volumeControl, .hoverMenu, .ambientMode:
            return CGPoint(x: size.width - 56, y: size.height / 2)
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
        Image(systemName: "cursorarrow.rays")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.88)], startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.7), radius: 8, x: 2, y: 4)
        .position(cursorPosition)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.75), value: cursorPosition)
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
                    Text("ESC")
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
        VStack(spacing: 16) {
            HStack {
                Text("\(localization.string("tutorial.step_label")) \(currentStage.rawValue + 1) / \(TutorialStage.allCases.count)")
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
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(stageDescription(currentStage))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 560)

            HStack(spacing: 8) {
                Image(systemName: isStageAnimationRunning ? "sparkles" : "checkmark.circle.fill")
                    .foregroundStyle(SongletonTheme.cyan)
                Text(isStageAnimationRunning
                    ? localization.string("tutorial.demo_running")
                    : localization.string("tutorial.continue_hint"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
            }

            HStack(spacing: 12) {
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
                    .frame(minWidth: 168, minHeight: 50)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isStageAnimationRunning)
                .accessibilityLabel(localization.string("common.try_again"))

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
                            .frame(minWidth: 210, minHeight: 50)
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
                            .frame(minWidth: 210, minHeight: 50)
                        .background(SongletonTheme.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStageAnimationRunning)
                    .accessibilityLabel(localization.string("common.start"))
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .frame(maxWidth: 680)
        .background(SongletonTheme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.62), radius: 24, y: 12)
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
        case .topEdgePlayPause, .volumeControl, .hoverMenu, .ambientMode:
            if TutorialAudioService.shared.currentTrack != 2 {
                TutorialAudioService.shared.switchToSecondTrack()
            } else {
                TutorialAudioService.shared.resume(fadeIn: true)
            }
        }
    }

    private func runStageAnimation(stage: TutorialStage, size: CGSize) {
        animationTask?.cancel()
        isStageAnimationRunning = true
        isPlaybackPaused = false
        isPlaybackResuming = false
        isHoverPanelVisible = false
        isTrackRightClicking = false
        isAmbientPreviewVisible = false
        mockManager.simulateEdgeGestureProgress(0)
        mockManager.simulateGestureVolume(8)
        TutorialAudioService.shared.setDemoVolume(8)
        prepareAudio(for: stage)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        cursorPosition = center

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            switch stage {
            case .cancelDemo:
                // Move cursor to left edge
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.75)) {
                    cursorPosition = CGPoint(x: 8, y: size.height / 2)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                // Fill progress to 45% then pull away to cancel
                for p in 0...45 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(12))
                }

                // Pull back away from edge -> Triggers Cancel Overlay!
                withAnimation(reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.45)) {
                    cursorPosition = CGPoint(x: 160, y: size.height / 2)
                    mockManager.simulateEdgeGestureCancelBurst()
                }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false

            case .rightEdgeSkip:
                // Move cursor to right edge
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.75)) {
                    cursorPosition = CGPoint(x: size.width - 8, y: size.height / 2)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                // Fill progress to 100%
                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    // Begin the crossfade only when the action is visibly about
                    // to complete. The gesture remains the cause, not background
                    // music that happens to change at random.
                    if p == 72 {
                        TutorialAudioService.shared.switchToSecondTrack()
                    }
                    try? await Task.sleep(for: .milliseconds(8))
                }

                // Trigger Success Burst
                mockManager.simulateEdgeGestureBurst()
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false

            case .topEdgePlayPause:
                // Move cursor to top center
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.75)) {
                    cursorPosition = CGPoint(x: size.width / 2, y: 8)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                // Fill progress to 100%
                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(8))
                }

                // Trigger Play/Pause Burst
                mockManager.simulateEdgeGestureBurst()
                mockManager.simulateEdgeGestureProgress(0)
                TutorialAudioService.shared.pause()
                isPlaybackPaused = true
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.40)) {
                    cursorPosition = CGPoint(x: size.width / 2, y: 140)
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }

                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.60)) {
                    cursorPosition = CGPoint(x: size.width / 2, y: 8)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                isPlaybackResuming = true
                withAnimation(reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.22)) {
                    cursorPosition = CGPoint(x: size.width / 2, y: 34)
                }
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.22)) {
                    cursorPosition = CGPoint(x: size.width / 2, y: 8)
                }
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }

                // Resume is a fresh gesture. Fill the same live ring before
                // bringing music back so the visual and the audio agree.
                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(6))
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
                // The real volume HUD is the hero. The cursor and audio follow
                // the same vertical gesture so the feedback is understandable.
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.65)) {
                    cursorPosition = CGPoint(x: size.width / 2 + 150, y: size.height / 2 - 145)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                for v in stride(from: 8, through: 0, by: -1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y += 5
                    try? await Task.sleep(for: .milliseconds(28))
                }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                for v in stride(from: 0, through: 20, by: 1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y -= 5
                    try? await Task.sleep(for: .milliseconds(24))
                }
                for v in stride(from: 20, through: 8, by: -1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y += 4
                    try? await Task.sleep(for: .milliseconds(24))
                }
                isStageAnimationRunning = false

            case .hoverMenu:
                // Move to the dummy menu bar item, then hold long enough for hover to open.
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.85)) {
                    cursorPosition = CGPoint(x: size.width / 2, y: 54)
                }
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    isHoverPanelVisible = true
                }
                try? await Task.sleep(for: .milliseconds(1000))
                guard !Task.isCancelled else { return }
                mockManager.simulateEdgeGestureBurst()
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false

            case .ambientMode:
                // Right-click the same dummy track item to reveal Ambient Mode.
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.85)) {
                    cursorPosition = CGPoint(x: size.width / 2, y: 54)
                }
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                isHoverPanelVisible = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    isTrackRightClicking = true
                }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) {
                    isAmbientPreviewVisible = true
                }
                try? await Task.sleep(for: .milliseconds(1100))
                guard !Task.isCancelled else { return }
                isStageAnimationRunning = false
            }
        }
    }

    // MARK: - Helpers & Localized Strings

    private func stageTitle(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: "1. " + localization.string("tutorial.stage_cancel")
        case .rightEdgeSkip: "2. " + localization.string("menu.next_track")
        case .topEdgePlayPause: "3. " + localization.string("tutorial.stage_playpause")
        case .volumeControl: "4. " + localization.string("tutorial.stage_volume_control")
        case .hoverMenu: "5. " + localization.string("tutorial.stage_hover_menu")
        case .ambientMode: "6. " + localization.string("tutorial.stage_ambient_mode")
        }
    }

    private func stageHeader(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_header")
        case .rightEdgeSkip: localization.string("tutorial.next_header")
        case .topEdgePlayPause: localization.string("tutorial.playpause_header")
        case .volumeControl: localization.string("tutorial.volume_control_header")
        case .hoverMenu: localization.string("tutorial.hover_menu_header")
        case .ambientMode: localization.string("tutorial.ambient_mode_header")
        }
    }

    private func stageDescription(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_desc")
        case .rightEdgeSkip: localization.string("tutorial.next_desc")
        case .topEdgePlayPause: localization.string("tutorial.playpause_desc")
        case .volumeControl: localization.string("tutorial.volume_control_desc")
        case .hoverMenu: localization.string("tutorial.hover_menu_desc")
        case .ambientMode: localization.string("tutorial.ambient_mode_desc")
        }
    }
}

// MARK: - Large Mouse Diagram View for Dual-Click Volume Tutorial

struct LargeMouseDiagramView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let isBothPressed: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(localization.string("tutorial.volume_mouse_header"))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            ZStack {
                // Mouse Outer Body Shell
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.18), Color(white: 0.08)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 180, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                isBothPressed
                                    ? LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                                lineWidth: isBothPressed ? 2.5 : 1.2
                            )
                    )
                    .shadow(color: isBothPressed ? .orange.opacity(0.35) : .black.opacity(0.5), radius: 18)
                    .shadow(
                        color: isBothPressed ? SongletonTheme.cyan.opacity(0.40) : Color.black.opacity(0.5),
                        radius: isBothPressed ? 20 : 10
                    )

                // Left Mouse Button
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isBothPressed
                            ? LinearGradient(colors: [SongletonTheme.cyan, SongletonTheme.violet], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 72, height: 74)
                    .overlay(
                        VStack(spacing: 2) {
                            Text(localization.string("tutorial.mouse.left_short"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white : .white.opacity(0.8))
                            Text(localization.string("tutorial.mouse.click_short"))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white.opacity(0.9) : .white.opacity(0.5))
                        }
                    )
                    .offset(x: -42, y: -55)

                // Right Mouse Button
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isBothPressed
                            ? LinearGradient(colors: [SongletonTheme.cyan, SongletonTheme.violet], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 72, height: 74)
                    .overlay(
                        VStack(spacing: 2) {
                            Text(localization.string("tutorial.mouse.right_short"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white : .white.opacity(0.8))
                            Text(localization.string("tutorial.mouse.click_short"))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white.opacity(0.9) : .white.opacity(0.5))
                        }
                    )
                    .offset(x: 42, y: -55)

                // Scroll Wheel
                Capsule()
                    .fill(isBothPressed ? Color.white : Color(white: 0.4))
                    .frame(width: 10, height: 28)
                    .shadow(color: isBothPressed ? .white : .clear, radius: 4)
                    .offset(y: -55)

                // Drag Vector Arrow Indicator
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(isBothPressed ? SongletonTheme.cyan : .white.opacity(0.6))
                    Text(localization.string("tutorial.mouse.drag_hint"))
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isBothPressed ? SongletonTheme.cyan : .white.opacity(0.6))
                }
                .offset(y: 48)
            }

            HStack(spacing: 8) {
                mouseInstructionStep(number: "1", text: localization.string("tutorial.mouse_step_one"))
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.45))
                mouseInstructionStep(number: "2", text: localization.string("tutorial.mouse_step_two"))
            }

            // Bottom Floating Badge
            Text(isBothPressed
                ? "⚡ " + localization.string("tutorial.mouse.press_both")
                : localization.string("tutorial.mouse.idle_hint"))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    isBothPressed
                        ? LinearGradient(colors: [SongletonTheme.cyan, SongletonTheme.violet], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [SongletonTheme.cyan.opacity(0.3), SongletonTheme.violet.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .shadow(color: isBothPressed ? SongletonTheme.cyan.opacity(0.5) : .clear, radius: 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(isBothPressed ? SongletonTheme.cyan.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1.5))
        .shadow(color: isBothPressed ? SongletonTheme.cyan.opacity(0.3) : .black.opacity(0.5), radius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localization.string("tutorial.volume_mouse_desc"))
    }

    private func mouseInstructionStep(number: String, text: String) -> some View {
        HStack(spacing: 6) {
            Text(number)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .frame(width: 20, height: 20)
                .background(SongletonTheme.cyan, in: Circle())
                .foregroundStyle(.black)
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: Capsule())
    }
}
