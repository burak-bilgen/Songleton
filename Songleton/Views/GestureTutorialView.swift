import SwiftUI
import AppKit

enum TutorialStage: Int, CaseIterable, Identifiable {
    case cancelDemo = 0
    case rightEdgeSkip = 1
    case topEdgePlayPause = 2
    case volumeKeyboard = 3
    case volumeMouse = 4

    var id: Int { rawValue }
}

struct GestureTutorialView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    var onClose: () -> Void

    @State private var currentStage: TutorialStage = .cancelDemo
    @State private var cursorPosition: CGPoint = .zero
    @State private var isBothButtonsPressed = false
    @State private var isKeyboardPressed = false
    @State private var showVolumeHUD = false
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

                            VolumeGestureHUDView(manager: mockManager)
                        }
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - 40)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }

                    // REAL APP EDGE GESTURE OVERLAY COMPONENT (Left / Right / Top)
                    if currentStage != .volumeKeyboard && currentStage != .volumeMouse {
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
                }
                .frame(width: geo.size.width, height: geo.size.height)

                // 3. Top Header and Bottom Control Panel
                VStack {
                    topBarView
                        .padding(.horizontal, 36)
                        .padding(.top, 28)

                    Spacer()

                    stageControlCard(size: geo.size)
                        .padding(.bottom, 36)
                }
            }
            .onAppear {
                cursorPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                runStageAnimation(stage: currentStage, size: geo.size)
            }
            .onDisappear {
                animationTask?.cancel()
            }
        }
    }

    // MARK: - Large Animated Keyboard Cap Overlay

    private var animatedKeyboardOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                keyCapView(symbol: "⌘", label: "Command", isPressed: true)
                keyCapView(symbol: "⌥", label: "Option", isPressed: true)
            }

            Text("⌘ + ⌥ Basılı Tutarak Sürükleyin")
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

    // MARK: - Zone Mapping for Real App Overlay

    private func currentZone(for stage: TutorialStage) -> MouseGestureManager.EdgeZone {
        switch stage {
        case .cancelDemo: return .previous
        case .rightEdgeSkip: return .next
        case .topEdgePlayPause: return .playPause
        case .volumeKeyboard, .volumeMouse: return .next
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
        case .volumeKeyboard, .volumeMouse:
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
        .animation(.spring(response: 0.75, dampingFraction: 0.85), value: cursorPosition)
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
        }
    }

    // MARK: - Stage Control Card Panel

    private func stageControlCard(size: CGSize) -> some View {
        VStack(spacing: 16) {
            // Stage Segment Pills
            HStack(spacing: 6) {
                ForEach(TutorialStage.allCases) { stage in
                    Button {
                        switchStage(to: stage, size: size)
                    } label: {
                        Text(stageTitle(stage))
                            .font(.system(size: 12, weight: currentStage == stage ? .bold : .medium, design: .rounded))
                            .foregroundStyle(currentStage == stage ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Group {
                                    if currentStage == stage {
                                        Capsule()
                                            .fill(SongletonTheme.cyan.opacity(0.35))
                                            .overlay(Capsule().stroke(SongletonTheme.cyan, lineWidth: 1))
                                    } else {
                                        Capsule().fill(Color.white.opacity(0.06))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Description Box
            VStack(spacing: 6) {
                Text(stageHeader(currentStage))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(SongletonTheme.cyan)

                Text(stageDescription(currentStage))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 480)

            // Replay & Action Buttons
            HStack(spacing: 16) {
                Button {
                    runStageAnimation(stage: currentStage, size: size)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text(localization.string("common.try_again"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                if currentStage.rawValue < TutorialStage.allCases.count - 1 {
                    Button {
                        if let next = TutorialStage(rawValue: currentStage.rawValue + 1) {
                            switchStage(to: next, size: size)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(localization.string("common.continue"))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(SongletonTheme.cyan, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onClose()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(localization.string("common.start"))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(SongletonTheme.cyan, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(SongletonTheme.card.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
    }

    // MARK: - Animation Controller & Sound Triggers

    private func switchStage(to stage: TutorialStage, size: CGSize) {
        currentStage = stage
        runStageAnimation(stage: stage, size: size)
    }

    private func runStageAnimation(stage: TutorialStage, size: CGSize) {
        animationTask?.cancel()
        mockManager.simulateEdgeGestureProgress(0)
        isBothButtonsPressed = false
        isKeyboardPressed = false
        showVolumeHUD = false

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        cursorPosition = center

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            switch stage {
            case .cancelDemo:
                // Move cursor to left edge
                withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
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
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    cursorPosition = CGPoint(x: 160, y: size.height / 2)
                    mockManager.simulateEdgeGestureCancelBurst()
                }

            case .rightEdgeSkip:
                // Move cursor to right edge
                withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
                    cursorPosition = CGPoint(x: size.width - 8, y: size.height / 2)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                // Fill progress to 100%
                for p in 0...100 {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateEdgeGestureProgress(CGFloat(p) / 100.0)
                    try? await Task.sleep(for: .milliseconds(8))
                }

                // Trigger Success Burst
                mockManager.simulateEdgeGestureBurst()

            case .topEdgePlayPause:
                // Move cursor to top center
                withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
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

            case .volumeKeyboard:
                // --- STAGE 4: KEYBOARD SHORTCUT (⌘ + ⌥ + DRAG) ---
                withAnimation {
                    isKeyboardPressed = true
                    isBothButtonsPressed = false
                    showVolumeHUD = true
                }
                withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
                    cursorPosition = CGPoint(x: size.width - 240, y: size.height / 2)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                // Drag down to lower volume unhurriedly
                for v in stride(from: 50, through: 20, by: -2) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    cursorPosition.y += 4
                    try? await Task.sleep(for: .milliseconds(24))
                }
                // Drag up to increase volume
                for v in stride(from: 20, through: 80, by: 2) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    cursorPosition.y -= 4
                    try? await Task.sleep(for: .milliseconds(20))
                }

            case .volumeMouse:
                // --- STAGE 5: MOUSE DUAL BUTTONS DRAG ---
                withAnimation {
                    isKeyboardPressed = false
                    isBothButtonsPressed = true
                    showVolumeHUD = true
                }
                withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
                    cursorPosition = CGPoint(x: size.width - 240, y: size.height / 2 - 40)
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }

                for v in stride(from: 80, through: 30, by: -2) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    cursorPosition.y += 4
                    try? await Task.sleep(for: .milliseconds(24))
                }
                for v in stride(from: 30, through: 90, by: 2) {
                    guard !Task.isCancelled else { return }
                    mockManager.simulateGestureVolume(v)
                    cursorPosition.y -= 4
                    try? await Task.sleep(for: .milliseconds(20))
                }
            }
        }
    }

    // MARK: - Helpers & Localized Strings

    private func stageTitle(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: "1. Önceki Şarkı & İptal"
        case .rightEdgeSkip: "2. " + localization.string("menu.next_track")
        case .topEdgePlayPause: "3. Oynat/Durdur"
        case .volumeKeyboard: "4. Ses (Klavye)"
        case .volumeMouse: "5. Ses (Fare)"
        }
    }

    private func stageHeader(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_header")
        case .rightEdgeSkip: localization.string("tutorial.next_header")
        case .topEdgePlayPause: localization.string("tutorial.playpause_header")
        case .volumeKeyboard: localization.string("tutorial.volume_keyboard_header")
        case .volumeMouse: localization.string("tutorial.volume_mouse_header")
        }
    }

    private func stageDescription(_ stage: TutorialStage) -> String {
        switch stage {
        case .cancelDemo: localization.string("tutorial.cancel_desc")
        case .rightEdgeSkip: localization.string("tutorial.next_desc")
        case .topEdgePlayPause: localization.string("tutorial.playpause_desc")
        case .volumeKeyboard: localization.string("tutorial.volume_keyboard_desc")
        case .volumeMouse: localization.string("tutorial.volume_mouse_desc")
        }
    }
}

// MARK: - Large Mouse Diagram View for Dual-Click Volume Tutorial

struct LargeMouseDiagramView: View {
    let isBothPressed: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Mouse Outer Body Shell
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.18), Color(white: 0.08)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 140, height: 170)
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
                    .frame(width: 52, height: 56)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("SOL")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white : .white.opacity(0.8))
                            Text("TIK")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white.opacity(0.9) : .white.opacity(0.5))
                        }
                    )
                    .offset(x: -28, y: -40)

                // Right Mouse Button
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isBothPressed
                            ? LinearGradient(colors: [SongletonTheme.cyan, SongletonTheme.violet], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 52, height: 56)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("SAĞ")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white : .white.opacity(0.8))
                            Text("TIK")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(isBothPressed ? .white.opacity(0.9) : .white.opacity(0.5))
                        }
                    )
                    .offset(x: 28, y: -40)

                // Scroll Wheel
                Capsule()
                    .fill(isBothPressed ? Color.white : Color(white: 0.4))
                    .frame(width: 7, height: 20)
                    .shadow(color: isBothPressed ? .white : .clear, radius: 4)
                    .offset(y: -40)

                // Drag Vector Arrow Indicator
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isBothPressed ? SongletonTheme.cyan : .white.opacity(0.6))
                    Text("FAREYİ DİKEY SÜRÜKLEYİN")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isBothPressed ? SongletonTheme.cyan : .white.opacity(0.6))
                }
                .offset(y: 30)
            }

            // Bottom Floating Badge
            Text(isBothPressed ? "⚡ İKİ TUŞA AYNI ANDA BASIN" : "FARE İLE KONTROL")
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
    }
}
