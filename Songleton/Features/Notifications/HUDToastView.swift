import SwiftUI

struct HUDButtonStyle: ButtonStyle {
    let accentColor: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : (isHovered ? 1.12 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct HUDToastView: View {
    let track: String
    let artist: String
    let artwork: NSImage?
    let layout: TrackNotificationLayout
    let accentColor: Color?
    let isPreview: Bool

    @ObservedObject private var model = NowPlayingModel.shared
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var isDragging: Bool = false

    private let cornerRadius: CGFloat = 18

    private var isPermanentMode: Bool {
        SettingsModel.shared.permanentHUDMode && !isPreview
    }

    private var isPlaying: Bool {
        if case .loaded(let info, _) = model.state {
            return info.isPlaying
        }
        return false
    }

    private var displayTrack: String {
        if isPreview { return track }
        if case .loaded(let info, _) = model.state {
            return info.track
        }
        return track
    }

    private var displayArtist: String {
        if isPreview { return artist }
        if case .loaded(let info, _) = model.state {
            return info.artist
        }
        return artist
    }

    private var resolvedArtwork: NSImage? {
        isPreview ? artwork : (artwork ?? model.artwork)
    }

    init(
        track: String,
        artist: String,
        artwork: NSImage?,
        layout: TrackNotificationLayout,
        accentColor: Color? = nil,
        isPreview: Bool = false
    ) {
        self.track = track
        self.artist = artist
        self.artwork = artwork
        self.layout = layout
        self.accentColor = accentColor
        self.isPreview = isPreview
    }

    private var themeColor: Color {
        accentColor ?? model.dominantColor
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(white: 0.12),
                        Color(white: 0.055),
                        Color.black.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                artworkAura

                LinearGradient(
                    colors: [.white.opacity(0.08), .clear, .black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                notificationContent
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .clipShape(cardShape)
            .overlay(
                cardShape.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.34), themeColor.opacity(0.46), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.68), radius: 11, x: 0, y: 7)
            .shadow(color: themeColor.opacity(0.30), radius: 20, x: 0, y: 8)
            .shadow(color: themeColor.opacity(0.13), radius: 30, x: 0, y: 9)
            .shadow(color: themeColor.opacity(0.08), radius: 46, x: 0, y: 10)
        }
        .frame(width: layout.panelSize.width, height: layout.panelSize.height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayArtist.isEmpty ? displayTrack : "\(displayTrack), \(displayArtist)")
    }

    @ViewBuilder
    private var artworkAura: some View {
        if let resolvedArtwork {
            Image(nsImage: resolvedArtwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: layout.size.width * 1.14, height: layout.size.height * 1.8)
                .blur(radius: 30)
                .saturation(1.35)
                .opacity(0.28)
                .id(resolvedArtwork)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: resolvedArtwork)
        } else {
            RadialGradient(
                colors: [themeColor.opacity(isPreview ? 0.34 : 0.20), .clear],
                center: .leading,
                startRadius: 8,
                endRadius: 150
            )
        }
    }

    private var notificationContent: some View {
        HStack(spacing: 12) {
            artworkTile

            VStack(alignment: .leading, spacing: 2) {
                ZStack(alignment: .leading) {
                    MarqueeText(
                        text: displayTrack,
                        font: .system(size: 13, weight: .bold, design: .rounded),
                        maxWidth: layout.textWidth,
                        alignment: .leading
                    )
                    .foregroundStyle(.white)
                    .id(displayTrack)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.45), value: displayTrack)

                if !displayArtist.isEmpty {
                    ZStack(alignment: .leading) {
                        MarqueeText(
                            text: displayArtist,
                            font: .system(size: 11, weight: .medium, design: .rounded),
                            maxWidth: layout.textWidth,
                            alignment: .leading
                        )
                        .foregroundStyle(.white.opacity(0.72))
                        .id(displayArtist)
                        .transition(.opacity)
                    }
                    .animation(.easeInOut(duration: 0.45), value: displayArtist)
                }
            }
            .frame(maxWidth: layout.textWidth, alignment: .leading)
            .layoutPriority(1)

            if isPermanentMode {
                HStack(spacing: 6) {
                    hudControlButton(
                        icon: "backward.fill",
                        label: LocalizationManager.shared.string("menu.previous_track")
                    ) {
                        model.previousTrack()
                    }

                    hudControlButton(
                        icon: isPlaying ? "pause.fill" : "play.fill",
                        label: isPlaying ? LocalizationManager.shared.string("control.pause") : LocalizationManager.shared.string("control.play")
                    ) {
                        model.togglePlayPause()
                    }

                    hudControlButton(
                        icon: "forward.fill",
                        label: LocalizationManager.shared.string("menu.next_track")
                    ) {
                        model.nextTrack()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var artworkTile: some View {
        ZStack {
            if let resolvedArtwork {
                Image(nsImage: resolvedArtwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    )
                    .id(resolvedArtwork)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [themeColor.opacity(0.34), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: isPreview ? "waveform" : "music.note")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isPreview ? themeColor : .white.opacity(0.64))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                    .id("placeholder-art")
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: resolvedArtwork)
    }

    private func hudControlButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.8))

                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(HUDButtonStyle(accentColor: themeColor))
        .accessibilityLabel(label)
    }
}
