import SwiftUI

struct HUDToastView: View {
    let track: String
    let artist: String
    let artwork: NSImage?

    @ObservedObject private var model = NowPlayingModel.shared
    @State private var appearOffset: CGFloat = 24
    @State private var appearOpacity: Double = 0.0

    private var themeColor: Color {
        model.dominantColor
    }

    var body: some View {
        ZStack {
            // 1. Pure Jet Black Base Container
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.07))

            // 2. Ambient Artwork Aura Glow Layer (Matches Ambient Mode & Hover Panel)
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 270, height: 64)
                    .blur(radius: 40)
                    .saturation(1.8)
                    .opacity(0.36)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Circle()
                    .fill(themeColor.opacity(0.25))
                    .frame(width: 160, height: 160)
                    .blur(radius: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            // 3. Specular Glass Rim with Dynamic Theme Glow Shadow
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.30), .white.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .shadow(color: themeColor.opacity(0.40), radius: 16, x: 0, y: 8)

            // 4. Toast Content (Thumbnail + Meta)
            HStack(spacing: 12) {
                ZStack {
                    if let artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
        }
        .frame(width: 270, height: 64)
        .offset(x: appearOffset)
        .opacity(appearOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                appearOffset = 0
                appearOpacity = 1.0
            }
        }
    }
}
