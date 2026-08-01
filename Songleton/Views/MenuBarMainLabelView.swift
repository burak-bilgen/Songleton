import SwiftUI

// MARK: - MenuBarMainLabelView

struct MenuBarMainLabelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject var settings: SettingsModel

    @State private var artworkScale: CGFloat = 1.0

    private var isPlaying: Bool {
        if case .loaded(let info, _) = model.state {
            return info.isPlaying
        }
        return false
    }

    private var currentTitle: String {
        model.menuBarTitle ?? "Songleton"
    }

    var body: some View {
        HStack(spacing: 5) {
            // Albüm Kapağı Görseli (16x16) ile tatlı zıplama efekti
            ZStack {
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                } else {
                    Image(systemName: isPlaying ? "waveform" : "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isPlaying ? Color.accentColor : .secondary)
                        .symbolEffect(.bounce, value: isPlaying)
                }
            }
            .frame(width: 16, height: 16)
            .scaleEffect(artworkScale)

            // Şarkı değiştiğinde yukarıdan düşen ve tatlıca zıplayan metin
            MarqueeText(
                text: currentTitle,
                font: settings.menuBarFont.font(size: 13),
                maxWidth: settings.menuBarWidth
            )
            .id(currentTitle)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                )
            )
        }
        .frame(maxWidth: settings.menuBarWidth, alignment: .leading)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: currentTitle)
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
