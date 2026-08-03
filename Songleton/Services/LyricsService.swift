import Foundation

final class LyricsService {
    static let shared = LyricsService()

    private init() {}

    func fetchSyncedLyrics(track: String, artist: String, album: String? = nil, duration: Double? = nil) async -> [LyricLine]? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if let album, !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if let duration, duration.isFinite, duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(min(duration, 7 * 24 * 60 * 60)))))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Songleton macOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let syncedLrc = json?["syncedLyrics"] as? String, !syncedLrc.isEmpty {
                return Self.parseLRC(syncedLrc)
            } else if let plainLrc = json?["plainLyrics"] as? String, !plainLrc.isEmpty {
                return Self.parsePlainLyrics(plainLrc)
            }
        } catch {
            return nil
        }
        return nil
    }

    static func parseLRC(_ lrcString: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        let tagPattern = "\\[(\\d{1,2}):(\\d{2})(?:[\\.\\:](\\d{1,3}))?\\]"
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern) else { return [] }

        let metadataPrefixes = ["[ar:", "[ti:", "[al:", "[by:", "[length:"]

        for line in lrcString.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if metadataPrefixes.contains(where: { trimmed.hasPrefix($0) }) { continue }

            let nsString = trimmed as NSString
            let matches = tagRegex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
            if matches.isEmpty { continue }

            guard let lastMatch = matches.last else { continue }
            let textStartIndex = lastMatch.range.location + lastMatch.range.length
            let lyricText = nsString.substring(from: textStartIndex).trimmingCharacters(in: .whitespaces)
            if lyricText.isEmpty { continue }

            for match in matches {
                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))

                var msSeconds = 0.0
                if match.numberOfRanges >= 4 && match.range(at: 3).location != NSNotFound {
                    let msStr = nsString.substring(with: match.range(at: 3))
                    if let msVal = Double(msStr) {
                        if msStr.count == 1 { msSeconds = msVal / 10.0 }
                        else if msStr.count == 2 { msSeconds = msVal / 100.0 }
                        else { msSeconds = msVal / 1000.0 }
                    }
                }

                if let minutes = Double(minStr), let seconds = Double(secStr) {
                    let totalSeconds = minutes * 60.0 + seconds + msSeconds
                    lines.append(LyricLine(timestamp: totalSeconds, text: lyricText))
                }
            }
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }

    static func parsePlainLyrics(_ plainString: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        var dummyTime = 0.0
        for line in plainString.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                lines.append(LyricLine(timestamp: dummyTime, text: trimmed))
                dummyTime += 4.0
            }
        }
        return lines
    }
}
