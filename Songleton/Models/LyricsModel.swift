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

    /// Finds the latest lyric line that has started based on playback position and delay compensation offset.
    func activeLineIndex(for position: Double) -> Int? {
        guard !lines.isEmpty else { return nil }

        let offset = SettingsModel.shared.lyricsOffset
        let effectivePosition = position + offset

        // Find the last line where effectivePosition is greater than or equal to timestamp
        for (index, line) in lines.enumerated().reversed() {
            if effectivePosition >= line.timestamp {
                return index
            }
        }
        return 0
    }
}
