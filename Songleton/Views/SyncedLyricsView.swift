import SwiftUI

// MARK: - SyncedLyricsView (Apple Music Style Glass Karaoke UI)

struct SyncedLyricsView: View {
    @ObservedObject var nowPlaying: NowPlayingModel
    @StateObject private var lyricsModel = LyricsModel.shared

    @State private var isUserScrolling = false
    @State private var userScrollTimer: Task<Void, Never>? = nil

    private var playbackPosition: Double {
        nowPlaying.currentPosition
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
                            .foregroundStyle(.secondary.opacity(0.6))
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
                            VStack(alignment: .leading, spacing: 10) {
                                Spacer().frame(height: 110)

                                ForEach(Array(lyricsModel.lines.enumerated()), id: \.element.id) { index, line in
                                    let isActive = index == activeIndex

                                    HStack(spacing: 0) {
                                        Text(line.text)
                                            .font(.system(
                                                size: isActive ? 15 : 13,
                                                weight: isActive ? .bold : .medium,
                                                design: .rounded
                                            ))
                                            .foregroundStyle(
                                                isActive
                                                    ? LinearGradient(colors: [.white, .white.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                                                    : LinearGradient(colors: [.primary.opacity(0.5), .primary.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                                            )
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .lineSpacing(3)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, isActive ? 7 : 4)
                                            .background(
                                                ZStack {
                                                    if isActive {
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .fill(.ultraThinMaterial)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                    .stroke(
                                                                        LinearGradient(
                                                                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.1)],
                                                                            startPoint: .topLeading,
                                                                            endPoint: .bottomTrailing
                                                                        ),
                                                                        lineWidth: 0.75
                                                                    )
                                                            )
                                                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                                                    }
                                                }
                                            )
                                            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
                                    }
                                    .frame(maxWidth: 310, alignment: .leading)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .focusable(false)
                                    .onTapGesture {
                                        nowPlaying.seekTo(line.timestamp)
                                    }
                                }

                                Spacer().frame(height: 130)
                            }
                            .padding(.horizontal, 14)
                        }
                        .focusable(false)
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
                        .onChange(of: lyricsModel.lines) { _, newLines in
                            if !newLines.isEmpty, let activeIndex {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    proxy.scrollTo(activeIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 350)
        .clipped()
        .focusable(false)
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
