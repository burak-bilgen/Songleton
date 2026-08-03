import AppKit
import SwiftUI

struct PlayerPanelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject private var settings = SettingsModel.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.openSettings) private var openSettings

    @State private var selectedTab = 0
    @State private var sliderPosition: Double = 0
    @State private var isDraggingPosition = false
    @State private var showCopiedToast = false
    @State private var toastText = ""
    @Namespace private var tabAnimationNamespace

    // Button press animation states
    @State private var playButtonScale: CGFloat = 1.0
    @State private var prevButtonScale: CGFloat = 1.0
    @State private var nextButtonScale: CGFloat = 1.0

    private var isCompact: Bool { false }
    private let panelWidth: CGFloat = 350

    var body: some View {
        ZStack(alignment: .top) {
            liquidBackgroundView

            VStack(spacing: 0) {
                topTabBar
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                ZStack {
                    switch selectedTab {
                    case 0:
                        switch model.state {
                        case .loaded(let info, let source):
                            loadedView(info: info, source: source)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 1.03).combined(with: .opacity)
                                ))
                        case .notRunning:
                            notRunningView
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        case .permissionDenied:
                            permissionDeniedView
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    case 1:
                        SyncedLyricsView(nowPlaying: model)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case 2:
                        SpotifyPlaylistsView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case 3:
                        recentTracksView
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    default:
                        EmptyView()
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.75), value: selectedTab)
                .frame(maxHeight: .infinity)
            }

            if showCopiedToast {
                toastBanner
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .scale(scale: 0.85)).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                    .padding(.top, 54)
                    .zIndex(1)
            }
        }
        .frame(width: panelWidth)
        .focusable()
        .onKeyPress(.space) { model.togglePlayPause(); return .handled }
        .onKeyPress(.leftArrow) { model.previousTrack(); return .handled }
        .onKeyPress(.rightArrow) { model.nextTrack(); return .handled }
    }

    // MARK: - Liquid Tab Bar with Matched Geometry Animation

    private var topTabBar: some View {
        HStack(spacing: 4) {
            tabButton(icon: "music.note", label: localization.string("tab.player"), index: 0)
            tabButton(icon: "quote.bubble.fill", label: localization.string("tab.lyrics"), index: 1)
            tabButton(icon: "music.note.list", label: localization.string("tab.playlists"), index: 2)
            tabButton(icon: "clock.fill", label: localization.string("tab.history"), index: 3)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
    }

    private func tabButton(icon: String, label: String, index: Int) -> some View {
        let active = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selectedTab = index }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .scaleEffect(active ? 1.15 : 1.0)
                Text(label)
                    .font(.system(size: 11, weight: active ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(active ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if active {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.22))
                            .matchedGeometryEffect(id: "activeTabHighlight", in: tabAnimationNamespace)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Liquid Background

    private var liquidBackgroundView: some View {
        ZStack {
            Rectangle()
                .fill(SongletonTheme.panelGradient)

            if settings.useDynamicColor, case .loaded = model.state {
                model.dominantColor
                .opacity(0.2)
                    .blur(radius: 50)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: model.dominantColor.description)
            }

            // Glass specular gradient highlight
            LinearGradient(
                colors: [SongletonTheme.cyan.opacity(0.12), .clear, SongletonTheme.violet.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Toast Banner with Spring Bounce

    private var toastBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: showCopiedToast)
            Text(toastText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
        )
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }

    private func triggerToast(_ text: String) {
        toastText = text
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.3)) { showCopiedToast = false }
        }
    }

    // MARK: - Loaded View

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
                    insertion: .scale(scale: 0.88).combined(with: .opacity),
                    removal: .scale(scale: 1.06).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: info.track)
                .padding(.top, 16)

            trackMetaView(info: info, source: source)
                .id(info.track + info.artist)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.68), value: info.track)
                .padding(.top, 14)
                .padding(.horizontal, 20)

            if settings.showProgressBar && info.duration > 0 {
                progressView(info: info)
                    .padding(.top, 16)
                    .padding(.horizontal, 22)
            }

            controlsView(info: info)
                .padding(.top, 12)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)
            footer
        }
    }

    // MARK: - Liquid Artwork with Ambient Glow Animation

    private var artworkView: some View {
        ZStack {
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 28)
                    .opacity(0.48)
                    .offset(y: 12)
                    .clipShape(Rectangle())
            }

            ZStack {
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity.animation(.spring(response: 0.4, dampingFraction: 0.7)))
                } else {
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .frame(width: 172, height: 172)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
        }
        .frame(height: 182)
        .onTapGesture { activateActivePlayer() }
        .help(localization.string("player.bring_to_front"))
    }

    // MARK: - Track Meta

    private func trackMetaView(info: NowPlayingInfo, source: String) -> some View {
        VStack(spacing: 4) {
            Text(info.track)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let copied = model.copyTrackInfo() {
                        triggerToast(localization.string("common.copied") + ": " + copied)
                    }
                }
                .help(localization.string("player.copy_track_hint"))

            Text(info.artist)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: source == localization.string("source.spotify") ? "music.note.list" : source == localization.string("source.apple_music") ? "music.note" : "play.tv.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text(source)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
            .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Progress

    private func progressView(info: NowPlayingInfo) -> some View {
        VStack(spacing: 6) {
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
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("-" + formatTime(max(0, info.duration - (isDraggingPosition ? sliderPosition : info.position))))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Controls with Spring Physics Press Animations

    private func controlsView(info: NowPlayingInfo) -> some View {
        HStack(spacing: 0) {
            Spacer()

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
                        .frame(width: 42, height: 42)

                    Image(systemName: "backward.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(prevButtonScale)
            .help(localization.string("menu.previous_track"))

            Spacer()

            // Play / Pause Button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { playButtonScale = 0.85 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { playButtonScale = 1.0 }
                }
                model.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.55), .white.opacity(0.18)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
                        .frame(width: 58, height: 58)

                    Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .offset(x: info.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(playButtonScale)
            .help(info.isPlaying ? localization.string("control.pause") : localization.string("control.play"))

            Spacer()

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
                        .frame(width: 42, height: 42)

                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(nextButtonScale)
            .help(localization.string("menu.next_track"))

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
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
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
                    miniControlButton("backward.fill", size: 14) { model.previousTrack() }
                    miniControlButton(info.isPlaying ? "pause.fill" : "play.fill", size: 16) { model.togglePlayPause() }
                    miniControlButton("forward.fill", size: 14) { model.nextTrack() }
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
                    Label(localization.string("history.title"), systemImage: "clock.fill")
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
                        Text(localization.string("history.empty"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.recentTracks) { item in recentRow(item) }
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
    }

    private func recentRow(_ item: RecentTrack) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.source == localization.string("source.spotify") ? "music.note.list" : item.source == localization.string("source.apple_music") ? "music.note" : "play.tv.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.1), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))

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
                let copied = item.artist.isEmpty ? item.track : "\(item.artist) - \(item.track)"
                NSPasteboard.general.setString(copied, forType: .string)
                triggerToast(localization.string("common.copied"))
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
                .help(localization.string("common.copy"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        )
    }

    // MARK: - Not Running

    private var notRunningView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        .frame(width: 76, height: 76)
                    Image(systemName: "headphones")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 5) {
                    Text(localization.string("player.not_playing"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(localization.string("player.launch_hint"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    launchButton(localization.string("source.spotify"), icon: "music.note.list", bundleID: "com.spotify.client")
                    launchButton(localization.string("source.apple_music"), icon: "music.note", bundleID: "com.apple.Music")
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
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                )
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
                        .fill(.orange.opacity(0.12))
                        .overlay(Circle().stroke(Color.orange.opacity(0.25), lineWidth: 0.5))
                        .frame(width: 76, height: 76)
                    Image(systemName: "lock.shield")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.orange)
                }

                VStack(spacing: 5) {
                        Text(localization.string("permission.required"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(localization.string("permission.explanation"))
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
                            Text(localization.string("permission.open_settings"))
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.requestPermissionByScript()
                    } label: {
                        Text(localization.string("common.try_again"))
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
            Divider().opacity(0.3)
            HStack {
                    Button(localization.string("settings.title")) {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 16)

                Spacer()

                Button(localization.string("common.quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.trailing, 16)
            }
            .frame(height: 34)
        }
    }

    // MARK: - Helpers

    private func miniControlButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    .frame(width: 30, height: 30)

                Image(systemName: systemName)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
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
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [barColor, barColor.opacity(0.75)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, activeWidth), height: 4)

                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1.5)
                    .offset(x: max(0, min(totalWidth - 12, activeWidth - 6)))
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
