import SwiftUI

struct HUDToastView: View {
    let track: String
    let artist: String
    let artwork: NSImage?
    let layout: TrackNotificationLayout
    let accentColor: Color?
    let isPreview: Bool

    @ObservedObject private var model = NowPlayingModel.shared

    private let cornerRadius: CGFloat = 18

    /// The cover shown in the toast. The caller may pass an explicit artwork
    /// (previews) or nil; when nil, the live NowPlayingModel artwork is used
    /// so a toast shown before the cover downloads simply fills in the moment
    /// it arrives — no need to delay the notification. Previews keep their
    /// placeholder and never adopt the currently playing track's cover.
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
        .accessibilityLabel(artist.isEmpty ? track : "\(track), \(artist)")
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
                Text(track)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: layout.textWidth, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var artworkTile: some View {
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
        }
    }
}
