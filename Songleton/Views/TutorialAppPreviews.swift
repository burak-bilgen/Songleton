import SwiftUI

/// Deterministic previews used by the tutorial. They intentionally mirror the
/// production surfaces without observing a real player, permission state, or
/// artwork. A guide must not become empty just because Spotify is closed.
struct TutorialMenuBarPreview: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var isRightClicking: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "backward.fill")
                .frame(width: 28, height: 24)

            HStack(spacing: 6) {
                Circle()
                    .fill(SongletonTheme.cyan)
                    .frame(width: 7, height: 7)
                Text(localization.string("tutorial.demo_track"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(width: 210, height: 24)
            .background(Color.white.opacity(0.10), in: Capsule())

            Image(systemName: "forward.fill")
                .frame(width: 28, height: 24)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(Color.black.opacity(0.94), in: Capsule())
        .overlay(
            Capsule().stroke(
                isRightClicking ? SongletonTheme.pink : SongletonTheme.cyan.opacity(0.55),
                lineWidth: 1
            )
        )
        .shadow(color: .black.opacity(0.60), radius: 14, y: 7)
        .animation(.easeInOut(duration: 0.22), value: isRightClicking)
    }
}

struct TutorialHoverPanelPreview: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SongletonTheme.panelGradient)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            VStack(spacing: 14) {
                HStack {
                    Label(localization.string("ambient.short_label"), systemImage: "sparkles.tv.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(SongletonTheme.cyan)
                    Spacer()
                    Image(systemName: "gearshape.fill")
                    Image(systemName: "power")
                }
                .foregroundStyle(.white.opacity(0.78))

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [SongletonTheme.violet, SongletonTheme.cyan, SongletonTheme.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 94, height: 94)
                        .overlay(Image(systemName: "music.note").font(.system(size: 32, weight: .bold)))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(localization.string("tutorial.demo_track"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(localization.string("tutorial.demo_artist"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                        Text("Spotify")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(SongletonTheme.cyan)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 18) {
                    Image(systemName: "shuffle")
                    Image(systemName: "backward.fill")
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(SongletonTheme.cyan, in: Circle())
                    Image(systemName: "forward.fill")
                    Image(systemName: "repeat")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.86))

                HStack(spacing: 9) {
                    Image(systemName: "speaker.wave.2.fill")
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 6)
                        .overlay(alignment: .leading) {
                            Capsule().fill(SongletonTheme.cyan).frame(width: 118)
                        }
                    Text("38%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.76))
            }
            .padding(18)
        }
        .frame(width: 360, height: 270)
        .shadow(color: .black.opacity(0.55), radius: 22, y: 12)
    }
}

struct TutorialAmbientPreview: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        ZStack {
            Color.black

            Circle()
                .fill(SongletonTheme.violet.opacity(0.56))
                .frame(width: 420, height: 420)
                .blur(radius: 110)

            VStack(spacing: 24) {
                HStack {
                    Text("10:42")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    HStack(spacing: 10) {
                        Label(localization.string("ambient.theme.vinyl"), systemImage: "record.circle")
                        Label(localization.string("ambient.lyrics"), systemImage: "quote.bubble.fill")
                        Text("ESC")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }

                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 8))
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SongletonTheme.cyan, SongletonTheme.violet, SongletonTheme.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 128, height: 128)
                    Circle().fill(.black).frame(width: 24, height: 24)
                }
                .frame(width: 230, height: 230)

                VStack(spacing: 6) {
                    Text(localization.string("tutorial.demo_track"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(localization.string("tutorial.demo_artist"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                }

                HStack(spacing: 28) {
                    Image(systemName: "backward.fill")
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.black)
                        .frame(width: 46, height: 46)
                        .background(SongletonTheme.cyan, in: Circle())
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 18, weight: .bold))
            }
            .padding(24)
            .foregroundStyle(.white)
        }
    }
}
