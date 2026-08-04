import Combine
import SwiftUI

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

    // Button Press & Hover Micro-Animation States
    @State private var playButtonScale: CGFloat = 1.0
    @State private var prevButtonScale: CGFloat = 1.0
    @State private var nextButtonScale: CGFloat = 1.0
    @State private var shuffleButtonScale: CGFloat = 1.0
    @State private var repeatButtonScale: CGFloat = 1.0
    @State private var ambientButtonScale: CGFloat = 1.0
    @State private var settingsButtonScale: CGFloat = 1.0
    @State private var quitButtonScale: CGFloat = 1.0
    @State private var isMutePressed: Bool = false
    @State private var hoveredButtonID: String? = nil
    @State private var hoveredPlaylistID: String? = nil

    // Gentle Artwork Breathing State
    @State private var isArtworkBreathing: Bool = false

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

            // 5. Ambient Mode Button (top-left) + Settings (top-right)
            .overlay(alignment: .topLeading) {
                if case .loaded = model.state {
                    ambientButton
                        .padding(.top, 14)
                        .padding(.leading, 14)
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    settingsButton
                    quitButton
                }
                .padding(.top, 14)
                .padding(.trailing, 14)
            }
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

    // Volume Slider Row (placed directly above the footer buttons)
    private var volumeRow: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { isMutePressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { isMutePressed = false }
                }
                toggleMute()
            } label: {
                controlCircle(
                    icon: speakerIconName,
                    iconSize: 12,
                    circleSize: 28,
                    isActive: activeVolume == 0,
                    accentColor: .red
                )
                .symbolEffect(.bounce, value: isMutePressed)
            }
            .buttonStyle(.plain)
            .scaleEffect(isMutePressed ? 0.82 : (hoveredButtonID == "mute" ? 1.1 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
            .onHover { isHovered in hoveredButtonID = isHovered ? "mute" : nil }
            .accessibilityLabel(activeVolume == 0 ? localization.string("control.unmute") : localization.string("control.mute"))

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

    // Ambient Mode Button: labeled pill, pinned to the top-right corner of the panel
    private var ambientButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { ambientButtonScale = 0.82 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { ambientButtonScale = 1.0 }
            }
            AmbientModeManager.shared.show()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles.tv.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeColor)
                Text(localization.string("ambient.short_label"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule().fill(themeColor.opacity(0.20)))
            .overlay(Capsule().stroke(themeColor.opacity(0.60), lineWidth: 1))
            .shadow(color: themeColor.opacity(0.30), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(hoveredButtonID == "ambient" ? 1.08 : ambientButtonScale)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
        .onHover { isHovered in hoveredButtonID = isHovered ? "ambient" : nil }
        .help(localization.string("ambient.short_label"))
        .accessibilityLabel(localization.string("ambient.short_label"))
    }

    // Quit Button: small power circle, always visible so the app can be fully quit
    private var quitButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { quitButtonScale = 0.82 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { quitButtonScale = 1.0 }
            }
            NSApp.terminate(nil)
        } label: {
            controlCircle(
                icon: "power",
                iconSize: 13,
                circleSize: 32,
                isActive: hoveredButtonID == "quit",
                accentColor: .red
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(hoveredButtonID == "quit" ? 1.1 : quitButtonScale)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
        .onHover { isHovered in hoveredButtonID = isHovered ? "quit" : nil }
        .help(localization.string("menu.quit"))
        .accessibilityLabel(localization.string("menu.quit"))
    }

    // Settings Button: circular gear, pinned to the top-right corner of the panel
    private var settingsButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { settingsButtonScale = 0.82 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { settingsButtonScale = 1.0 }
            }
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            controlCircle(icon: "gearshape.fill", iconSize: 14, circleSize: 32)
        }
        .buttonStyle(.plain)
        .scaleEffect(hoveredButtonID == "settings" ? 1.1 : settingsButtonScale)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
        .onHover { isHovered in hoveredButtonID = isHovered ? "settings" : nil }
        .help(localization.string("settings.title"))
        .accessibilityLabel(localization.string("settings.title"))
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
                        .frame(width: 130, height: 130)
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
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 130, height: 130)
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

            // Controls Row: Playback (dead center)
            HStack(spacing: 10) {
                // Shuffle Button
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { shuffleButtonScale = 0.82 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { shuffleButtonScale = 1.0 }
                        }
                        model.toggleShuffle()
                    } label: {
                        controlCircle(
                            icon: "shuffle",
                            iconSize: 13,
                            circleSize: 32,
                            isActive: info.isShuffleEnabled
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(hoveredButtonID == "shuffle" ? 1.1 : shuffleButtonScale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                    .onHover { isHovered in hoveredButtonID = isHovered ? "shuffle" : nil }
                    .help(localization.string("control.shuffle"))
                    .accessibilityLabel(localization.string("control.shuffle"))

                    // Backward Button
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { prevButtonScale = 0.82 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { prevButtonScale = 1.0 }
                        }
                        model.previousTrack()
                    } label: {
                        controlCircle(icon: "backward.fill", iconSize: 16, circleSize: 36)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(hoveredButtonID == "prev" ? 1.1 : prevButtonScale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                    .onHover { isHovered in hoveredButtonID = isHovered ? "prev" : nil }
                    .help(localization.string("menu.previous_track"))
                    .accessibilityLabel(localization.string("menu.previous_track"))

                    // Play / Pause Button (Hero: filled with theme color + glow)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { playButtonScale = 0.85 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { playButtonScale = 1.0 }
                        }
                        model.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [themeColor.opacity(0.95), themeColor.opacity(0.75)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                                .shadow(color: themeColor.opacity(0.65), radius: 14, x: 0, y: 5)
                                .frame(width: 48, height: 48)

                            Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 19, weight: .bold))
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
                    .accessibilityLabel(info.isPlaying ? localization.string("control.pause") : localization.string("control.play"))

                    // Forward Button
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { nextButtonScale = 0.82 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { nextButtonScale = 1.0 }
                        }
                        model.nextTrack()
                    } label: {
                        controlCircle(icon: "forward.fill", iconSize: 16, circleSize: 36)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(hoveredButtonID == "next" ? 1.1 : nextButtonScale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                    .onHover { isHovered in hoveredButtonID = isHovered ? "next" : nil }
                    .help(localization.string("menu.next_track"))
                    .accessibilityLabel(localization.string("menu.next_track"))

                    // Repeat Button (3 States: Off, All, One)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { repeatButtonScale = 0.82 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { repeatButtonScale = 1.0 }
                        }
                        model.cycleRepeatMode()
                    } label: {
                        controlCircle(
                            icon: info.repeatMode == .one ? "repeat.1" : "repeat",
                            iconSize: 13,
                            circleSize: 32,
                            isActive: info.repeatMode != .off
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(hoveredButtonID == "repeat" ? 1.1 : repeatButtonScale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredButtonID)
                    .onHover { isHovered in hoveredButtonID = isHovered ? "repeat" : nil }
                    .help(localization.string("control.repeat"))
                    .accessibilityLabel(localization.string("control.repeat"))
            }
            .padding(.top, 2)

            // Volume Slider Row
            volumeRow
                .padding(.top, 2)

            if source.lowercased().contains("spotify") {
                spotifyDiscoverySection
            }
        }
    }

    private var spotifyDiscoverySection: some View {
        let playlists = SpotifyDiscoveryCatalog.playlists()
        let marketName = SpotifyDiscoveryCatalog.marketName(for: Locale.autoupdatingCurrent)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 29 / 255, green: 185 / 255, blue: 84 / 255))

                Text(localization.string("spotify.discovery_title"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))

                Spacer()

                Text(marketName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Text(localization.string("spotify.discovery_hint"))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))

            ForEach(playlists) { playlist in
                spotifyPlaylistRow(playlist)
            }
        }
        .padding(.top, 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localization.string("spotify.discovery_title"))
    }

    private func spotifyPlaylistRow(_ playlist: SpotifyDiscoveryPlaylist) -> some View {
        let accent = playlistAccent(for: playlist)

        return Button {
            model.playSpotifyPlaylist(playlist)
        } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), accent.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: accent.opacity(0.28), radius: 5, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text(playlist.subtitle)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "shuffle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hoveredPlaylistID == playlist.id ? .black : accent)
                    .frame(width: 27, height: 27)
                    .background(
                        hoveredPlaylistID == playlist.id ? accent : accent.opacity(0.13),
                        in: Circle()
                    )
            }
            .padding(.horizontal, 7)
            .frame(height: 43)
            .background(
                hoveredPlaylistID == playlist.id ? Color.white.opacity(0.11) : Color.white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(hoveredPlaylistID == playlist.id ? accent.opacity(0.55) : .white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredPlaylistID = isHovered ? playlist.id : nil
        }
        .help(localization.string("spotify.discovery_play_hint"))
        .accessibilityLabel(playlist.title)
        .accessibilityHint(localization.string("spotify.discovery_play_hint"))
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

    // Unified circular control button look: gradient glass fill, rim, soft shadow,
    // and a clear accent highlight whenever the control is active.
    private func controlCircle(
        icon: String,
        iconSize: CGFloat,
        circleSize: CGFloat,
        isActive: Bool = false,
        accentColor: Color? = nil
    ) -> some View {
        let accent = accentColor ?? themeColor
        return ZStack {
            Group {
                if isActive {
                    Circle().fill(accent.opacity(0.30))
                } else {
                    Circle().fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
            }
            .overlay(
                Circle().stroke(
                    isActive ? accent.opacity(0.70) : Color.white.opacity(0.18),
                    lineWidth: 1
                )
            )
            .frame(width: circleSize, height: circleSize)
            .shadow(
                color: isActive ? accent.opacity(0.35) : .black.opacity(0.25),
                radius: 6, x: 0, y: 2
            )

            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(isActive ? accent : .white.opacity(0.85))
        }
    }

    private func playlistAccent(for playlist: SpotifyDiscoveryPlaylist) -> Color {
        switch playlist.accentIndex {
        case 0: Color(red: 29 / 255, green: 185 / 255, blue: 84 / 255)
        case 1: SongletonTheme.cyan
        case 2: SongletonTheme.violet
        case 3: SongletonTheme.pink
        default: Color(red: 0.96, green: 0.68, blue: 0.23)
        }
    }

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
}
