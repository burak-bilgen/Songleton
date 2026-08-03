import SwiftUI
import Combine
import AppKit

enum SlideDirection {
    case next     // Next track: new song enters from trailing (right), old song exits to leading (left)
    case previous // Previous track: new song enters from leading (left), old song exits to trailing (right)
}

enum CRTState {
    case off               // Completely hidden
    case turningOn         // Phase 1: Gentle scale-up & fade-in without any flash
    case active            // Fully open & interactive
    case turningOffLine    // Phase 1: Flattens vertically into a center beam
    case turningOffDot     // Phase 2: Zips horizontally into a tiny center dot
    case turningOffFade    // Phase 3: Center dot fades out into AMOLED blackness
}

enum AmbientTheme: String, CaseIterable, Identifiable {
    case vinyl = "Vinyl Record"
    case cassette = "Cassette Tape"
    case glass = "Pure Glass"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .vinyl: return "record.circle"
        case .cassette: return "opticaldisc"
        case .glass: return "square.stack"
        }
    }
}

struct ScreenOffsetModifier: ViewModifier {
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
    }
}

extension AnyTransition {
    static func offScreenSlide(screenWidth: CGFloat, direction: SlideDirection) -> AnyTransition {
        let dist = max(screenWidth, 1400) + 500
        switch direction {
        case .next:
            return .asymmetric(
                insertion: .modifier(
                    active: ScreenOffsetModifier(offset: dist),
                    identity: ScreenOffsetModifier(offset: 0)
                ),
                removal: .modifier(
                    active: ScreenOffsetModifier(offset: -dist),
                    identity: ScreenOffsetModifier(offset: 0)
                )
            )
        case .previous:
            return .asymmetric(
                insertion: .modifier(
                    active: ScreenOffsetModifier(offset: -dist),
                    identity: ScreenOffsetModifier(offset: 0)
                ),
                removal: .modifier(
                    active: ScreenOffsetModifier(offset: dist),
                    identity: ScreenOffsetModifier(offset: 0)
                )
            )
        }
    }
}

struct AmbientView: View {
    @ObservedObject var model = NowPlayingModel.shared
    @ObservedObject var settings = SettingsModel.shared
    @ObservedObject var lyricsModel = LyricsModel.shared
    @ObservedObject private var localization = LocalizationManager.shared
    var onClose: () -> Void

    // Theme Mode State
    @State private var selectedTheme: AmbientTheme = .vinyl

    // Continuous Rotation Angle State (Preserves exact rotation angle when paused!)
    @State private var vinylAngle: Double = 0
    @State private var cassetteSpoolAngle: Double = 0
    @State private var rotationTimerCancellable: AnyCancellable?

    // Auto-Hide Interface State
    @State private var showControls: Bool = true
    @State private var idleWorkItem: DispatchWorkItem?

    // Local Slider State
    @State private var sliderPosition: Double = 0
    @State private var isDraggingPosition: Bool = false
    @State private var localVolume: Double = 50.0
    @State private var isDraggingVolume: Bool = false

    // Live Clock State
    @State private var currentTimeString: String = ""
    @State private var currentDateString: String = ""
    private let clockTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // Direction-Aware Song Transition State
    @State private var slideDirection: SlideDirection = .next

    // Retro CRT TV Turn-On / Turn-Off State
    @State private var crtState: CRTState = .off
    @State private var isClosing: Bool = false

    // Cinematic Opening Entrance Animation State
    @State private var openingScale: CGFloat = 0.82
    @State private var openingOpacity: Double = 0.0
    @State private var openingBlur: CGFloat = 24.0

    // Heartbeat Aura Pulse State
    @State private var auraPulse: Bool = false

    // Synced Lyrics Overlay State
    @State private var showLyrics: Bool = false

    // Sleep Timer State (minutes: 0, 15, 30, 45, 60)
    @State private var sleepTimerMinutes: Int = 0
    @State private var sleepSecondsRemaining: Int = 0

    // High-Contrast Theme Color
    private var themeColor: Color {
        model.dominantColor
    }

    private var isPlaying: Bool {
        if case .loaded(let info, _) = model.state {
            return info.isPlaying
        }
        return false
    }

    private var currentTrackId: String {
        if case .loaded(let info, _) = model.state {
            return "\(info.track)-\(info.artist)"
        }
        return "idle"
    }

    private var currentPlaybackPosition: Double {
        if case .loaded(let info, _) = model.state {
            return info.position
        }
        return 0
    }

    // Gentle Flash-Free Opening Scale & Opacity
    private var crtScaleX: CGFloat {
        switch crtState {
        case .off: return 0.95
        case .turningOn, .active, .turningOffLine: return 1.0
        case .turningOffDot, .turningOffFade: return 0.001
        }
    }

    private var crtScaleY: CGFloat {
        switch crtState {
        case .off: return 0.95
        case .turningOffLine, .turningOffDot, .turningOffFade: return 0.003
        case .turningOn, .active: return 1.0
        }
    }

    private var crtOpacity: Double {
        switch crtState {
        case .off, .turningOffFade: return 0.0
        default: return 1.0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // 1. Pure AMOLED Pitch Black Background
                Color.black

                // 2. Philips Ambilight Dynamic Artwork Aura Glow Layer with Heartbeat Pulse
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 120)
                        .saturation(1.8)
                        .opacity(auraPulse && isPlaying ? 0.80 : 0.60)
                        .scaleEffect(auraPulse && isPlaying ? 1.06 : 1.0)
                        .clipped()
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: auraPulse)
                        .animation(.easeInOut(duration: 1.2), value: model.artwork)
                } else {
                    Circle()
                        .fill(themeColor.opacity(0.3))
                        .frame(width: 600, height: 600)
                        .blur(radius: 130)
                        .scaleEffect(auraPulse && isPlaying ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: auraPulse)
                        .animation(.easeInOut(duration: 1.2), value: themeColor)
                }

                // AMOLED Radial Vignette
                RadialGradient(
                    colors: [.clear, .black.opacity(0.35), .black.opacity(0.92)],
                    center: .center,
                    startRadius: 200,
                    endRadius: 950
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(false)

                // 3. Main Hero View (Shifted right gracefully when Lyrics view is active)
                HStack(spacing: showLyrics ? 44 : 0) {
                    // Left Column: Hero Cover & Fixed Controls
                    VStack(spacing: 20) {
                        // A. Hero Content (Vinyl Disc Stays Fixed, Album Cover & Title Slide Off-Screen Always!)
                        VStack(spacing: 20) {
                            // Theme Display Hero Container
                            themeHeroDisplay(screenWidth: geometry.size.width)
                                .frame(width: showLyrics ? 400 : 580, height: showLyrics ? 320 : 420)
                                .transition(.scale(scale: 0.92).combined(with: .opacity))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTheme)

                            // Track & Artist Meta (ALWAYS slides physical off-screen 100% on track change)
                            if case .loaded(let info, _) = model.state {
                                VStack(spacing: 8) {
                                    Text(info.track)
                                        .font(.system(size: showLyrics ? 22 : 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(4)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if !info.artist.isEmpty {
                                        Text(info.artist)
                                            .font(.system(size: showLyrics ? 15 : 18, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.80))
                                            .multilineTextAlignment(.center)
                                            .minimumScaleFactor(0.75)
                                            .lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: showLyrics ? 380 : 560)
                                .id(currentTrackId)
                                .transition(.offScreenSlide(screenWidth: geometry.size.width, direction: slideDirection))
                                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: currentTrackId)
                            }
                        }
                        .frame(width: showLyrics ? 400 : geometry.size.width, height: showLyrics ? 440 : 540)

                        // B. Fixed Playback Controls Section
                        if case .loaded(let info, _) = model.state {
                            VStack(spacing: 16) {
                                // Progress Bar
                                if info.duration > 0 {
                                    VStack(spacing: 4) {
                                        CustomSliderView(
                                            value: $sliderPosition,
                                            range: 0...max(info.duration, 1),
                                            onEditingChanged: { editing in
                                                isDraggingPosition = editing
                                                if !editing { model.seekTo(sliderPosition) }
                                            },
                                            barColor: themeColor
                                        )
                                        .onAppear { if !isDraggingPosition { sliderPosition = info.position } }
                                        .onChange(of: info.position) { _, v in
                                            if !isDraggingPosition { sliderPosition = v }
                                        }

                                        HStack {
                                            Text(formatTime(isDraggingPosition ? sliderPosition : info.position))
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.6))
                                            Spacer()
                                            Text("-" + formatTime(max(0, info.duration - (isDraggingPosition ? sliderPosition : info.position))))
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                    }
                                    .frame(width: showLyrics ? 360 : 440)
                                }

                                // Playback Buttons Row
                                HStack(spacing: 24) {
                                    Button { model.toggleShuffle() } label: {
                                        Image(systemName: "shuffle")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(info.isShuffleEnabled ? themeColor : .white.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        slideDirection = .previous
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            model.previousTrack()
                                        }
                                    } label: {
                                        Image(systemName: "backward.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .buttonStyle(.plain)

                                    Button { model.togglePlayPause() } label: {
                                        ZStack {
                                            Circle()
                                                .fill(themeColor)
                                                .shadow(color: themeColor.opacity(0.65), radius: 18, x: 0, y: 7)
                                                .frame(width: 64, height: 64)

                                            Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundStyle(.white)
                                                .offset(x: info.isPlaying ? 0 : 2)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        slideDirection = .next
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            model.nextTrack()
                                        }
                                    } label: {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .buttonStyle(.plain)

                                    Button { model.cycleRepeatMode() } label: {
                                        Image(systemName: info.repeatMode == .one ? "repeat.1" : "repeat")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(info.repeatMode != .off ? themeColor : .white.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Volume Row
                                HStack(spacing: 16) {
                                    Image(systemName: "speaker.wave.1.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.65))

                                    CustomSliderView(
                                        value: $localVolume,
                                        range: 0...100,
                                        onEditingChanged: { editing in
                                            isDraggingVolume = editing
                                            if !editing { model.setVolume(Int(localVolume)) }
                                        },
                                        barColor: themeColor
                                    )
                                    .frame(width: 160)

                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                .padding(.top, 2)
                            }
                            .opacity(showControls ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.4), value: showControls)
                            .animation(.easeInOut(duration: 0.8), value: themeColor)
                        }
                    }
                    .frame(maxWidth: showLyrics ? 420 : geometry.size.width)

                    // Right Column: Lyrics View (Shifted right to avoid any overlap)
                    if showLyrics {
                        lyricsOverlayView
                            .frame(width: 520, height: 600)
                            .padding(.trailing, 24)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: showLyrics)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)

                // 4. Top Status Bar (Clock, Theme Switcher, Sleep Timer Dropdown Menu, Lyrics Toggle & Exit)
                VStack {
                    HStack(spacing: 16) {
                        // Desk Clock & Date Display
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentTimeString)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(currentDateString)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        // Theme Mode Switcher Button
                        Button {
                            cycleThemeMode()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: selectedTheme.icon)
                                    .font(.system(size: 13, weight: .bold))
                                Text(selectedTheme.rawValue)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        // Lyrics Toggle Button
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showLyrics.toggle()
                                if showLyrics { triggerLyricsFetch() }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Lyrics")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(showLyrics ? themeColor.opacity(0.4) : Color.white.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(showLyrics ? themeColor : Color.white.opacity(0.20), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        // Sleep Timer Dropdown Menu
                        Menu {
                            Button("Timer Off") { setSleepTimer(0) }
                            Divider()
                            Button("15 Minutes") { setSleepTimer(15) }
                            Button("30 Minutes") { setSleepTimer(30) }
                            Button("45 Minutes") { setSleepTimer(45) }
                            Button("60 Minutes") { setSleepTimer(60) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 12, weight: .bold))
                                if sleepTimerMinutes > 0 {
                                    Text(formatSleepTimerRemaining())
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                } else {
                                    Text("Sleep Timer")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(sleepTimerMinutes > 0 ? themeColor.opacity(0.4) : Color.white.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(sleepTimerMinutes > 0 ? themeColor : Color.white.opacity(0.20), lineWidth: 0.5))
                        }
                        .menuStyle(.borderlessButton)

                        // Exit Ambient Mode Button (Triggers CRT Turn-Off Animation)
                        Button {
                            triggerCRTTurnOffAndClose()
                        } label: {
                            HStack(spacing: 6) {
                                Text("ESC")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                                Text("Exit")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.10), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 28)

                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .opacity(showControls ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.4), value: showControls)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(openingScale * crtScaleX, anchor: .center)
            .opacity(openingOpacity * crtOpacity)
            .blur(radius: openingBlur)
        }
        .ignoresSafeArea()
        .onContinuousHover { _ in
            registerUserActivity()
        }
        .onAppear {
            updateClock()
            registerUserActivity()
            startContinuousRotationTimer()
            auraPulse = true
            if case .loaded(let info, _) = model.state {
                localVolume = Double(info.volume)
            }
            triggerLyricsFetch()
            startCRTTurnOnAnimation()
        }
        .onDisappear {
            stopContinuousRotationTimer()
        }
        .onReceive(clockTimer) { _ in
            updateClock()
            updateSleepTimerCountdown()
        }
        .onChange(of: currentTrackId) { _, _ in
            triggerLyricsFetch()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ambientKeyDown"))) { notif in
            if let userInfo = notif.userInfo,
               let keyCode = userInfo["keyCode"] as? UInt16 {
                let chars = userInfo["chars"] as? String ?? ""
                handleKeyEvent(keyCode: keyCode, chars: chars)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("triggerAmbientCloseAnimation"))) { _ in
            triggerCRTTurnOffAndClose()
        }
    }

    // MARK: - Theme Hero Display Builder

    @ViewBuilder
    private func themeHeroDisplay(screenWidth: CGFloat) -> some View {
        switch selectedTheme {
        case .vinyl:
            vinylHeroView(screenWidth: screenWidth)
        case .cassette:
            cassetteHeroView(screenWidth: screenWidth)
        case .glass:
            glassHeroView(screenWidth: screenWidth)
        }
    }

    // 1. Vinyl Record Theme View (Spinning Vinyl Disc Body STAYS FIXED IN PLACE continuously!)
    private func vinylHeroView(screenWidth: CGFloat) -> some View {
        ZStack {
            // Stationary Rotating Vinyl Record Disc Body (NEVER moves, slides, or resets on track change!)
            vinylDiscBodyView
                .rotationEffect(.degrees(vinylAngle))
                .offset(x: showLyrics ? 65 : 110)

            // Animated Album Cover (ALWAYS slides off-screen 100% on track change)
            artworkCoverView
                .id(currentTrackId)
                .transition(.offScreenSlide(screenWidth: screenWidth, direction: slideDirection))
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: currentTrackId)
        }
    }

    // Rotating Vinyl Disc Body Element (Stationary in place)
    private var vinylDiscBodyView: some View {
        ZStack {
            // Base Dark Vinyl Disc Body
            Circle()
                .fill(Color(white: 0.06))
                .frame(width: 420, height: 420)
                .shadow(color: .black.opacity(0.88), radius: 30, x: 0, y: 16)

            // Realistic Vinyl Track Bands & Grooves
            Circle().stroke(Color(white: 0.15), lineWidth: 1.5).frame(width: 395, height: 395)
            Circle().stroke(Color(white: 0.12), lineWidth: 1.0).frame(width: 360, height: 360)
            Circle().stroke(Color(white: 0.10), lineWidth: 1.0).frame(width: 320, height: 320)
            Circle().stroke(Color(white: 0.09), lineWidth: 1.0).frame(width: 270, height: 270)
            Circle().stroke(Color(white: 0.08), lineWidth: 1.0).frame(width: 220, height: 220)

            // Rotating High-Contrast Light Glare Sheen
            AngularGradient(
                colors: [
                    .clear,
                    .white.opacity(0.26),
                    .clear,
                    .white.opacity(0.20),
                    .clear
                ],
                center: .center
            )
            .clipShape(Circle())
            .frame(width: 410, height: 410)

            // Strobe Speed Dots Ring
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [4, 7]))
                .foregroundStyle(Color(white: 0.28))
                .frame(width: 175, height: 175)

            // Center Label with Artwork Thumbnail
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .id(currentTrackId)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.35), value: currentTrackId)
            } else {
                Circle()
                    .fill(themeColor.opacity(0.45))
                    .frame(width: 140, height: 140)
            }

            // Center Spindle Hole
            Circle()
                .fill(Color.black)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
        }
    }

    // 2. Retro Cassette Tape Theme View
    private func cassetteHeroView(screenWidth: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.16), Color(white: 0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 440, height: 290)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.8), radius: 30, x: 0, y: 16)

            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    if let artwork = model.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .id(currentTrackId)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.35), value: currentTrackId)
                    }
                    if case .loaded(let info, _) = model.state {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.track)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(white: 0.95))
                                .lineLimit(1)
                            Text(info.artist)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.75))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(white: 0.22), in: RoundedRectangle(cornerRadius: 12))
                .frame(width: 380)

                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 260, height: 90)

                    HStack(spacing: 60) {
                        ZStack {
                            Circle().fill(Color(white: 0.85)).frame(width: 52, height: 52)
                            Circle().stroke(Color.black, lineWidth: 3).frame(width: 38, height: 38)
                            Image(systemName: "asterisk")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.black)
                        }
                        .rotationEffect(.degrees(cassetteSpoolAngle))

                        ZStack {
                            Circle().fill(Color(white: 0.85)).frame(width: 52, height: 52)
                            Circle().stroke(Color.black, lineWidth: 3).frame(width: 38, height: 38)
                            Image(systemName: "asterisk")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.black)
                        }
                        .rotationEffect(.degrees(cassetteSpoolAngle))
                    }
                }
            }
        }
    }

    // 3. Pure Glassmorphic Theme View
    private func glassHeroView(screenWidth: CGFloat) -> some View {
        ZStack {
            artworkCoverView
                .scaleEffect(1.08)
                .shadow(color: themeColor.opacity(0.55), radius: 45, x: 0, y: 20)
                .id(currentTrackId)
                .transition(.offScreenSlide(screenWidth: screenWidth, direction: slideDirection))
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: currentTrackId)
        }
    }

    // Base Artwork Cover Element
    private var artworkCoverView: some View {
        ZStack {
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: showLyrics ? 300 : 380, height: showLyrics ? 300 : 380)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.1)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.8), radius: 36, x: -8, y: 16)
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: showLyrics ? 300 : 380, height: showLyrics ? 300 : 380)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 72, weight: .ultraLight))
                            .foregroundStyle(Color.white.opacity(0.3))
                    )
            }
        }
    }

    // MARK: - Dynamic Synced Lyrics Component connected to LyricsModel.shared

    private var lyricsOverlayView: some View {
        let activeIdx = lyricsModel.activeLineIndex(for: currentPlaybackPosition) ?? 0

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(themeColor).frame(width: 8, height: 8)
                    Text("LIVE LYRICS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(themeColor.opacity(0.4), in: Capsule())

                Spacer()

                Button {
                    withAnimation { showLyrics = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            if lyricsModel.isLoading {
                VStack(spacing: 14) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading synced lyrics...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lyricsModel.lines.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white.opacity(0.25))
                    Text("No synced lyrics found")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Instrumental or unlisted track")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(Array(lyricsModel.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == activeIdx
                                HStack(spacing: 12) {
                                    if isActive {
                                        Capsule()
                                            .fill(themeColor)
                                            .frame(width: 4, height: 28)
                                            .shadow(color: themeColor, radius: 8)
                                    }

                                    Text(line.text)
                                        .font(.system(size: isActive ? 24 : 19, weight: isActive ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(isActive ? .white : .white.opacity(0.42))
                                        .blur(radius: isActive ? 0 : 0.3)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
                                }
                                .id(index)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                    .onChange(of: activeIdx) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(28)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 30)
    }

    // MARK: - Key Event Handling

    private func handleKeyEvent(keyCode: UInt16, chars: String) {
        switch keyCode {
        case 49: // Spacebar -> Play / Pause
            model.togglePlayPause()
            registerUserActivity()
        case 124: // Right Arrow -> Next Track
            slideDirection = .next
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                model.nextTrack()
            }
            registerUserActivity()
        case 123: // Left Arrow -> Previous Track
            slideDirection = .previous
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                model.previousTrack()
            }
            registerUserActivity()
        case 126: // Up Arrow -> Volume Up
            model.setVolume(min(100, Int(localVolume) + 10))
            registerUserActivity()
        case 125: // Down Arrow -> Volume Down
            model.setVolume(max(0, Int(localVolume) - 10))
            registerUserActivity()
        case 53: // ESC -> Exit Ambient Mode
            triggerCRTTurnOffAndClose()
        default:
            if chars == "l" {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                    if showLyrics { triggerLyricsFetch() }
                }
                registerUserActivity()
            } else if chars == "t" {
                cycleThemeMode()
                registerUserActivity()
            }
        }
    }

    // MARK: - Helpers, Rotation & Actions

    private func startContinuousRotationTimer() {
        rotationTimerCancellable = Timer.publish(every: 0.03, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if isPlaying {
                    vinylAngle += 0.9
                    cassetteSpoolAngle += 1.2
                    if vinylAngle >= 36000 { vinylAngle = 0 }
                    if cassetteSpoolAngle >= 36000 { cassetteSpoolAngle = 0 }
                }
            }
    }

    private func stopContinuousRotationTimer() {
        rotationTimerCancellable?.cancel()
        rotationTimerCancellable = nil
    }

    private func triggerLyricsFetch() {
        if case .loaded(let info, let source) = model.state {
            lyricsModel.loadLyrics(
                track: info.track,
                artist: info.artist,
                album: info.album,
                duration: info.duration,
                source: source
            )
        }
    }

    private func cycleThemeMode() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            switch selectedTheme {
            case .vinyl: selectedTheme = .cassette
            case .cassette: selectedTheme = .glass
            case .glass: selectedTheme = .vinyl
            }
        }
    }

    private func setSleepTimer(_ minutes: Int) {
        sleepTimerMinutes = minutes
        sleepSecondsRemaining = minutes * 60
    }

    private func updateSleepTimerCountdown() {
        guard sleepTimerMinutes > 0 else { return }
        if sleepSecondsRemaining > 0 {
            sleepSecondsRemaining -= 1
        } else {
            model.togglePlayPause()
            sleepTimerMinutes = 0
            triggerCRTTurnOffAndClose()
        }
    }

    private func formatSleepTimerRemaining() -> String {
        let m = sleepSecondsRemaining / 60
        let s = sleepSecondsRemaining % 60
        return String(format: "%dm %02ds", m, s)
    }

    private func startCRTTurnOnAnimation() {
        openingScale = 0.82
        openingOpacity = 0.0
        openingBlur = 24.0
        crtState = .off

        withAnimation(.spring(response: 0.58, dampingFraction: 0.76)) {
            openingScale = 1.0
            openingOpacity = 1.0
            openingBlur = 0.0
            crtState = .turningOn
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            crtState = .active
        }
    }

    private func triggerCRTTurnOffAndClose() {
        guard !isClosing else { return }
        isClosing = true

        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            crtState = .turningOffLine
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeInOut(duration: 0.18)) {
                crtState = .turningOffDot
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.easeOut(duration: 0.14)) {
                crtState = .turningOffFade
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            onClose()
        }
    }

    private func registerUserActivity() {
        showControls = true
        idleWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) {
                showControls = false
            }
        }
        idleWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: item)
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        currentTimeString = formatter.string(from: Date())

        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        currentDateString = formatter.string(from: Date())
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
