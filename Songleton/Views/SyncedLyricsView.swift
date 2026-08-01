import SwiftUI

// MARK: - SyncedLyricsView (Apple Music Style Glass Karaoke UI)

struct SyncedLyricsView: View {
    @ObservedObject var nowPlaying: NowPlayingModel
    @StateObject private var lyricsModel = LyricsModel.shared

    @State private var isUserScrolling = false
    @State private var userScrollTimer: Task<Void, Never>? = nil

    private var playbackPosition: Double {
        if case .loaded(let info, _) = nowPlaying.state {
            return info.position
        }
        return 0
    }

    var body: some View {
        ZStack {
            // Ambient artwork blur background for lyrics
            if let artwork = nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 36)
                    .opacity(0.18)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if lyricsModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Şarkı sözleri yükleniyor…")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if lyricsModel.lines.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(Color.accentColor.opacity(0.6))
                        Text("Şarkı Sözü Bulunamadı")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Bu parça için senkronize söz kaydı bulunmuyor.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    let activeIndex = lyricsModel.activeLineIndex(for: playbackPosition)

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 12) {
                                Spacer().frame(height: 120)

                                ForEach(Array(lyricsModel.lines.enumerated()), id: \.element.id) { index, line in
                                    let isActive = index == activeIndex

                                    HStack(spacing: 0) {
                                        Text(line.text)
                                            .font(.system(
                                                size: isActive ? 16 : 13,
                                                weight: isActive ? .bold : .medium,
                                                design: .rounded
                                            ))
                                            .foregroundStyle(
                                                isActive
                                                    ? LinearGradient(colors: [.white, .white.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                                                    : LinearGradient(colors: [.primary.opacity(0.5), .primary.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                                            )
                                            .lineSpacing(4)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, isActive ? 8 : 4)
                                            .background(
                                                ZStack {
                                                    if isActive {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(.ultraThinMaterial)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                    .stroke(
                                                                        LinearGradient(
                                                                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.1)],
                                                                            startPoint: .topLeading,
                                                                            endPoint: .bottomTrailing
                                                                        ),
                                                                        lineWidth: 0.75
                                                                    )
                                                            )
                                                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                                    }
                                                }
                                            )
                                            .scaleEffect(isActive ? 1.03 : 1.0, anchor: .leading)
                                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
                                    }
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        nowPlaying.seekTo(line.timestamp)
                                    }
                                }

                                Spacer().frame(height: 140)
                            }
                            .padding(.horizontal, 16)
                        }
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                isUserScrolling = true
                                userScrollTimer?.cancel()
                                userScrollTimer = Task {
                                    try? await Task.sleep(for: .seconds(4.0))
                                    if !Task.isCancelled {
                                        isUserScrolling = false
                                    }
                                }
                            }
                        )
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
