import Combine
import Foundation

// MARK: - LyricsModel

@MainActor
final class LyricsModel: ObservableObject {
    static let shared = LyricsModel()

    @Published var lines: [LyricLine] = []
    @Published var isLoading = false
    @Published var currentTrackKey: String = ""

    private init() {}

    func loadLyrics(track: String, artist: String, album: String? = nil, duration: Double? = nil) {
        let key = "\(track)|\(artist)"
        guard key != currentTrackKey else { return }

        currentTrackKey = key
        lines = []
        isLoading = true

        Task {
            if let fetched = await LyricsService.shared.fetchSyncedLyrics(
                track: track,
                artist: artist,
                album: album,
                duration: duration
            ) {
                self.lines = fetched
            } else {
                self.lines = []
            }
            self.isLoading = false
        }
    }

    func activeLineIndex(for position: Double) -> Int? {
        guard !lines.isEmpty else { return nil }

        for (index, line) in lines.enumerated().reversed() {
            if position >= line.timestamp - 0.3 {
                return index
            }
        }
        return 0
    }
}
