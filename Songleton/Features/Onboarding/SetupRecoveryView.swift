import SwiftUI

/// A deliberate recovery surface for people who close onboarding before a
/// music-player permission is ready. Keeping this as a normal window means
/// Songleton never becomes an invisible, unusable background process.
struct SetupRecoveryView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    let onContinue: () -> Void
    let onQuit: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            SongletonTheme.background.ignoresSafeArea()

            Circle()
                .fill(SongletonTheme.cyan.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -130, y: -120)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(SongletonTheme.cyan.opacity(0.16))
                        .frame(width: 76, height: 76)
                    SongletonBrandMark(size: 46)
                }

                VStack(spacing: 8) {
                    Text(localization.string("setup_recovery.title"))
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(localization.string("setup_recovery.subtitle"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button(action: onContinue) {
                        Label(localization.string("setup_recovery.continue"), systemImage: "arrow.right.circle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.84))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(SongletonTheme.accentGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onQuit) {
                        Text(localization.string("setup_recovery.quit"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .frame(width: 400)
            .background(SongletonTheme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(SongletonTheme.cyan.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 24, y: 12)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .frame(width: 460, height: 360)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}
