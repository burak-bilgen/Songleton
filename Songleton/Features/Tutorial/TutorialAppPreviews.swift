import SwiftUI

/// Deterministic previews used by the tutorial. They intentionally mirror the
/// production surfaces without observing a real player, permission state, or
/// artwork. A guide must not become empty just because Spotify is closed.
struct TutorialMenuBarPreview: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var isRightClicking: Bool
    var isPlaying: Bool = true

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "backward.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))

            // Square Album Artwork (mini cover)
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1.00, green: 0.42, blue: 0.20), Color(red: 0.24, green: 0.10, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Circle()
                        .fill(Color(red: 1.00, green: 0.72, blue: 0.35).opacity(0.9))
                        .frame(width: 8, height: 8)
                        .offset(x: 3, y: -2)
                )
                .frame(width: 15, height: 15)

            Text(localization.string("tutorial.demo_track"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Image(systemName: "forward.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isRightClicking ? SongletonTheme.pink : Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.40), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.20), value: isRightClicking)
        .animation(.easeInOut(duration: 0.20), value: isPlaying)
    }
}

struct FullMacOSMenuBarPreview: View {
    var isRightClicking: Bool
    var isPlaying: Bool = true

    var body: some View {
        ZStack {
            // Simulated macOS Top Menu Bar Glass Strip
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.48))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 1),
                    alignment: .bottom
                )
                .frame(height: 28)

            HStack(spacing: 0) {
                // Left Side: Official Apple Logo  + Active App Menus
                HStack(spacing: 14) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 13, weight: .bold))

                    Text(verbatim: "Songleton")
                        .font(.system(size: 13, weight: .bold))

                    Group {
                        Text(LocalizationManager.shared.string("tutorial.mock_menu_file"))
                        Text(LocalizationManager.shared.string("tutorial.mock_menu_edit"))
                        Text(LocalizationManager.shared.string("tutorial.mock_menu_view"))
                        Text(LocalizationManager.shared.string("tutorial.mock_menu_window"))
                        Text(LocalizationManager.shared.string("tutorial.mock_menu_help"))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)
                .padding(.leading, 14)

                Spacer()

                // Right Side: Songleton Status Item + macOS System Icons
                HStack(spacing: 14) {
                    TutorialMenuBarPreview(isRightClicking: isRightClicking, isPlaying: isPlaying)

                    HStack(spacing: 10) {
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100")
                        Image(systemName: "controlcenter")
                        Image(systemName: "magnifyingglass")
                        Text(verbatim: "Thu 15:40")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.trailing, 14)
                }
            }
        }
        .frame(height: 28)
    }
}

struct TutorialHoverPanelPreview: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 24/255, green: 24/255, blue: 36/255).opacity(0.96),
                            Color(red: 14/255, green: 14/255, blue: 22/255).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            VStack(spacing: 14) {
                // Header Bar
                HStack {
                    Label(localization.string("ambient.short_label"), systemImage: "sparkles.tv.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(SongletonTheme.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SongletonTheme.cyan.opacity(0.15), in: Capsule())
                    Spacer()
                    Image(systemName: "gearshape.fill")
                    Image(systemName: "power")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))

                // Artwork & Metadata
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.00, green: 0.52, blue: 0.24), Color(red: 0.55, green: 0.20, blue: 0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: SongletonTheme.violet.opacity(0.4), radius: 10, y: 4)
                            .overlay(
                                GeometryReader { proxy in
                                    let w = proxy.size.width
                                    ZStack {
                                        // Setting sun
                                        Circle()
                                            .fill(Color(red: 1.00, green: 0.78, blue: 0.38).opacity(0.95))
                                            .frame(width: w * 0.42, height: w * 0.42)
                                            .offset(x: -w * 0.10, y: -w * 0.14)
                                        // Horizon haze
                                        LinearGradient(
                                            colors: [Color(red: 1.00, green: 0.55, blue: 0.25).opacity(0.85), Color.clear],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                        .frame(height: w * 0.34)
                                        .offset(y: w * 0.28)
                                        // City skyline silhouette
                                        HStack(spacing: 3) {
                                            ForEach(0..<7, id: \.self) { index in
                                                Capsule()
                                                    .fill(Color(red: 0.08, green: 0.05, blue: 0.16).opacity(0.95))
                                                    .frame(width: w * 0.07, height: w * (0.10 + Double(index % 3) * 0.045))
                                            }
                                        }
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                        .padding(.bottom, 5)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.string("tutorial.demo_track"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(localization.string("tutorial.demo_artist"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))

                        HStack(spacing: 5) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text(verbatim: "Spotify")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(SongletonTheme.cyan)
                        }
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }

                // Transport Controls
                HStack(spacing: 22) {
                    Image(systemName: "shuffle")
                    Image(systemName: "backward.fill")
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(SongletonTheme.cyan, in: Circle())
                        .shadow(color: SongletonTheme.cyan.opacity(0.5), radius: 8)
                    Image(systemName: "forward.fill")
                    Image(systemName: "repeat")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.86))

                // Volume Bar
                HStack(spacing: 9) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 6)
                        .overlay(alignment: .leading) {
                            Capsule().fill(SongletonTheme.cyan).frame(width: 140)
                        }
                    Text(verbatim: "65%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.76))
            }
            .padding(18)
        }
        .frame(width: 320, height: 260)
        .shadow(color: .black.opacity(0.65), radius: 24, y: 14)
    }
}
