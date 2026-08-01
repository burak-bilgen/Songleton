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

        for i in 0..<(lines.count - 1) {
            if position >= lines[i].timestamp && position < lines[i + 1].timestamp {
                return i
            }
        }
        if let last = lines.last, position >= last.timestamp {
            return lines.count - 1
        }
        return 0
    }
}
