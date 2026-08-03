import SwiftUI

struct HUDToastView: View {
    let track: String
    let artist: String
    let artwork: NSImage?

    @ObservedObject private var model = NowPlayingModel.shared
    @State private var appearScale: CGFloat = 0.85
    @State private var appearOpacity: Double = 0.0

    private var themeColor: Color {
        model.platformAccentColor
    }

    var body: some View {
        ZStack {
            // Pure Jet Black Background with Clean Specular Glass Rim (No Glow)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SongletonTheme.panelGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [SongletonTheme.cyan.opacity(0.4), SongletonTheme.violet.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.75), radius: 12, x: 0, y: 6)

            HStack(spacing: 8) {
                // Track Artwork (Snug to Left Edge, Clean Specular Border, No Glow)
                ZStack {
                    if let artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.35), .white.opacity(0.1)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.75
                                    )
                            )
                            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            )
                    }
                }

                // Track & Artist Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(artist)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
        }
        .frame(width: 240, height: 56)
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.54)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
    }
}
