import SwiftUI

// MARK: - SyncedLyricsView

struct SyncedLyricsView: View {
    @ObservedObject var nowPlaying: NowPlayingModel
    @StateObject private var lyricsModel = LyricsModel.shared

    private var playbackPosition: Double {
        if case .loaded(let info, _) = nowPlaying.state {
            return info.position
        }
        return 0
    }

    var body: some View {
        VStack(spacing: 0) {
            if lyricsModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Şarkı sözleri yükleniyor…")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else if lyricsModel.lines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("Şarkı sözü bulunamadı")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Bu parça için senkronize söz kaydı yok.")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                let activeIndex = lyricsModel.activeLineIndex(for: playbackPosition)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            Spacer().frame(height: 120)

                            ForEach(Array(lyricsModel.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == activeIndex

                                Text(line.text)
                                    .font(.system(
                                        size: isActive ? 16 : 13,
                                        weight: isActive ? .bold : .medium,
                                        design: .rounded
                                    ))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                                    .opacity(isActive ? 1.0 : (index < (activeIndex ?? 0) ? 0.35 : 0.5))
                                    .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                    .blur(radius: isActive ? 0 : 0.4)
                                    .shadow(color: isActive ? Color.accentColor.opacity(0.4) : .clear, radius: 4)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
                                    .id(index)
                                    .onTapGesture {
                                        nowPlaying.seekTo(line.timestamp)
                                    }
                            }

                            Spacer().frame(height: 140)
                        }
                        .padding(.horizontal, 20)
                    }
                    .onChange(of: activeIndex) { _, newIndex in
                        if let newIndex {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadLyricsForCurrentTrack()
        }
        .onChange(of: nowPlaying.menuBarTitle) { _, _ in
            loadLyricsForCurrentTrack()
        }
    }

    private func loadLyricsForCurrentTrack() {
        if case .loaded(let info, _) = nowPlaying.state {
            lyricsModel.loadLyrics(
                track: info.track,
                artist: info.artist,
                album: info.album,
                duration: info.duration
            )
        }
    }
}
