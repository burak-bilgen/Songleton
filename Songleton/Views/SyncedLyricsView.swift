import SwiftUI

struct SyncedLyricsView: View {
    @ObservedObject var nowPlaying: NowPlayingModel
    @StateObject private var lyricsModel = LyricsModel.shared

    @State private var isUserScrolling = false
    @State private var userScrollTimer: Task<Void, Never>? = nil

    private var playbackPosition: Double { nowPlaying.currentPosition }

    var body: some View {
        VStack(spacing: 0) {
            if lyricsModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(NSLocalizedString("Sözler yükleniyor…", comment: "Loading lyrics"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lyricsModel.lines.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(NSLocalizedString("Söz Bulunamadı", comment: "Lyrics not found"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(NSLocalizedString("Bu parça için söz bulunmuyor.", comment: "No synced lyrics available"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let activeIndex = lyricsModel.activeLineIndex(for: playbackPosition)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(lyricsModel.lines.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == activeIndex

                                HStack(spacing: 0) {
                                    Text(line.text)
                                        .font(.system(
                                            size: isActive ? 13 : 11,
                                            weight: isActive ? .bold : .medium,
                                            design: .rounded
                                        ))
                                        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.45))
                                        .lineLimit(nil)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, isActive ? 5 : 3)
                                        .background(
                                            Group {
                                                if isActive {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(Color.white.opacity(0.12))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                                        )
                                                }
                                            }
                                        )
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                                .contentShape(Rectangle())
                                .focusable(false)
                                .onTapGesture { nowPlaying.seekTo(line.timestamp) }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .focusable(false)
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            isUserScrolling = true
                            userScrollTimer?.cancel()
                            userScrollTimer = Task {
                                try? await Task.sleep(for: .seconds(4.0))
                                if !Task.isCancelled { isUserScrolling = false }
                            }
                        }
                    )
                    .onAppear {
                        if let activeIndex {
                            proxy.scrollTo(activeIndex, anchor: .center)
                        }
                    }
                    .onChange(of: activeIndex) { _, newIndex in
                        if let newIndex, !isUserScrolling {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .focusable(false)
        .onAppear { loadLyricsForCurrentTrack() }
        .onChange(of: nowPlaying.menuBarTitle) { _, _ in loadLyricsForCurrentTrack() }
    }

    private func loadLyricsForCurrentTrack() {
        if case .loaded(let info, _) = nowPlaying.state {
            lyricsModel.loadLyrics(track: info.track, artist: info.artist, album: info.album, duration: info.duration)
        }
    }
}
