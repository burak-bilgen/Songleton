import Foundation

// MARK: - LyricLine

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Double // seconds
    let text: String
}

// MARK: - LyricsService

final class LyricsService {
    static let shared = LyricsService()

    private init() {}

    func fetchSyncedLyrics(track: String, artist: String, album: String? = nil, duration: Double? = nil) async -> [LyricLine]? {
        guard let encodedTrack = track.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        var urlString = "https://lrclib.net/api/get?track_name=\(encodedTrack)&artist_name=\(encodedArtist)"
        if let album, let encodedAlbum = album.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), !album.isEmpty {
            urlString += "&album_name=\(encodedAlbum)"
        }
        if let duration, duration > 0 {
            urlString += "&duration=\(Int(duration))"
        }

        guard let url = URL(string: urlString) else { return nil }

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
                return parseLRC(syncedLrc)
            } else if let plainLrc = json?["plainLyrics"] as? String, !plainLrc.isEmpty {
                return parsePlainLyrics(plainLrc)
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Robust LRC Parser matching any standard or non-standard timestamp:
    /// e.g. [01:23.45], [1:23.4], [01:23:45], [01:23]
    private func parseLRC(_ lrcString: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        // Match [mm:ss.xx], [m:ss.x], [mm:ss:xx], [mm:ss]
        let pattern = "\\[(\\d{1,2}):(\\d{2})(?:[\\.\\:](\\d{1,3}))?\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let rawLines = lrcString.components(separatedBy: .newlines)
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Skip metadata tags like [ar:Artist], [ti:Title], [al:Album], [by:...]
            if trimmed.hasPrefix("[ar:") || trimmed.hasPrefix("[ti:") || trimmed.hasPrefix("[al:") || trimmed.hasPrefix("[by:") || trimmed.hasPrefix("[length:") {
                continue
            }

            let nsString = trimmed as NSString
            let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if match.numberOfRanges >= 3 {
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))

                    var msSeconds = 0.0
                    if match.numberOfRanges >= 4 && match.range(at: 3).location != NSNotFound {
                        let msStr = nsString.substring(with: match.range(at: 3))
                        if let msVal = Double(msStr) {
                            if msStr.count == 1 {
                                msSeconds = msVal / 10.0
                            } else if msStr.count == 2 {
                                msSeconds = msVal / 100.0
                            } else {
                                msSeconds = msVal / 1000.0
                            }
                        }
                    }

                    var lyricText = ""
                    if match.numberOfRanges >= 5 && match.range(at: 4).location != NSNotFound {
                        lyricText = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                    }

                    if let minutes = Double(minStr), let seconds = Double(secStr) {
                        let totalSeconds = minutes * 60.0 + seconds + msSeconds
                        // Keep line even if music note symbol ♪
                        if !lyricText.isEmpty {
                            lines.append(LyricLine(timestamp: totalSeconds, text: lyricText))
                        }
                    }
                }
            }
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }

    private func parsePlainLyrics(_ plainString: String) -> [LyricLine] {
        let rawLines = plainString.components(separatedBy: .newlines)
        var lines: [LyricLine] = []
        var dummyTime = 0.0
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                lines.append(LyricLine(timestamp: dummyTime, text: trimmed))
                dummyTime += 4.0
            }
        }
        return lines
    }
}
