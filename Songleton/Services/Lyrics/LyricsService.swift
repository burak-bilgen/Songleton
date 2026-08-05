import Foundation

final class LyricsService {
    static let shared = AppContainer.shared.lyricsService

    init() {}

    func fetchSyncedLyrics(track: String, artist: String, album: String? = nil, duration: Double? = nil) async -> [LyricLine]? {
        let safeTrack = RemoteResourceSecurity.sanitizedMetadata(track)
        let safeArtist = RemoteResourceSecurity.sanitizedMetadata(artist)
        let safeAlbum = album.map { RemoteResourceSecurity.sanitizedMetadata($0) }
        guard !safeTrack.isEmpty, !safeArtist.isEmpty else { return nil }

        // First try exact fetch with provided track name
        if let result = await fetchFromAPI(track: safeTrack, artist: safeArtist, album: safeAlbum, duration: duration) {
            return result
        }

        // Fallback 1: Try with cleaned track title (removing feat, remaster, live tags)
        let cleanedTrack = Self.cleanTrackTitle(safeTrack)
        if cleanedTrack != safeTrack, let result = await fetchFromAPI(track: cleanedTrack, artist: safeArtist, album: safeAlbum, duration: duration) {
            return result
        }

        // Fallback 2: Search LRCLIB /api/search with query string
        let searchQuery = "\(cleanedTrack) \(safeArtist)"
        if let result = await searchFromAPI(query: searchQuery, duration: duration) {
            return result
        }

        return nil
    }

    static func cleanTrackTitle(_ title: String) -> String {
        var cleaned = title
        // Remove parenthetical & bracketed extras like (feat. X), (Remastered 2021), [Live], - Remastered
        let patterns = [
            "\\(feat\\..*?\\)", "\\(with.*?\\)", "\\(remastered.*?\\)", "\\(live.*?\\)",
            "\\[feat\\..*?\\]", "\\[remastered.*?\\]", "\\[live.*?\\]",
            "\\-.*?remastered.*$", "\\-.*?live.*$"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length), withTemplate: "")
            }
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fetchFromAPI(track: String, artist: String, album: String?, duration: Double?) async -> [LyricLine]? {
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

        return await performLyricsRequest(url: url)
    }

    private func searchFromAPI(query: String, duration: Double?) async -> [LyricLine]? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Songleton macOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 6.0

        do {
            let data = try await SecureRemoteResource.data(for: request, kind: .lyrics)
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !jsonArray.isEmpty else {
                return nil
            }

            // Find best matching search result based on duration if available
            let boundedResults = jsonArray.prefix(100)
            var bestResult: [String: Any]? = boundedResults.first
            if let duration, duration > 0 {
                let closest = boundedResults.min(by: { a, b in
                    let durA = a["duration"] as? Double ?? 0
                    let durB = b["duration"] as? Double ?? 0
                    return abs(durA - duration) < abs(durB - duration)
                })
                if let closest { bestResult = closest }
            }

            if let syncedLrc = bestResult?["syncedLyrics"] as? String, !syncedLrc.isEmpty {
                return Self.parseLRC(syncedLrc)
            } else if let plainLrc = bestResult?["plainLyrics"] as? String, !plainLrc.isEmpty {
                return Self.parsePlainLyrics(plainLrc)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func performLyricsRequest(url: URL) async -> [LyricLine]? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Songleton macOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 6.0

        do {
            let data = try await SecureRemoteResource.data(for: request, kind: .lyrics)
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

        for line in lrcString.components(separatedBy: .newlines).prefix(5_000) {
            let trimmed = String(line.prefix(2_000)).trimmingCharacters(in: .whitespaces)
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

                if let minutes = Double(minStr), let seconds = Double(secStr), seconds < 60 {
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
        for line in plainString.components(separatedBy: .newlines).prefix(5_000) {
            let trimmed = String(line.prefix(2_000)).trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                lines.append(LyricLine(timestamp: dummyTime, text: trimmed))
                dummyTime += 4.0
            }
        }
        return lines
    }
}
