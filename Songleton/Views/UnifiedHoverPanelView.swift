import SwiftUI
import Combine

struct UnifiedHoverPanelView: View {
    @ObservedObject var model = NowPlayingModel.shared
    @ObservedObject var settings = SettingsModel.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.openSettings) private var openSettings

    // Local Volume Slider State
    @State private var localVolume: Double = 50.0
    @State private var isDraggingVolume: Bool = false
    @State private var lastVolumeSetTime: Date = .distantPast
    @State private var volumeSubject = PassthroughSubject<Int, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var hasConfiguredVolume = false

    // Track Position Slider State
    @State private var sliderPosition: Double = 0
    @State private var isDraggingPosition: Bool = false

    // Button Press & Hover Micro-Animation States
    @State private var playButtonScale: CGFloat = 1.0
    @State private var prevButtonScale: CGFloat = 1.0
    @State private var nextButtonScale: CGFloat = 1.0
    @State private var shuffleButtonScale: CGFloat = 1.0
    @State private var repeatButtonScale: CGFloat = 1.0
    @State private var lyricsButtonScale: CGFloat = 1.0
    @State private var ambientButtonScale: CGFloat = 1.0
    @State private var settingsButtonScale: CGFloat = 1.0
    @State private var isMutePressed: Bool = false
    @State private var hoveredButtonID: String? = nil

    // Gentle Artwork Breathing State
    @State private var isArtworkBreathing: Bool = false

    // Accordion Lyrics Expansion State
    @State private var isLyricsExpanded: Bool = false

    // Entrance Animation State
    @State private var appearScale: CGFloat = 0.88
    @State private var appearOpacity: Double = 0.0

    // Dynamic Vibrant HSL Theme Color matching Ambient Mode
    private var themeColor: Color {
        model.dominantColor
    }

    private var modelVolume: Double {
        if case .loaded(let info, _) = model.state {
            return Double(info.volume)
        }
        return 50.0
    }

    private var activeVolume: Double {
        if isDraggingVolume || Date().timeIntervalSince(lastVolumeSetTime) < 2.0 {
            return localVolume
        }
        return modelVolume
    }

    var body: some View {
        ZStack {
            // 1. Pure Jet Black Background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SongletonTheme.panelGradient)

            // 2. Ambient Artwork Aura Glow Layer (Fills 100% of parent panel dynamically with ZERO gaps!)
            GeometryReader { geo in
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 65)
                        .saturation(1.8)
                        .opacity(0.38)
                        .clipped()
                        .id(artwork)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.8), value: model.artwork)
                } else {
                    Circle()
                        .fill(themeColor.opacity(0.25))
                        .frame(width: max(geo.size.width, geo.size.height) * 1.2)
                        .blur(radius: 70)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .animation(.easeInOut(duration: 0.8), value: themeColor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .animation(.easeInOut(duration: 0.8), value: themeColor)

            // 3. Specular Glass Rim Overlay with Dynamic Theme Glow Shadow
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .shadow(color: themeColor.opacity(0.35), radius: 24, x: 0, y: 10)
                .animation(.easeInOut(duration: 0.8), value: themeColor)

            // 4. Panel Content
            VStack(spacing: 12) {
                // Top Section: Volume Slider Row
                volumeRow

                // Center Section: Track Info & Controls
                switch model.state {
                case .loaded(let info, let source):
                    nowPlayingView(info: info, source: source)
                case .notRunning:
                    notRunningView
                case .permissionDenied:
                    permissionDeniedView
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 21)
        }
        .frame(width: 360)
        .fixedSize(horizontal: true, vertical: true)
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onAppear {
            localVolume = modelVolume
            withAnimation(.spring(response: 0.36, dampingFraction: 0.55)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }

            if !hasConfiguredVolume {
                hasConfiguredVolume = true
                volumeSubject
                    .debounce(for: .milliseconds(60), scheduler: DispatchQueue.main)
                    .removeDuplicates()
                    .sink { newVol in
                        NowPlayingModel.shared.setVolume(newVol)
                    }
                    .store(in: &cancellables)
            }
        }
        .onChange(of: modelVolume) { _, newVol in
            if !isDraggingVolume && Date().timeIntervalSince(lastVolumeSetTime) >= 2.0 {
                localVolume = newVol
            }
        }
    }

    // MARK: - Volume Row

    private var volumeRow: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { isMutePressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { isMutePressed = false }
                }
                toggleMute()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        .frame(width: 28, height: 28)

                    Image(systemName: speakerIconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(activeVolume == 0 ? Color.red : Color.white)
                        .symbolEffect(.bounce, value: isMutePressed)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isMutePressed ? 0.82 : (hoveredButtonID == "mute" ? 1.1 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
            .onHover { isHovered in hoveredButtonID = isHovered ? "mute" : nil }

            CustomSliderView(
                value: Binding(
                    get: { activeVolume },
                    set: { newVol in
                        localVolume = newVol
                        isDraggingVolume = true
                        lastVolumeSetTime = Date()
                        volumeSubject.send(Int(newVol))
                    }
                ),
                range: 0...100,
                onEditingChanged: { editing in
                    isDraggingVolume = editing
                    if !editing {
                        lastVolumeSetTime = Date()
                        model.setVolume(Int(localVolume))
                    }
                },
                barColor: themeColor
            )

            // %100 Label Fixed Width (52px)
            Text("\(Int(activeVolume))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                .frame(width: 52, alignment: .trailing)
        }
    }

    // MARK: - Now Playing Section

    private func nowPlayingView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 10) {
            // Artwork (Clean Specular Border with Gentle Breathing Micro-Animation)
            ZStack {
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: isLyricsExpanded ? 84 : 130, height: isLyricsExpanded ? 84 : 130)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.35), .white.opacity(0.1)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: themeColor.opacity(0.40), radius: 14, x: 0, y: 6)
                        .scaleEffect(info.isPlaying && isArtworkBreathing ? 1.025 : 1.0)
                        .animation(
                            info.isPlaying
                                ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                                : .default,
                            value: isArtworkBreathing
                        )
                        .onAppear { isArtworkBreathing = true }
                        .onTapGesture(count: 2) {
                            AmbientModeManager.shared.show()
                        }
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: isLyricsExpanded ? 84 : 130, height: isLyricsExpanded ? 84 : 130)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundStyle(Color.white.opacity(0.4))
                        )
                }
            }

            // Track & Artist Meta
            VStack(spacing: 3) {
                Text(info.track)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                if !info.artist.isEmpty {
                    Text(info.artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            // Progress Bar
            if settings.showProgressBar && info.duration > 0 {
                VStack(spacing: 3) {
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
                    .onChange(of: info.position) { _, v in if !isDraggingPosition { sliderPosition = v } }

                    HStack {
                        Text(formatTime(isDraggingPosition ? sliderPosition : info.position))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("-" + formatTime(max(0, info.duration - (isDraggingPosition ? sliderPosition : info.position))))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            // Minimalist Controls Row with Hover Physics Micro-Animations
            HStack(spacing: 16) {
                // Shuffle Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { shuffleButtonScale = 0.82 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { shuffleButtonScale = 1.0 }
                    }
                    model.toggleShuffle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(info.isShuffleEnabled ? themeColor.opacity(0.25) : Color.white.opacity(0.08))
                            .overlay(Circle().stroke(info.isShuffleEnabled ? themeColor.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 0.5))
                            .frame(width: 32, height: 32)

                        Image(systemName: "shuffle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(info.isShuffleEnabled ? themeColor : Color.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "shuffle" ? 1.1 : shuffleButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "shuffle" : nil }
                .help(localization.string("control.shuffle"))

                // Backward Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { prevButtonScale = 0.82 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { prevButtonScale = 1.0 }
                    }
                    model.previousTrack()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                            .frame(width: 36, height: 36)

                        Image(systemName: "backward.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "prev" ? 1.1 : prevButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "prev" : nil }
                .help(localization.string("menu.previous_track"))

                // Play / Pause Button (The ONLY element with Platform Glow Effect & Bouncy Micro-Animations!)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { playButtonScale = 0.85 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { playButtonScale = 1.0 }
                    }
                    model.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(themeColor)
                            .shadow(color: themeColor.opacity(0.65), radius: 12, x: 0, y: 5)
                            .frame(width: 46, height: 46)

                        Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: info.isPlaying ? 0 : 1.5)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "play" ? 1.12 : playButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "play" : nil }
                .help(info.isPlaying ? localization.string("control.pause") : localization.string("control.play"))

                // Forward Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { nextButtonScale = 0.82 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { nextButtonScale = 1.0 }
                    }
                    model.nextTrack()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                            .frame(width: 36, height: 36)

                        Image(systemName: "forward.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "next" ? 1.1 : nextButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "next" : nil }
                .help(localization.string("menu.next_track"))

                // Repeat Button (3 States: Off, All, One)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { repeatButtonScale = 0.82 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { repeatButtonScale = 1.0 }
                    }
                    model.cycleRepeatMode()
                } label: {
                    let isRepeatActive = info.repeatMode != .off
                    ZStack {
                        Circle()
                            .fill(isRepeatActive ? themeColor.opacity(0.25) : Color.white.opacity(0.08))
                            .overlay(Circle().stroke(isRepeatActive ? themeColor.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 0.5))
                            .frame(width: 32, height: 32)

                        Image(systemName: info.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isRepeatActive ? themeColor : Color.white.opacity(0.6))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "repeat" ? 1.1 : repeatButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "repeat" : nil }
                .help(localization.string("control.repeat"))
            }
            .padding(.top, 2)

            // Expanded Lyrics Section (Accordion Container with Smooth Asymmetric Transition)
            if isLyricsExpanded {
                VStack(spacing: 0) {
                    SyncedLyricsView(nowPlaying: model)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .move(edge: .top))
                ))
            }

            // Clean Footer Row (Bottom-Left Circular Lyrics & Ambient Buttons, Bottom-Right Settings Button)
            HStack(spacing: 10) {
                // Bottom-Left Circular Lyrics Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { lyricsButtonScale = 0.82 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { lyricsButtonScale = 1.0 }
                    }
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.65)) {
                        isLyricsExpanded.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isLyricsExpanded ? themeColor.opacity(0.25) : Color.white.opacity(0.08))
                            .overlay(Circle().stroke(isLyricsExpanded ? themeColor.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 0.5))
                            .frame(width: 32, height: 32)

                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isLyricsExpanded ? themeColor : Color.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "lyrics" ? 1.1 : lyricsButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "lyrics" : nil }
                .help(localization.string("lyrics.title"))

                // Ambient Mode Button (Full Screen)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { ambientButtonScale = 0.82 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { ambientButtonScale = 1.0 }
                    }
                    AmbientModeManager.shared.show()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                            .frame(width: 32, height: 32)

                        Image(systemName: "sparkles.tv.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(themeColor)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "ambient" ? 1.1 : ambientButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "ambient" : nil }
                .help("Ambient Mode ✨")

                Spacer()

                // Bottom-Right Circular Settings Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { settingsButtonScale = 0.82 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { settingsButtonScale = 1.0 }
                    }
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                            .frame(width: 32, height: 32)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredButtonID == "settings" ? 1.1 : settingsButtonScale)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                .onHover { isHovered in hoveredButtonID = isHovered ? "settings" : nil }
                .help(localization.string("settings.title"))
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Not Running

    private var notRunningView: some View {
        VStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.5))
            Text(localization.string("player.not_playing"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(localization.string("player.launch_hint"))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.orange)
            Text(localization.string("permission.required"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private var speakerIconName: String {
        let vol = activeVolume
        if vol == 0 {
            return "speaker.slash.fill"
        } else if vol < 33 {
            return "speaker.wave.1.fill"
        } else if vol < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func toggleMute() {
        lastVolumeSetTime = Date()
        let current = activeVolume
        if current > 0 {
            localVolume = 0
            model.setVolume(0)
        } else {
            localVolume = 50
            model.setVolume(50)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
