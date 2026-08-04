import SwiftUI
import AppKit

enum TutorialStage: Int, CaseIterable, Identifiable {
    case cancelDemo = 0
    case rightEdgeSkip = 1
    case topEdgePlayPause = 2
    case volumeKeyboard = 3
    case volumeMouse = 4
    case hoverMenu = 5
    case ambientMode = 6

    var id: Int { rawValue }
}

struct GestureTutorialView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onClose: () -> Void

    @State private var currentStage: TutorialStage = .cancelDemo
    @State private var cursorPosition: CGPoint = .zero
    @State private var isBothButtonsPressed = false
    @State private var isKeyboardPressed = false
    @State private var showVolumeHUD = false
    @State private var isStageAnimationRunning = true
    @State private var isPlaybackPaused = false
    @State private var isPlaybackResuming = false
    @State private var isDummyMenuHovered = false
    @State private var isDummyRightClicking = false
    @State private var showDummyAmbient = false
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
                    // Hotspot Screen Edge Guides
                    edgeHotspotIndicators(size: geo.size)

                    // Real App Volume HUD View & Control Visuals (CENTERED TOGETHER IN SCREEN MIDDLE)
                    if currentStage == .volumeKeyboard || currentStage == .volumeMouse {
                        HStack(spacing: 36) {
                            if currentStage == .volumeKeyboard {
                                animatedKeyboardOverlay
                            } else {
                                LargeMouseDiagramView(isBothPressed: isBothButtonsPressed)
                            }

                            VolumeGestureHUDView(manager: mockManager, visualMaximum: 20)
                        }
                        .position(
                            x: geo.size.width / 2,
                            y: geo.size.height / 2 - 190
                        )
                        .zIndex(20)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }

                    if currentStage == .hoverMenu || currentStage == .ambientMode {
                        dummyMenuBarView
                            .position(x: geo.size.width / 2, y: 54)
                            .zIndex(25)
                    }

                    if showDummyAmbient {
                        dummyAmbientView
                            .position(x: geo.size.width / 2, y: geo.size.height / 2 - 70)
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

                    // Animated Vector Mouse Cursor (Visible in edge stages and volumeKeyboard)
                    if currentStage != .volumeMouse {
                        animatedMouseCursor(size: geo.size)
                    }

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

                // 3. Header and centered control panel
                VStack {
                    topBarView
                        .padding(.horizontal, 36)
                        .padding(.top, 28)

                    Spacer()

                    stageControlCard(size: geo.size)
                        .offset(y: currentStage.rawValue >= TutorialStage.volumeKeyboard.rawValue
                            ? geo.size.height * 0.15
                            : 0)
                        .zIndex(10)

                    Spacer()
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

    // MARK: - Large Animated Keyboard Cap Overlay

    private var animatedKeyboardOverlay: some View {
        VStack(spacing: 14) {
            Text(localization.string("tutorial.volume_keyboard_header"))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                keyCapView(symbol: "⌘", label: "Command", isPressed: true)
                Text("+")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(SongletonTheme.cyan)
                keyCapView(symbol: "⌥", label: "Option", isPressed: true)
            }

            HStack(spacing: 8) {
                instructionStep(number: "1", text: localization.string("tutorial.keyboard_step_one"))
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.45))
                instructionStep(number: "2", text: localization.string("tutorial.keyboard_step_two"))
            }

            Text(localization.string("tutorial.keyboard_drag_hint"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(SongletonTheme.cyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(SongletonTheme.cyan.opacity(0.6), lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SongletonTheme.cyan.opacity(0.60), lineWidth: 1.5))
        .shadow(color: SongletonTheme.cyan.opacity(0.40), radius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localization.string("tutorial.volume_keyboard_desc"))
    }

    private func keyCapView(symbol: String, label: String, isPressed: Bool) -> some View {
        VStack(spacing: 3) {
            Text(symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(isPressed ? SongletonTheme.cyan : .white)

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isPressed ? .white : .white.opacity(0.6))
        }
        .frame(width: 82, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isPressed ? SongletonTheme.cyan.opacity(0.35) : Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isPressed ? SongletonTheme.cyan : Color.white.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: isPressed ? SongletonTheme.cyan.opacity(0.5) : .clear, radius: 12)
    }

    private func instructionStep(number: String, text: String) -> some View {
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

    private var dummyMenuBarView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SongletonTheme.cyan)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Midnight Drive")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text("Neon Coast")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Image(systemName: "backward.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SongletonTheme.cyan)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.black.opacity(0.86), in: Capsule())
            .overlay(Capsule().stroke(isDummyRightClicking ? SongletonTheme.pink : SongletonTheme.cyan.opacity(0.6), lineWidth: 1.5))

            HStack(spacing: 18) {
                Label(localization.string("tutorial.next_track_hint"), systemImage: "forward.fill")
                Label(localization.string("tutorial.track_click_hint"), systemImage: "playpause.fill")
                Label(localization.string("tutorial.previous_track_hint"), systemImage: "backward.fill")
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.top, 9)

            if isDummyMenuHovered && !showDummyAmbient {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Midnight Drive")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("Neon Coast  •  Tutorial preview")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Divider().overlay(Color.white.opacity(0.12))
                    HStack(spacing: 14) {
                        Image(systemName: "backward.fill")
                        Image(systemName: "play.fill")
                        Image(systemName: "forward.fill")
                        Image(systemName: "waveform")
                    }
                    .foregroundStyle(SongletonTheme.cyan)
                }
                .padding(14)
                .frame(width: 220, alignment: .leading)
                .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(SongletonTheme.cyan.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isDummyMenuHovered)
        .animation(.easeInOut(duration: 0.3), value: isDummyRightClicking)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localization.string("tutorial.hover_dummy_accessibility"))
    }

    private var dummyAmbientView: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [SongletonTheme.violet, SongletonTheme.cyan.opacity(0.8), .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 190, height: 190)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 42, weight: .bold))
                            Text("AMBIENT")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    )
                    .shadow(color: SongletonTheme.violet.opacity(0.45), radius: 28)
            }

            VStack(spacing: 4) {
                Text("Midnight Drive")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Neon Coast")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                Text("City lights blur into the night...")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(SongletonTheme.cyan)
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(width: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(SongletonTheme.cyan.opacity(0.45), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.6), radius: 32, y: 16)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localization.string("tutorial.ambient_dummy_accessibility"))
    }

    // MARK: - Zone Mapping for Real App Overlay

    private func currentZone(for stage: TutorialStage) -> MouseGestureManager.EdgeZone {
        switch stage {
        case .cancelDemo: return .previous
        case .rightEdgeSkip: return .next
        case .topEdgePlayPause: return .playPause
        case .volumeKeyboard, .volumeMouse, .hoverMenu, .ambientMode: return .next
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
        case .volumeKeyboard, .volumeMouse, .hoverMenu, .ambientMode:
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
        ZStack(alignment: .topLeading) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    isBothButtonsPressed
                        ? LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.white, Color(white: 0.88)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black.opacity(0.7), radius: 8, x: 2, y: 4)

            if isBothButtonsPressed {
                HStack(spacing: 3) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Circle().fill(.yellow).frame(width: 8, height: 8)
                }
                .offset(x: 20, y: -4)
                .shadow(color: .orange.opacity(0.6), radius: 6)
            }
        }
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
                onClose()
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
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                Button {
                    if let previous = TutorialStage(rawValue: currentStage.rawValue - 1) {
                        switchStage(to: previous, size: size)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isStageAnimationRunning || currentStage == .cancelDemo)
                .opacity(currentStage == .cancelDemo ? 0.3 : 1)
                .accessibilityLabel(localization.string("tutorial.previous_step"))

                VStack(spacing: 8) {
                    Text("\(localization.string("tutorial.step_label")) \(currentStage.rawValue + 1) / \(TutorialStage.allCases.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(SongletonTheme.cyan)

                    Text(String(stageTitle(currentStage).dropFirst(3)))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    ProgressView(value: Double(currentStage.rawValue + 1), total: Double(TutorialStage.allCases.count))
                        .tint(SongletonTheme.cyan)
                        .frame(maxWidth: 260)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if let next = TutorialStage(rawValue: currentStage.rawValue + 1) {
                        switchStage(to: next, size: size)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isStageAnimationRunning || currentStage == .volumeMouse)
                .opacity(currentStage == .volumeMouse ? 0.3 : 1)
                .accessibilityLabel(localization.string("tutorial.next_step"))
            }

            VStack(spacing: 6) {
                Text(stageHeader(currentStage))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(SongletonTheme.cyan)

                Text(stageDescription(currentStage))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 560)
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                Image(systemName: isStageAnimationRunning ? "play.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(SongletonTheme.cyan)
                Text(isStageAnimationRunning
                    ? localization.string("tutorial.demo_running")
                    : localization.string("tutorial.continue_hint"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)

            HStack(spacing: 14) {
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
                    .frame(minWidth: 160, minHeight: 48)
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
                        .frame(minWidth: 190, minHeight: 48)
                        .background(SongletonTheme.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStageAnimationRunning)
                    .accessibilityLabel(localization.string("common.continue"))
                } else {
                    Button {
                        onClose()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(localization.string("common.start"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(minWidth: 190, minHeight: 48)
                        .background(SongletonTheme.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStageAnimationRunning)
                    .accessibilityLabel(localization.string("common.start"))
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .frame(maxWidth: 680)
        .background(SongletonTheme.card.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
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
        case .topEdgePlayPause, .volumeKeyboard, .volumeMouse, .hoverMenu, .ambientMode:
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
        isDummyMenuHovered = false
        isDummyRightClicking = false
        showDummyAmbient = false
        mockManager.simulateEdgeGestureProgress(0)
        isBothButtonsPressed = false
        isKeyboardPressed = false
        showVolumeHUD = false
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

                // Start the crossfade as soon as the cursor reaches the edge.
                // The gesture is still visibly completing while the next track enters.
                TutorialAudioService.shared.switchToSecondTrack()

                // Fill progress to 100%
                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
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
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }

                TutorialAudioService.shared.resume(fadeIn: true)
                isPlaybackPaused = false
                mockManager.simulateEdgeGestureProgress(0)
                mockManager.simulateEdgeGestureBurst()
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                isPlaybackResuming = false
                isStageAnimationRunning = false

            case .volumeKeyboard:
                // --- STAGE 4: KEYBOARD SHORTCUT (⌘ + ⌥ + DRAG) ---
                withAnimation {
                    isKeyboardPressed = true
                    isBothButtonsPressed = false
                    showVolumeHUD = true
                }
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.75)) {
                    cursorPosition = CGPoint(x: size.width - 240, y: size.height / 2)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                // Fade all the way down, pause briefly at silence, then restore gently.
                for v in stride(from: 8, through: 0, by: -1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y += 4
                    try? await Task.sleep(for: .milliseconds(24))
                }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                for v in stride(from: 0, through: 20, by: 1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y -= 4
                    try? await Task.sleep(for: .milliseconds(20))
                }
                for v in stride(from: 20, through: 8, by: -1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y += 3
                    try? await Task.sleep(for: .milliseconds(20))
                }
                isStageAnimationRunning = false

            case .volumeMouse:
                // --- STAGE 5: MOUSE DUAL BUTTONS DRAG ---
                withAnimation {
                    isKeyboardPressed = false
                    isBothButtonsPressed = true
                    showVolumeHUD = true
                }
                withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.75)) {
                    cursorPosition = CGPoint(x: size.width - 240, y: size.height / 2 - 40)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                for v in stride(from: 8, through: 0, by: -1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y += 4
                    try? await Task.sleep(for: .milliseconds(24))
                }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                for v in stride(from: 0, through: 20, by: 1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y -= 4
                    try? await Task.sleep(for: .milliseconds(20))
                }
                for v in stride(from: 20, through: 8, by: -1) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    TutorialAudioService.shared.setDemoVolume(v)
                    cursorPosition.y += 3
                    try? await Task.sleep(for: .milliseconds(20))
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
                    isDummyMenuHovered = true
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
                isDummyMenuHovered = true
                withAnimation(.easeInOut(duration: 0.25)) {
                    isDummyRightClicking = true
                }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) {
                    showDummyAmbient = true
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
        case .volumeKeyboard: "4. " + localization.string("tutorial.stage_keyboard_volume")
        case .volumeMouse: "5. " + localization.string("tutorial.stage_mouse_volume")
        case .hoverMenu: "6. " + localization.string("tutorial.stage_hover_menu")
        case .ambientMode: "7. " + localization.string("tutorial.stage_ambient_mode")
        }
    }

    private func stageHeader(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_header")
        case .rightEdgeSkip: localization.string("tutorial.next_header")
        case .topEdgePlayPause: localization.string("tutorial.playpause_header")
        case .volumeKeyboard: localization.string("tutorial.volume_keyboard_header")
        case .volumeMouse: localization.string("tutorial.volume_mouse_header")
        case .hoverMenu: localization.string("tutorial.hover_menu_header")
        case .ambientMode: localization.string("tutorial.ambient_mode_header")
        }
    }

    private func stageDescription(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_desc")
        case .rightEdgeSkip: localization.string("tutorial.next_desc")
        case .topEdgePlayPause: localization.string("tutorial.playpause_desc")
        case .volumeKeyboard: localization.string("tutorial.volume_keyboard_desc")
        case .volumeMouse: localization.string("tutorial.volume_mouse_desc")
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
