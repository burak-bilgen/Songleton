import SwiftUI

// MARK: - MenuBarMainLabelView

struct MenuBarMainLabelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject var settings: SettingsModel
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var artworkScale: CGFloat = 1.0

    private var isPlaying: Bool {
        if case .loaded(let info, _) = model.state {
            return info.isPlaying
        }
        return false
    }

    private var isNotRunning: Bool {
        if case .notRunning = model.state {
            return true
        }
        return false
    }

    private var currentTitle: String {
        model.menuBarTitle ?? localization.string("app.name")
    }

    private var remainingTextWidth: CGFloat {
        max(30, settings.menuBarWidth - 20)
    }

    var body: some View {
        HStack(spacing: 4) {
            if isNotRunning {
                // Clean brand wordmark while no music app is running.
                MarqueeText(
                    text: localization.string("app.name"),
                    font: .custom("Audiowide", size: 11),
                    maxWidth: max(30, settings.menuBarWidth - 8),
                    alignment: .leading
                )
                .foregroundStyle(Color.secondary.opacity(0.55))
                .transition(.opacity)
            } else {
                // Square Album Artwork (Tight next to track title, 4px spacing)
                ZStack {
                    if let artwork = model.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 15, height: 15)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    } else {
                        Image(systemName: isPlaying ? "waveform" : "music.note")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isPlaying ? model.platformAccentColor : .secondary)
                    }
                }
                .frame(width: 15, height: 15)
                .scaleEffect(artworkScale)

                // Track text is centered in the middle.
                MarqueeText(
                    text: currentTitle,
                    font: settings.menuBarFont.font(size: 12),
                    maxWidth: remainingTextWidth,
                    alignment: .center
                )
                .id(currentTitle)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
            }
        }
        .padding(.horizontal, 2)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: currentTitle)
        .animation(.easeInOut(duration: 0.3), value: isNotRunning)
        .onChange(of: currentTitle) { _, _ in
            triggerCuteBounce()
        }
    }

    private func triggerCuteBounce() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            artworkScale = 1.28
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                artworkScale = 1.0
            }
        }
    }
}
