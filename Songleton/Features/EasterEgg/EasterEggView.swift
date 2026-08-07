import SwiftUI
import AppKit
import Combine

struct EasterEggParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speedY: CGFloat
    var rotation: Double
    var rotationSpeed: Double
    var symbol: String
}

struct EasterEggView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    var onOpenSpotify: () -> Void
    var onDismiss: () -> Void

    @State private var particles: [EasterEggParticle] = []
    @State private var vinylAngle: Double = 0
    @State private var auraPulse: Bool = false
    @State private var cardScale: CGFloat = 0.7
    @State private var cardOpacity: Double = 0
    @State private var hoveredButton: String? = nil
    @State private var timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    private let spotifyGreen = Color(red: 29/255, green: 185/255, blue: 84/255)

    var body: some View {
        ZStack {
            // 1. Full Screen Translucent Dark Glass Backdrop
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // 2. Dual Dynamic Radial Ambient Glow Orbs
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(spotifyGreen.opacity(auraPulse ? 0.35 : 0.20))
                        .frame(width: 550, height: 550)
                        .blur(radius: 110)
                        .position(x: geo.size.width * 0.35, y: geo.size.height * 0.45)
                        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: auraPulse)

                    Circle()
                        .fill(Color.purple.opacity(auraPulse ? 0.25 : 0.12))
                        .frame(width: 480, height: 480)
                        .blur(radius: 120)
                        .position(x: geo.size.width * 0.65, y: geo.size.height * 0.55)
                        .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: auraPulse)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 3. Floating Musical Particles Layer
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x * size.width - particle.size / 2,
                        y: particle.y * size.height - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    context.opacity = particle.opacity
                    context.draw(
                        Text(particle.symbol)
                            .font(.system(size: particle.size))
                            .foregroundStyle(spotifyGreen),
                        at: CGPoint(x: rect.midX, y: rect.midY)
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 4. Center Easter Egg Animated Card
            VStack(spacing: 22) {
                // Spinning Vinyl Centerpiece
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [spotifyGreen, .cyan, .purple, spotifyGreen],
                                center: .center,
                                startAngle: .degrees(vinylAngle),
                                endAngle: .degrees(vinylAngle + 360)
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 4)

                    Circle()
                        .fill(Color(white: 0.08))
                        .frame(width: 174, height: 174)
                        .shadow(color: .black.opacity(0.7), radius: 18, x: 0, y: 8)

                    Circle().stroke(Color(white: 0.16), lineWidth: 1.5).frame(width: 155, height: 155)
                    Circle().stroke(Color(white: 0.13), lineWidth: 1.0).frame(width: 130, height: 130)
                    Circle().stroke(Color(white: 0.11), lineWidth: 1.0).frame(width: 105, height: 105)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [spotifyGreen, Color(red: 20/255, green: 140/255, blue: 60/255)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))

                        VStack(spacing: 2) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Text(verbatim: "SHUFFLE")
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                    Circle()
                        .fill(Color.black)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                }
                .rotationEffect(.degrees(vinylAngle))

                // Equalizer Bar Visualizer
                HStack(spacing: 4) {
                    ForEach(0..<14, id: \.self) { i in
                        EqualizerBar(index: i, color: spotifyGreen)
                    }
                }
                .frame(height: 24)

                // Animated Main Text
                VStack(spacing: 8) {
                    Text(localization.string("easter_egg.title"))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, spotifyGreen, .white],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .shadow(color: spotifyGreen.opacity(0.6), radius: 14, x: 0, y: 4)

                    Text(localization.string("easter_egg.subtitle"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)

                    Text(localization.string("easter_egg.playing"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                }

                // Action Buttons
                HStack(spacing: 14) {
                    Button {
                        onOpenSpotify()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(localization.string("easter_egg.open_spotify"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background(spotifyGreen, in: Capsule())
                        .shadow(color: spotifyGreen.opacity(0.45), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(hoveredButton == "spotify" ? 1.06 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.6), value: hoveredButton)
                    .onHover { isHovered in hoveredButton = isHovered ? "spotify" : nil }

                    Button {
                        onDismiss()
                    } label: {
                        Text(localization.string("easter_egg.close"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(hoveredButton == "dismiss" ? 1.06 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.6), value: hoveredButton)
                    .onHover { isHovered in hoveredButton = isHovered ? "dismiss" : nil }
                }
                .padding(.top, 4)

                Text(LocalizationManager.shared.string("easter_egg.close_hint"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(white: 0.06).opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [spotifyGreen.opacity(0.6), .white.opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.85), radius: 40, x: 0, y: 20)
            )
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
            setupParticles()
            auraPulse = true

            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
        .onReceive(timer) { _ in
            vinylAngle += 1.2
            updateParticles()
        }
    }

    private func setupParticles() {
        let symbols = ["🎵", "🎶", "🎼", "🎧", "✨", "⚡️", "💿"]
        particles = (0..<24).map { _ in
            EasterEggParticle(
                x: Double.random(in: 0.05...0.95),
                y: Double.random(in: 0.1...1.1),
                size: CGFloat.random(in: 14...26),
                opacity: Double.random(in: 0.2...0.75),
                speedY: CGFloat.random(in: 0.0015...0.0045),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -1.5...1.5),
                symbol: symbols.randomElement()!
            )
        }
    }

    private func updateParticles() {
        for i in 0..<particles.count {
            particles[i].y -= particles[i].speedY
            particles[i].rotation += particles[i].rotationSpeed
            if particles[i].y < -0.05 {
                particles[i].y = 1.05
                particles[i].x = Double.random(in: 0.05...0.95)
            }
        }
    }
}

struct EqualizerBar: View {
    let index: Int
    let color: Color
    @State private var heightMultiplier: CGFloat = 0.4

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 4, height: 24 * heightMultiplier)
            .animation(
                .easeInOut(duration: Double.random(in: 0.25...0.55))
                    .repeatForever(autoreverses: true),
                value: heightMultiplier
            )
            .onAppear {
                heightMultiplier = CGFloat.random(in: 0.25...1.0)
            }
    }
}
