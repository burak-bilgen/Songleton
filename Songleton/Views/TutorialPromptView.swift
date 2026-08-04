import SwiftUI

struct TutorialPromptView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    var onStart: () -> Void
    var onSkip: () -> Void

    @State private var pulseGlow = false

    var body: some View {
        ZStack {
            // Dark Backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SongletonTheme.cyan.opacity(0.35), SongletonTheme.violet.opacity(0.35)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: pulseGlow ? 18 : 8)
                        .scaleEffect(pulseGlow ? 1.08 : 0.96)

                    Circle()
                        .fill(SongletonTheme.panelGradient)
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(SongletonTheme.cyan.opacity(0.6), lineWidth: 1.5))

                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [SongletonTheme.cyan, .white], startPoint: .top, endPoint: .bottom)
                        )
                }

                // Titles
                VStack(spacing: 8) {
                    Text(localization.string("tutorial.prompt_title"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(localization.string("tutorial.prompt_subtitle"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 6)

                // Feature Bullets Card
                VStack(alignment: .leading, spacing: 12) {
                    bulletRow(icon: "sparkles", text: localization.string("tutorial.prompt_bullet_1"))
                    bulletRow(icon: "keyboard.fill", text: localization.string("tutorial.prompt_bullet_2"))
                    bulletRow(icon: "arrow.uturn.backward.circle.fill", text: localization.string("tutorial.prompt_bullet_3"))
                }
                .padding(16)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))

                // Actions
                VStack(spacing: 12) {
                    Button(action: onStart) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(SongletonTheme.accentGradient)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(color: SongletonTheme.cyan.opacity(0.45), radius: 14, y: 4)

                            Text(localization.string("tutorial.prompt_start"))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Text(localization.string("tutorial.prompt_skip"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .frame(width: 440)
            .background(SongletonTheme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(SongletonTheme.cyan.opacity(0.35), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.7), radius: 30, y: 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(SongletonTheme.cyan)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()
        }
    }
}
