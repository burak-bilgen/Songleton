import Combine
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Double
    let text: String
}

@MainActor
final class LyricsModel: ObservableObject {
    static let shared = LyricsModel()

    @Published var lines: [LyricLine] = []
    @Published var isLoading = false
    @Published var currentTrackKey: String = ""

    private var loadTask: Task<Void, Never>?

    private init() {}

    func loadLyrics(track: String, artist: String, album: String? = nil, duration: Double? = nil, source: String = "") {
        let key = "\(source)|\(track)|\(artist)|\(album ?? "")"
        guard key != currentTrackKey else { return }

        loadTask?.cancel()
        currentTrackKey = key
        lines = []
        isLoading = true

        loadTask = Task { [weak self] in
            let fetched = await LyricsService.shared.fetchSyncedLyrics(
                track: track,
                artist: artist,
                album: album,
                duration: duration
            )

            guard !Task.isCancelled, let self, self.currentTrackKey == key else {
                return
            }

            self.lines = fetched ?? []
            self.isLoading = false
        }
    }

    func activeLineIndex(for position: Double) -> Int? {
        guard !lines.isEmpty else { return nil }
        let effectivePosition = position + SettingsModel.shared.lyricsOffset
        guard effectivePosition >= lines[0].timestamp else { return nil }
        for (index, line) in lines.enumerated().reversed() {
            if effectivePosition >= line.timestamp {
                return index
            }
        }
        return 0
    }
}
