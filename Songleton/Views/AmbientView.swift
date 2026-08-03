import SwiftUI
import Combine

struct AmbientView: View {
    @ObservedObject var model = NowPlayingModel.shared
    @ObservedObject var settings = SettingsModel.shared
    @ObservedObject private var localization = LocalizationManager.shared
    var onClose: () -> Void

    // Vinyl Rotation Animation State
    @State private var vinylRotation: Double = 0
    @State private var timerCancellable: AnyCancellable?

    // Auto-Hide Interface State
    @State private var showControls: Bool = true
    @State private var idleWorkItem: DispatchWorkItem?

    // Local Slider State
    @State private var sliderPosition: Double = 0
    @State private var isDraggingPosition: Bool = false
    @State private var localVolume: Double = 50.0
    @State private var isDraggingVolume: Bool = false

    // Live Clock State
    @State private var currentTimeString: String = ""
    @State private var currentDateString: String = ""
    private let clockTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var themeColor: Color {
        model.platformAccentColor
    }

    var body: some View {
        ZStack {
            // 1. Pure AMOLED Pitch Black Background
            Color.black
                .ignoresSafeArea()

            // 2. Dynamic Fluid Ambient Glow (Blur Mesh)
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.22))
                    .frame(width: 550, height: 550)
                    .blur(radius: 120)
                    .offset(x: -250, y: -150)

                Circle()
                    .fill(themeColor.opacity(0.15))
                    .frame(width: 480, height: 480)
                    .blur(radius: 110)
                    .offset(x: 280, y: 180)
            }
            .ignoresSafeArea()

            // 3. Main Content Grid (Two Columns: Vinyl/Player on Left, Synced Lyrics on Right)
            HStack(spacing: 48) {
                // Left Column: Spinning Vinyl Record + Album Cover + Meta + Controls
                VStack(spacing: 24) {
                    Spacer()

                    // Vinyl Record & Album Artwork Display
                    ZStack {
                        // Vinyl Record Disc
                        ZStack {
                            // Disc Outer Groove Layers
                            Circle()
                                .fill(Color(white: 0.07))
                                .frame(width: 280, height: 280)
                                .shadow(color: .black.opacity(0.8), radius: 20, x: 0, y: 10)

                            // Realistic Vinyl Grooves
                            Circle()
                                .stroke(Color(white: 0.12), lineWidth: 1)
                                .frame(width: 260, height: 260)
                            Circle()
                                .stroke(Color(white: 0.11), lineWidth: 1)
                                .frame(width: 230, height: 230)
                            Circle()
                                .stroke(Color(white: 0.10), lineWidth: 1)
                                .frame(width: 200, height: 200)
                            Circle()
                                .stroke(Color(white: 0.09), lineWidth: 1)
                                .frame(width: 170, height: 170)

                            // Vinyl Center Label with Artwork Thumbnail
                            if let artwork = model.artwork {
                                Image(nsImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            } else {
                                Circle()
                                    .fill(themeColor.opacity(0.4))
                                    .frame(width: 90, height: 90)
                            }

                            // Center Spindle Hole
                            Circle()
                                .fill(Color.black)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        }
                        .rotationEffect(.degrees(vinylRotation))
                        .offset(x: 75) // Slides out from behind artwork

                        // Album Artwork Cover Container
                        ZStack {
                            if let artwork = model.artwork {
                                Image(nsImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 240, height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.white.opacity(0.3), .white.opacity(0.08)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.7), radius: 25, x: -5, y: 12)
                            } else {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 240, height: 240)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 54, weight: .ultraLight))
                                            .foregroundStyle(Color.white.opacity(0.3))
                                    )
                            }
                        }
                    }
                    .frame(width: 400, height: 280)

                    // Track & Artist Meta
                    if case .loaded(let info, let source) = model.state {
                        VStack(spacing: 6) {
                            Text(info.track)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            if !info.artist.isEmpty {
                                Text(info.artist)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .lineLimit(1)
                            }

                            // Active Source Badge
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(themeColor)
                                    .frame(width: 7, height: 7)
                                Text(source)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: 380)

                        // Playback Controls Section (Fades with Auto-Hide)
                        VStack(spacing: 16) {
                            // Progress Bar
                            if info.duration > 0 {
                                VStack(spacing: 4) {
                                    CustomSliderView(
                                        value: $sliderPosition,
                                        range: 0...max(info.duration, 1),
                                        onEditingChanged: { editing in
                                            isDraggingPosition = editing
                                            if !editing { model.seekTo(sliderPosition) }
                                        },
                                        barColor: themeColor
                                    )
                                    .onAppear { if !isDraggingPosition { sliderPosition = info.position } }
                                    .onChange(of: info.position) { _, v in if !isDraggingPosition { sliderPosition = v } }

                                    HStack {
                                        Text(formatTime(isDraggingPosition ? sliderPosition : info.position))
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.5))
                                        Spacer()
                                        Text("-" + formatTime(max(0, info.duration - (isDraggingPosition ? sliderPosition : info.position))))
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .frame(width: 340)
                            }

                            // Playback Buttons Row
                            HStack(spacing: 22) {
                                Button { model.toggleShuffle() } label: {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(info.isShuffleEnabled ? themeColor : .white.opacity(0.5))
                                }
                                .buttonStyle(.plain)

                                Button { model.previousTrack() } label: {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)

                                Button { model.togglePlayPause() } label: {
                                    ZStack {
                                        Circle()
                                            .fill(themeColor)
                                            .shadow(color: themeColor.opacity(0.6), radius: 14, x: 0, y: 5)
                                            .frame(width: 56, height: 56)

                                        Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundStyle(.white)
                                            .offset(x: info.isPlaying ? 0 : 2)
                                    }
                                }
                                .buttonStyle(.plain)

                                Button { model.nextTrack() } label: {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)

                                Button { model.cycleRepeatMode() } label: {
                                    Image(systemName: info.repeatMode == .one ? "repeat.1" : "repeat")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(info.repeatMode != .off ? themeColor : .white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }

                            // Volume Row
                            HStack(spacing: 10) {
                                Image(systemName: "speaker.wave.1.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.6))

                                CustomSliderView(
                                    value: $localVolume,
                                    range: 0...100,
                                    onEditingChanged: { editing in
                                        isDraggingVolume = editing
                                        if !editing { model.setVolume(Int(localVolume)) }
                                    },
                                    barColor: themeColor
                                )
                                .frame(width: 140)

                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.top, 4)
                        }
                        .opacity(showControls ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.4), value: showControls)
                    }

                    Spacer()
                }
                .frame(width: 420)

                // Right Column: Synced Lyrics View (Full Height, Glass Card)
                VStack {
                    SyncedLyricsView(nowPlaying: model)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: 600, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .padding(.vertical, 48)
            }
            .padding(.horizontal, 48)

            // 4. Top Status Bar (Clock, Date & Exit Button - Fades with Auto-Hide)
            VStack {
                HStack {
                    // Desk Clock & Date Display
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentTimeString)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(currentDateString)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    // Exit Ambient Mode Button
                    Button {
                        onClose()
                    } label: {
                        HStack(spacing: 6) {
                            Text("ESC")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            Text("Exit Ambient")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 36)
                .padding(.top, 28)

                Spacer()
            }
            .opacity(showControls ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.4), value: showControls)
        }
        .onContinuousHover { _ in
            registerUserActivity()
        }
        .onAppear {
            updateClock()
            startVinylAnimation()
            registerUserActivity()
            if case .loaded(let info, _) = model.state {
                localVolume = Double(info.volume)
            }
        }
        .onDisappear {
            stopVinylAnimation()
        }
        .onReceive(clockTimer) { _ in
            updateClock()
        }
    }

    // MARK: - Helpers

    private func registerUserActivity() {
        showControls = true
        idleWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) {
                showControls = false
            }
        }
        idleWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: item)
    }

    private func startVinylAnimation() {
        timerCancellable = Timer.publish(every: 0.03, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if case .loaded(let info, _) = model.state, info.isPlaying {
                    vinylRotation += 0.8
                    if vinylRotation >= 360 { vinylRotation = 0 }
                }
            }
    }

    private func stopVinylAnimation() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        currentTimeString = formatter.string(from: Date())

        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        currentDateString = formatter.string(from: Date())
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
