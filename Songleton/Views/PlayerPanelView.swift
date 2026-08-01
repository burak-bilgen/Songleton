import AppKit
import SwiftUI

// MARK: - PlayerPanelView

struct PlayerPanelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.openSettings) private var openSettings

    @State private var selectedTab = 0 // 0: Now Playing, 1: Lyrics, 2: Spotify Playlists, 3: History
    @State private var sliderVolume: Double = 50
    @State private var isDraggingVolume = false
    @State private var sliderPosition: Double = 0
    @State private var isDraggingPosition = false
    @State private var showCopiedToast = false
    @State private var toastText = ""

    private var isCompact: Bool { settings.panelStyle == .compact }
    private var panelWidth: CGFloat { 350 }

    var body: some View {
        ZStack {
            // Dynamic ambient background layer
            backgroundView

            VStack(spacing: 0) {
                // Pinned Stationary Top Segmented Tab Picker
                topTabBar
                    .padding(.top, 10)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)

                Divider()

                // Content View Container
                ZStack {
                    switch selectedTab {
                    case 0:
                        // Now Playing Tab
                        switch model.state {
                        case .loaded(let info, let source):
                            loadedView(info: info, source: source)
                        case .notRunning:
                            notRunningView
                        case .permissionDenied:
                            permissionDeniedView
                        }
                    case 1:
                        // Synced Karaoke Lyrics Tab
                        SyncedLyricsView(nowPlaying: model)
                    case 2:
                        // Spotify Playlists Tab
                        SpotifyPlaylistsView()
                    case 3:
                        // History Tab
                        recentTracksSheet
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }

            // Toast Notification Overlay
            if showCopiedToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 12)
            }
        }
        .frame(width: panelWidth)
        .focusable()
        .onKeyPress(.space) {
            model.togglePlayPause()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            model.previousTrack()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.nextTrack()
            return .handled
        }
    }

    // MARK: - Pinned Stationary Top Tab Bar

    private var topTabBar: some View {
        HStack(spacing: 4) {
            tabButton(title: NSLocalizedString("Oynatıcı", comment: "Now Playing Tab"), icon: "music.note", index: 0)
            tabButton(title: NSLocalizedString("Sözler", comment: "Lyrics Tab"), icon: "quote.bubble.fill", index: 1)
            tabButton(title: NSLocalizedString("Playlistler", comment: "Playlists Tab"), icon: "music.note.list", index: 2)
            tabButton(title: NSLocalizedString("Geçmiş", comment: "History Tab"), icon: "clock", index: 3)
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: selectedTab == index ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selectedTab == index ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    if selectedTab == index {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Backgrounds

    private var backgroundView: some View {
        ZStack {
            if settings.useDynamicColor, case .loaded = model.state {
                model.dominantColor
                    .opacity(0.24)
                    .blur(radius: 28)
                    .animation(.easeInOut(duration: 0.8), value: model.dominantColor.description)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Toast View

    private var toastView: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(toastText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            Spacer()
        }
    }

    private func triggerToast(_ text: String) {
        toastText = text
        withAnimation(.spring(duration: 0.3)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedToast = false
            }
        }
    }

    // MARK: - Loaded State

    @ViewBuilder
    private func loadedView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 0) {
            if !isCompact {
                // Album artwork with glow
                artworkView
                    .id(info.track)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .scale(scale: 1.05).combined(with: .opacity)
                    ))
                    .padding(.top, 18)
                    .padding(.horizontal, 16)

                // Track info
                trackInfoView(info: info, source: source)
                    .id(info.track + info.artist)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                // Progress bar
                if settings.showProgressBar && info.duration > 0 {
                    progressView(info: info)
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                }

                // Controls
                controlsView(info: info)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                // Volume
                volumeView(info: info)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
            } else {
                // Compact mode
                compactLoadedView(info: info, source: source)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            dividerAndFooter
        }
    }

    // MARK: - Artwork View

    private var artworkView: some View {
        ZStack {
            // Ambient glowing shadow
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .opacity(0.45)
                    .offset(y: 8)
            }

            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onTapGesture { activateActivePlayer() }
        .help(NSLocalizedString("Çalan uygulamayı ön plana getirmek için tıklayın", comment: "Bring app to front"))
    }

    // MARK: - Track Info View

    private func trackInfoView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(info.track)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let copied = model.copyTrackInfo() {
                    triggerToast("\(NSLocalizedString("Kopyalandı", comment: "Copied")): \(copied)")
                }
            }
            .help(NSLocalizedString("Tıklayarak şarkı ve sanatçı adını kopyalayın", comment: "Copy track info"))

            Text(info.artist)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !info.album.isEmpty {
                Text(info.album)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Image(systemName: source == "Spotify" ? "music.note.list" : "music.note")
                    .font(.system(size: 9, weight: .semibold))
                Text(source)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.primary.opacity(0.06), in: Capsule())
            .padding(.top, 2)
        }
    }

    // MARK: - Progress View

    private func progressView(info: NowPlayingInfo) -> some View {
        VStack(spacing: 4) {
            CustomSliderView(
                value: $sliderPosition,
                range: 0...max(info.duration, 1),
                onEditingChanged: { editing in
                    isDraggingPosition = editing
                    if !editing { model.seekTo(sliderPosition) }
                },
                barColor: .primary
            )
            .onAppear { if !isDraggingPosition { sliderPosition = info.position } }
            .onChange(of: info.position) { _, v in if !isDraggingPosition { sliderPosition = v } }

            HStack {
                Text(formatTime(isDraggingPosition ? sliderPosition : info.position))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(formatTime(info.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Controls View

    private func controlsView(info: NowPlayingInfo) -> some View {
        HStack(spacing: 36) {
            Spacer(minLength: 0)

            // 1. Önceki Şarkı (Previous Track)
            Button(action: { model.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Önceki şarkı", comment: "Previous track"))

            // 2. Canlı Oynat / Durdur Butonu (Play / Pause Button)
            Button(action: { model.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.75)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                        .frame(width: 50, height: 50)

                    Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .help(info.isPlaying ? NSLocalizedString("Duraklat", comment: "Pause") : NSLocalizedString("Oynat", comment: "Play"))

            // 3. Sonraki Şarkı (Next Track)
            Button(action: { model.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Sonraki şarkı", comment: "Next track"))

            Spacer(minLength: 0)
        }
    }

    // MARK: - Volume View

    private func volumeView(info: NowPlayingInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: sliderVolume < 1 ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            CustomSliderView(
                value: $sliderVolume,
                range: 0...100,
                onEditingChanged: { editing in
                    isDraggingVolume = editing
                    if !editing { model.setVolume(Int(sliderVolume)) }
                },
                barColor: .primary
            )

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
        }
        .onAppear { sliderVolume = Double(info.volume) }
        .onChange(of: info.volume) { _, v in if !isDraggingVolume { sliderVolume = Double(v) } }
    }

    // MARK: - Compact Loaded View

    private func compactLoadedView(info: NowPlayingInfo, source: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.2)
                    Image(systemName: "music.note")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture { activateActivePlayer() }

            VStack(alignment: .leading, spacing: 2) {
                Text(info.track)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(info.artist)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 12) {
                controlButton("backward.fill", size: 16) { model.previousTrack() }
                controlButton(info.isPlaying ? "pause.fill" : "play.fill", size: 18) { model.togglePlayPause() }
                controlButton("forward.fill", size: 16) { model.nextTrack() }
            }
        }
    }

    // MARK: - Recent Tracks Sheet

    private var recentTracksSheet: some View {
        VStack(spacing: 10) {
            HStack {
                Label(NSLocalizedString("Son Çalınanlar", comment: "Recent Tracks"), systemImage: "clock.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if model.recentTracks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text(NSLocalizedString("Henüz geçmiş yok", comment: "No history yet"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 280)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.recentTracks) { item in
                            recentTrackRow(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private func recentTrackRow(item: RecentTrack) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.source == "Spotify" ? "music.note.list" : "music.note")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.primary.opacity(0.06), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(item.track)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(item.artist)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                let text = "\(item.track) - \(item.artist)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                triggerToast(NSLocalizedString("Kopyalandı", comment: "Copied"))
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Kopyala", comment: "Copy"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Not Running State

    private var notRunningView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 12)
            ZStack {
                Circle()
                    .fill(.secondary.opacity(0.1))
                    .frame(width: 68, height: 68)
                Image(systemName: "headphones")
                    .font(.system(size: 30, weight: .thin))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                Text(NSLocalizedString("Müzik çalmıyor", comment: "Not playing"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(NSLocalizedString("Spotify veya Apple Music'i başlatın", comment: "Launch Spotify or Music"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                playerLaunchButton(
                    label: "Spotify",
                    icon: "music.note.list",
                    bundleID: "com.spotify.client"
                )
                playerLaunchButton(
                    label: "Music",
                    icon: "music.note",
                    bundleID: "com.apple.Music"
                )
            }
            dividerAndFooter
        }
        .padding(.horizontal, 20)
    }

    private func playerLaunchButton(label: String, icon: String, bundleID: String) -> some View {
        Button(action: { openPlayer(bundleID: bundleID) }) {
            Label(label, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Permission Denied State

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 12)
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: "lock.shield")
                    .font(.system(size: 30, weight: .thin))
                    .foregroundStyle(.orange)
            }
            VStack(spacing: 6) {
                Text(NSLocalizedString("İzin Gerekli", comment: "Permission Required"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(NSLocalizedString("Songleton, Spotify veya Apple Music'e erişmek için Otomasyon izni istiyor.", comment: "Automation permission explanation"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Button(action: { openAutomationSettings() }) {
                    HStack {
                        Image(systemName: "gear")
                        Text(NSLocalizedString("Gizlilik Ayarlarını Aç", comment: "Open Privacy Settings"))
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Button(action: {
                    model.requestPermissionByScript()
                }) {
                    Text(NSLocalizedString("Tekrar Dene", comment: "Try Again"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            dividerAndFooter
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Footer

    private var dividerAndFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 8)
            HStack(spacing: 0) {
                Button(NSLocalizedString("Ayarlar…", comment: "Settings")) {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.leading, 16)

                Spacer()

                Button(NSLocalizedString("Çıkış", comment: "Quit")) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.trailing, 16)
            }
            .frame(height: 34)
        }
    }

    // MARK: - Helpers

    private func controlButton(_ systemName: String, size: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func activateActivePlayer() {
        guard let bundleID = model.activeBundleID else { return }
        openPlayer(bundleID: bundleID)
    }

    private func openPlayer(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private func openAutomationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ]
        for urlString in urls {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - CustomSliderView

struct CustomSliderView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    var barColor: Color = .primary

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 1)
            let safeRangeLength = max(range.upperBound - range.lowerBound, 0.001)
            let percent = max(0, min(1, (value - range.lowerBound) / safeRangeLength))
            let activeWidth = totalWidth * CGFloat(percent)

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 4)

                // Active Progress Track
                Capsule()
                    .fill(barColor.opacity(0.85))
                    .frame(width: max(4, activeWidth), height: 4)

                // Monochrome White Thumb Handle (Zero blue system tint!)
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, min(totalWidth - 10, activeWidth - 5)))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let newPercent = max(0, min(1, gesture.location.x / totalWidth))
                        value = range.lowerBound + Double(newPercent) * safeRangeLength
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 14)
    }
}
