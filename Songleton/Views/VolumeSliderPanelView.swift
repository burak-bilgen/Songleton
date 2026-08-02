import SwiftUI
import Combine

struct VolumeSliderPanelView: View {
    @ObservedObject var model = NowPlayingModel.shared

    @State private var spotifyVol: Double = 50
    @State private var appleMusicVol: Double = 50
    @State private var isDraggingSpotify = false
    @State private var isDraggingMusic = false

    @State private var appearScale: CGFloat = 0.9
    @State private var appearOpacity: Double = 0.0

    private var isSpotifyRunning: Bool {
        SpotifyController().isRunning
    }

    private var isMusicRunning: Bool {
        AppleMusicController().isRunning
    }

    private var isYouTubeRunning: Bool {
        YouTubeController().isRunning
    }

    var body: some View {
        ZStack {
            // Pure Jet Black Background with Glass Outline
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.8), radius: 16, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("SES MİKSERİ")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 4)

                // 1. Spotify Control Row
                if isSpotifyRunning {
                    mixerRow(
                        iconName: "circle.fill",
                        iconColor: Color(red: 29/255, green: 185/255, blue: 84/255),
                        name: "Spotify",
                        volume: $spotifyVol,
                        isDragging: $isDraggingSpotify,
                        onCommit: { newVol in
                            try? SpotifyController().setVolume(Int(newVol))
                        }
                    )
                }

                // 2. Apple Music Control Row
                if isMusicRunning {
                    mixerRow(
                        iconName: "music.note",
                        iconColor: Color(red: 250/255, green: 36/255, blue: 60/255),
                        name: "Apple Music",
                        volume: $appleMusicVol,
                        isDragging: $isDraggingMusic,
                        onCommit: { newVol in
                            try? AppleMusicController().setVolume(Int(newVol))
                        }
                    )
                }

                // 3. YouTube Browser Media Control Row
                if isYouTubeRunning {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 28, height: 28)
                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.red)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("YouTube")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Web Oynatıcısı")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Spacer()

                        Button {
                            try? YouTubeController().togglePlayPause()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Durdur")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                }

                // Fallback if no specific players active
                if !isSpotifyRunning && !isMusicRunning && !isYouTubeRunning {
                    HStack {
                        Text("Aktif Medya Oynatıcısı Bulunamadı")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(16)
        }
        .frame(width: 310)
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onAppear {
            if isSpotifyRunning, let info = try? SpotifyController().fetchNowPlaying() {
                spotifyVol = Double(info.volume)
            }
            if isMusicRunning, let info = try? AppleMusicController().fetchNowPlaying() {
                appleMusicVol = Double(info.volume)
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
    }

    private func mixerRow(
        iconName: String,
        iconColor: Color,
        name: String,
        volume: Binding<Double>,
        isDragging: Binding<Bool>,
        onCommit: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            Text(name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 75, alignment: .leading)

            Slider(
                value: volume,
                in: 0...100,
                onEditingChanged: { editing in
                    isDragging.wrappedValue = editing
                    if !editing {
                        onCommit(volume.wrappedValue)
                    }
                }
            )
            .tint(iconColor)

            Text("\(Int(volume.wrappedValue))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
}
