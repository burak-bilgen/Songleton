import SwiftUI

// MARK: - MenuBarMainLabelView (Unified Control Bar View)

struct MenuBarMainLabelView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject var settings: SettingsModel

    var onPrevious: () -> Void
    var onNext: () -> Void
    var onOpenPanel: () -> Void

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
        HStack(spacing: 6) {
            // 1. Geri Butonu [⏮]
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 22)
            .help("Önceki Şarkı")

            // 2. Orta Alan: Albüm Kapağı + Kayan Metin (Tıklanınca Oynatıcı Paneli Açılır)
            Button(action: onOpenPanel) {
                HStack(spacing: 5) {
                    // Albüm Kapağı (16x16)
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
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        } else {
                            Image(systemName: isPlaying ? "waveform" : "music.note")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isPlaying ? Color.accentColor : .secondary)
                                .symbolEffect(.bounce, value: isPlaying)
                        }
                    }
                    .frame(width: 16, height: 16)
                    .scaleEffect(artworkScale)

                    // Şarkı / Sanatçı Kayan Metni
                    MarqueeText(
                        text: currentTitle,
                        font: settings.menuBarFont.font(size: 12),
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
                .frame(width: settings.menuBarWidth + 22, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Oynatıcıyı Aç")

            // 3. İleri Butonu [⏭]
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 22)
            .help("Sonraki Şarkı")
        }
        .padding(.horizontal, 4)
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
