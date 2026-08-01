import AppKit
import SwiftUI

// MARK: - MenuBarUnifiedStackView

struct MenuBarUnifiedStackView: View {
    @ObservedObject var model: NowPlayingModel
    @ObservedObject var settings: SettingsModel
    let onTogglePanel: () -> Void

    @State private var isAnimatingFeedback = false
    @State private var feedbackIsPlaying = false

    private var isPlaying: Bool {
        if case .loaded(let info, _) = model.state {
            return info.isPlaying
        }
        return false
    }

    var body: some View {
        HStack(spacing: 5) {
            // 1. Önceki Şarkı (Backward)
            Button(action: { model.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 16, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Önceki Şarkı")

            // 2. Ortadaki Şarkı Adı & Tıklayınca Durdur / Başlat
            Button(action: {
                let currentIsPlaying = isPlaying
                model.togglePlayPause()
                triggerPlayPauseAnimation(wasPlaying: currentIsPlaying)
            }) {
                HStack(spacing: 5) {
                    // Albüm Kapağı veya Animasyonlu Oynat / Duraklat Göstergesi
                    ZStack {
                        if isAnimatingFeedback {
                            Image(systemName: feedbackIsPlaying ? "play.fill" : "pause.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .transition(.scale.combined(with: .opacity))
                        } else if let artwork = model.artwork {
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
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Tıklayın: Oynat / Duraklat")

            // 3. Sonraki Şarkı (Forward)
            Button(action: { model.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 16, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Sonraki Şarkı")

            // 4. Oynatıcı Paneli Aç / Kapat (Panel Toggle)
            Button(action: onTogglePanel) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Oynatıcı Paneli")
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
    }

    private func triggerPlayPauseAnimation(wasPlaying: Bool) {
        feedbackIsPlaying = !wasPlaying
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isAnimatingFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimatingFeedback = false
            }
        }
    }
}
