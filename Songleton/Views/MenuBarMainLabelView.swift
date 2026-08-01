import SwiftUI

// MARK: - MenuBarMainLabelView

struct MenuBarMainLabelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject var settings: SettingsModel

    private var isPlaying: Bool {
        if case .loaded(let info, _) = model.state {
            return info.isPlaying
        }
        return false
    }

    var body: some View {
        HStack(spacing: 5) {
            // Albüm Kapağı Görseli (16x16)
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

            // Kayan Şarkı Metni
            MarqueeText(
                text: model.menuBarTitle ?? "Songleton",
                font: settings.menuBarFont.font(size: 13),
                maxWidth: settings.menuBarWidth
            )
        }
        .frame(maxWidth: settings.menuBarWidth, alignment: .leading)
    }
}
