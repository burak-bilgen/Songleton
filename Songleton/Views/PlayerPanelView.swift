import AppKit
import SwiftUI

// MARK: - PlayerPanelView

struct PlayerPanelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.openSettings) private var openSettings

    @State private var sliderVolume: Double = 50
    @State private var isDraggingVolume = false
    @State private var sliderPosition: Double = 0
    @State private var isDraggingPosition = false
    @State private var showingRecents = false

    private var isCompact: Bool { settings.panelStyle == .compact }
    private var panelWidth: CGFloat { 320 }

    var body: some View {
        ZStack {
            // Dynamic background
            backgroundView

            VStack(spacing: 0) {
                switch model.state {
                case .loaded(let info, let source):
                    loadedView(info: info, source: source)
                case .notRunning:
                    notRunningView
                case .permissionDenied:
                    permissionDeniedView
                }
            }
        }
        .frame(width: panelWidth)
        .onKeyPress(.space) { model.togglePlayPause(); return .handled }
    }

    // MARK: - Backgrounds

    private var backgroundView: some View {
        ZStack {
            if settings.useDynamicColor, case .loaded = model.state {
                model.dominantColor
                    .opacity(0.18)
                    .animation(.easeInOut(duration: 1.2), value: model.dominantColor.description)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Loaded State

    @ViewBuilder
    private func loadedView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 0) {
            if !isCompact {
                // Album artwork
                artworkView
                    .padding(.top, 16)
                    .padding(.horizontal, 16)

                // Track info
                trackInfoView(info: info, source: source)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                // Progress bar
                if settings.showProgressBar && info.duration > 0 {
                    progressView(info: info)
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                }

                // Controls
                controlsView(info: info)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                // Volume
                volumeView(info: info)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
            } else {
                // Compact: artwork + info side by side
                compactLoadedView(info: info, source: source)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            dividerAndFooter
        }
    }

    private var artworkView: some View {
        ZStack {
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
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
        .frame(width: panelWidth - 32, height: panelWidth - 32)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        .onTapGesture { activateActivePlayer() }
    }

    private func trackInfoView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 3) {
            Text(info.track)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(info.artist)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if !info.album.isEmpty {
                Text(info.album)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                Image(systemName: source == "Spotify" ? "music.note.list" : "music.note")
                    .font(.system(size: 9))
                Text(source)
                    .font(.system(size: 10))
            }
            .foregroundStyle(.quaternary)
            .padding(.top, 2)
        }
        .onTapGesture { activateActivePlayer() }
    }

    private func progressView(info: NowPlayingInfo) -> some View {
        VStack(spacing: 3) {
            Slider(value: $sliderPosition, in: 0...max(info.duration, 1)) { editing in
                isDraggingPosition = editing
                if !editing { model.seekTo(sliderPosition) }
            }
            .controlSize(.mini)
            .onAppear { if !isDraggingPosition { sliderPosition = info.position } }
            .onChange(of: info.position) { _, v in if !isDraggingPosition { sliderPosition = v } }

            HStack {
                Text(formatTime(isDraggingPosition ? sliderPosition : info.position))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(formatTime(info.duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func controlsView(info: NowPlayingInfo) -> some View {
        HStack(spacing: 0) {
            Spacer()
            controlButton("backward.end.fill", size: 18) { model.restartTrack() }
            Spacer()
            controlButton("backward.fill", size: 20) { model.previousTrack() }
            Spacer()
            // Play/Pause — bigger
            Button(action: { model.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(.primary.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            Spacer()
            controlButton("forward.fill", size: 20) { model.nextTrack() }
            Spacer()
            // Recents button
            Button(action: { withAnimation(.spring(duration: 0.3)) { showingRecents.toggle() } }) {
                Image(systemName: showingRecents ? "clock.fill" : "clock")
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func volumeView(info: NowPlayingInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: sliderVolume < 1 ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
            Slider(value: $sliderVolume, in: 0...100) { editing in
                isDraggingVolume = editing
                if !editing { model.setVolume(Int(sliderVolume)) }
            }
            .controlSize(.mini)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
        }
        .onAppear { sliderVolume = Double(info.volume) }
        .onChange(of: info.volume) { _, v in if !isDraggingVolume { sliderVolume = Double(v) } }
    }

    // MARK: - Compact Loaded

    private func compactLoadedView(info: NowPlayingInfo, source: String) -> some View {
        HStack(spacing: 12) {
            // Small artwork
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
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(info.track)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(info.artist)
                    .font(.system(size: 11))
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

    // MARK: - Not Running State

    private var notRunningView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)
            ZStack {
                Circle()
                    .fill(.secondary.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "headphones")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                Text("Müzik çalmıyor")
                    .font(.system(size: 15, weight: .semibold))
                Text("Spotify veya Apple Music'i başlatın")
                    .font(.system(size: 12))
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
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Permission Denied State

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.shield")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(.orange)
            }
            VStack(spacing: 6) {
                Text("İzin Gerekli")
                    .font(.system(size: 15, weight: .semibold))
                Text("Songleton, Spotify veya Apple Music'e erişmek için Otomasyon izni istiyor. Bu izin, menü çubuğunda çalan parçayı göstermek için gereklidir.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Button(action: { openAutomationSettings() }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Gizlilik Ayarlarını Aç")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Button(action: {
                    model.requestPermissionByScript()
                }) {
                    Text("Tekrar Dene")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("Sistem Ayarları → Gizlilik ve Güvenlik → Otomasyon bölümüne gidip Songleton'ın altında Spotify ve Music'e izin verin.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            dividerAndFooter
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Footer

    private var dividerAndFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 12)
            HStack(spacing: 0) {
                Button("Ayarlar…") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
                .padding(.leading, 16)

                Spacer()

                Button("Çıkış") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                    .padding(.trailing, 16)
            }
            .frame(height: 36)
        }
    }

    // MARK: - Helpers

    private func controlButton(_ systemName: String, size: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .frame(width: 34, height: 34)
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
        // macOS 13+: direct deep-link to Automation privacy pane
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
