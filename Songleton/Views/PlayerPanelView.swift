import AppKit
import SwiftUI

struct PlayerPanelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.openSettings) private var openSettings

    @State private var selectedTab = 0
    @State private var sliderPosition: Double = 0
    @State private var isDraggingPosition = false
    @State private var showCopiedToast = false
    @State private var toastText = ""

    private var isCompact: Bool { settings.panelStyle == .compact }
    private let panelWidth: CGFloat = 350

    var body: some View {
        ZStack(alignment: .top) {
            backgroundView

            VStack(spacing: 0) {
                topTabBar
                    .padding(.top, 10)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)

                Divider()

                ZStack {
                    switch selectedTab {
                    case 0:
                        switch model.state {
                        case .loaded(let info, let source):
                            loadedView(info: info, source: source)
                        case .notRunning:
                            notRunningView
                        case .permissionDenied:
                            permissionDeniedView
                        }
                    case 1:
                        SyncedLyricsView(nowPlaying: model)
                    case 2:
                        SpotifyPlaylistsView()
                    case 3:
                        recentTracksView
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }

            if showCopiedToast {
                toastBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50)
                    .zIndex(1)
            }
        }
        .frame(width: panelWidth)
        .focusable()
        .onKeyPress(.space) { model.togglePlayPause(); return .handled }
        .onKeyPress(.leftArrow) { model.previousTrack(); return .handled }
        .onKeyPress(.rightArrow) { model.nextTrack(); return .handled }
    }

    // MARK: - Tab Bar

    private var topTabBar: some View {
        HStack(spacing: 3) {
            tabButton(icon: "music.note", label: NSLocalizedString("Oynatıcı", comment: "Now Playing Tab"), index: 0)
            tabButton(icon: "quote.bubble.fill", label: NSLocalizedString("Sözler", comment: "Lyrics Tab"), index: 1)
            tabButton(icon: "music.note.list", label: NSLocalizedString("Listeler", comment: "Playlists Tab"), index: 2)
            tabButton(icon: "clock", label: NSLocalizedString("Geçmiş", comment: "History Tab"), index: 3)
        }
        .padding(3)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tabButton(icon: String, label: String, index: Int) -> some View {
        let active = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedTab = index }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: active ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(active ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                Group {
                    if active {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            if settings.useDynamicColor, case .loaded = model.state {
                model.dominantColor
                    .opacity(0.18)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 1.0), value: model.dominantColor.description)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Toast

    private var toastBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(toastText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    private func triggerToast(_ text: String) {
        toastText = text
        withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.3)) { showCopiedToast = false }
        }
    }

    // MARK: - Loaded (Full)

    @ViewBuilder
    private func loadedView(info: NowPlayingInfo, source: String) -> some View {
        if isCompact {
            compactView(info: info)
        } else {
            fullView(info: info, source: source)
        }
    }

    private func fullView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 0) {
            artworkView
                .id(info.track)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 1.06).combined(with: .opacity)
                ))
                .padding(.top, 20)

            trackMetaView(info: info, source: source)
                .id(info.track + info.artist)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .padding(.top, 12)
                .padding(.horizontal, 20)

            if settings.showProgressBar && info.duration > 0 {
                progressView(info: info)
                    .padding(.top, 14)
                    .padding(.horizontal, 22)
            }

            controlsView(info: info)
                .padding(.top, 10)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)
            footer
        }
    }

    // MARK: - Artwork

    private var artworkView: some View {
        ZStack {
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 22)
                    .opacity(0.4)
                    .offset(y: 10)
                    .clipShape(Rectangle())
            }

            ZStack {
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                } else {
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .frame(width: 168, height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .frame(height: 178)
        .onTapGesture { activateActivePlayer() }
        .help(NSLocalizedString("Çalan uygulamayı ön plana getirmek için tıklayın", comment: "Bring app to front"))
    }

    // MARK: - Track Meta

    private func trackMetaView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 5) {
            Text(info.track)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let copied = model.copyTrackInfo() {
                        triggerToast(NSLocalizedString("Kopyalandı", comment: "Copied") + ": " + copied)
                    }
                }
                .help(NSLocalizedString("Tıklayarak şarkı ve sanatçı adını kopyalayın", comment: "Copy track info"))

            Text(info.artist)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 3) {
                Image(systemName: source == "Spotify" ? "music.note.list" : "music.note")
                    .font(.system(size: 9, weight: .semibold))
                Text(source)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.tertiary)
            .padding(.top, 1)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Progress

    private func progressView(info: NowPlayingInfo) -> some View {
        VStack(spacing: 5) {
            CustomSliderView(
                value: $sliderPosition,
                range: 0...max(info.duration, 1),
                onEditingChanged: { editing in
                    isDraggingPosition = editing
                    if !editing { model.seekTo(sliderPosition) }
                }
            )
            .onAppear { if !isDraggingPosition { sliderPosition = info.position } }
            .onChange(of: info.position) { _, v in if !isDraggingPosition { sliderPosition = v } }

            HStack {
                Text(formatTime(isDraggingPosition ? sliderPosition : info.position))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.quaternary)
                Spacer()
                Text("-" + formatTime(max(0, info.duration - (isDraggingPosition ? sliderPosition : info.position))))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - Controls

    private func controlsView(info: NowPlayingInfo) -> some View {
        HStack(spacing: 0) {
            Spacer()

            Button { model.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Önceki şarkı", comment: "Previous track"))

            Spacer()

            Button { model.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.75))
                        .frame(width: 54, height: 54)

                    Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .offset(x: info.isPlaying ? 0 : 1.5)
                }
            }
            .buttonStyle(.plain)
            .help(info.isPlaying ? NSLocalizedString("Duraklat", comment: "Pause") : NSLocalizedString("Oynat", comment: "Play"))

            Spacer()

            Button { model.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Sonraki şarkı", comment: "Next track"))

            Spacer()
        }
    }

    // MARK: - Compact View

    private func compactView(info: NowPlayingInfo) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    if let artwork = model.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.secondary.opacity(0.15)
                        Image(systemName: "music.note")
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 46, height: 46)
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
                HStack(spacing: 14) {
                    miniControlButton("backward.fill", size: 15) { model.previousTrack() }
                    miniControlButton(info.isPlaying ? "pause.fill" : "play.fill", size: 17) { model.togglePlayPause() }
                    miniControlButton("forward.fill", size: 15) { model.nextTrack() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            footer
        }
    }

    // MARK: - Recent Tracks

    private var recentTracksView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(NSLocalizedString("Son Çalınanlar", comment: "Recent Tracks"), systemImage: "clock.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if model.recentTracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text(NSLocalizedString("Henüz geçmiş yok", comment: "No history yet"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.recentTracks) { item in recentRow(item) }
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
    }

    private func recentRow(_ item: RecentTrack) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.source == "Spotify" ? "music.note.list" : "music.note")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.05), in: Circle())

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

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(item.track) - \(item.artist)", forType: .string)
                triggerToast(NSLocalizedString("Kopyalandı", comment: "Copied"))
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("Kopyala", comment: "Copy"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Not Running

    private var notRunningView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.secondary.opacity(0.08))
                        .frame(width: 76, height: 76)
                    Image(systemName: "headphones")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 5) {
                    Text(NSLocalizedString("Müzik Çalmıyor", comment: "Not playing"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(NSLocalizedString("Spotify veya Apple Music'i başlatın", comment: "Launch Spotify or Music"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    launchButton("Spotify", icon: "music.note.list", bundleID: "com.spotify.client")
                    launchButton("Apple Music", icon: "music.note", bundleID: "com.apple.Music")
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            footer
        }
    }

    private func launchButton(_ label: String, icon: String, bundleID: String) -> some View {
        Button { openPlayer(bundleID: bundleID) } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.orange.opacity(0.1))
                        .frame(width: 76, height: 76)
                    Image(systemName: "lock.shield")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.orange)
                }

                VStack(spacing: 5) {
                    Text(NSLocalizedString("İzin Gerekli", comment: "Permission Required"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(NSLocalizedString("Songleton, müzik uygulamalarına erişmek için Otomasyon iznine ihtiyaç duyuyor.", comment: "Permission explanation"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gear")
                            Text(NSLocalizedString("Gizlilik Ayarlarını Aç", comment: "Open Privacy Settings"))
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.requestPermissionByScript()
                    } label: {
                        Text(NSLocalizedString("Tekrar Dene", comment: "Try Again"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            footer
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button(NSLocalizedString("Ayarlar…", comment: "Settings")) {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.leading, 16)

                Spacer()

                Button(NSLocalizedString("Çıkış", comment: "Quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 16)
            }
            .frame(height: 32)
        }
    }

    // MARK: - Helpers

    private func miniControlButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 30, height: 30)
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

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
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
            let safeRange = max(range.upperBound - range.lowerBound, 0.001)
            let percent = max(0, min(1, (value - range.lowerBound) / safeRange))
            let activeWidth = totalWidth * CGFloat(percent)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 3.5)

                Capsule()
                    .fill(barColor.opacity(0.8))
                    .frame(width: max(3.5, activeWidth), height: 3.5)

                Circle()
                    .fill(Color.white)
                    .frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(0.22), radius: 2.5, x: 0, y: 1)
                    .offset(x: max(0, min(totalWidth - 11, activeWidth - 5.5)))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        onEditingChanged(true)
                        value = range.lowerBound + Double(max(0, min(1, g.location.x / totalWidth))) * safeRange
                    }
                    .onEnded { _ in onEditingChanged(false) }
            )
        }
        .frame(height: 16)
    }
}
