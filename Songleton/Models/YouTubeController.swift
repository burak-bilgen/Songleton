import AppKit

final class YouTubeController: MediaController {
    let bundleID = "com.google.Chrome"
    let displayName = "YouTube"
    var scriptAppName: String { "YouTube" }

    private struct BrowserInfo {
        let bundleID: String
        let name: String
    }

    // Supported browsers to scan dynamically
    private let browserTargets: [BrowserInfo] = [
        BrowserInfo(bundleID: "com.brave.Browser", name: "Brave"),
        BrowserInfo(bundleID: "com.google.Chrome", name: "Google Chrome"),
        BrowserInfo(bundleID: "company.thebrowser.Browser", name: "Arc"),
        BrowserInfo(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge"),
        BrowserInfo(bundleID: "com.apple.Safari", name: "Safari")
    ]

    private var activeRunningBrowser: BrowserInfo? {
        browserTargets.first { target in
            !NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).isEmpty
        }
    }

    var isRunning: Bool {
        activeRunningBrowser != nil
    }

    nonisolated func fetchNowPlaying() throws -> NowPlayingInfo {
        guard let runningBrowser = getRunningBrowser() else {
            throw MediaControllerError.appNotRunning
        }

        let isSafari = runningBrowser.bundleID == "com.apple.Safari"

        let script: String
        if isSafari {
            script = """
            tell application id "com.apple.Safari"
                if (count of windows) > 0 then
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "youtube.com" then
                                set tabTitle to name of t
                                return tabTitle
                            end if
                        end repeat
                    end repeat
                end if
            end tell
            return ""
            """
        } else {
            // Chromium based (Brave, Chrome, Arc, Edge) using generic AppleScript ID call
            script = """
            tell application id "\(runningBrowser.bundleID)"
                if (count of windows) > 0 then
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "youtube.com" then
                                set tabTitle to title of t
                                return tabTitle
                            end if
                        end repeat
                    end repeat
                end if
            end tell
            return ""
            """
        }

        let res = try AppleScriptRunner.run(script)
        guard let rawTitle = res.stringValue, !rawTitle.isEmpty else {
            throw MediaControllerError.appNotRunning
        }

        let (track, artist) = parseYouTubeTitle(rawTitle)

        return NowPlayingInfo(
            track: track,
            artist: artist,
            album: "",
            isPlaying: true,
            volume: 80,
            artworkURL: nil,
            artworkData: nil,
            position: 0,
            duration: 0,
            isShuffleEnabled: false,
            repeatMode: .off
        )
    }

    private nonisolated func getRunningBrowser() -> BrowserInfo? {
        let targets = [
            BrowserInfo(bundleID: "com.brave.Browser", name: "Brave"),
            BrowserInfo(bundleID: "com.google.Chrome", name: "Google Chrome"),
            BrowserInfo(bundleID: "company.thebrowser.Browser", name: "Arc"),
            BrowserInfo(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge"),
            BrowserInfo(bundleID: "com.apple.Safari", name: "Safari")
        ]
        return targets.first { target in
            !NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).isEmpty
        }
    }

    private nonisolated func parseYouTubeTitle(_ rawTitle: String) -> (track: String, artist: String) {
        var cleanTitle = rawTitle
            .replacingOccurrences(of: "- YouTube Music", with: "")
            .replacingOccurrences(of: "- YouTube", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip notifications count like "(3) Track Name"
        if let range = cleanTitle.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) {
            cleanTitle.removeSubrange(range)
        }

        let components = cleanTitle.components(separatedBy: " - ")
        if components.count >= 2 {
            let artist = components[0].trimmingCharacters(in: .whitespaces)
            let track = components[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            return (track, artist)
        }

        return (cleanTitle, "")
    }

    nonisolated func togglePlayPause() throws {
        try executeJSInActiveBrowser("var v = document.querySelector('video'); if (v) { v.paused ? v.play() : v.pause(); }")
    }

    nonisolated func nextTrack() throws {
        try executeJSInActiveBrowser("var btn = document.querySelector('.ytp-next-button') || document.querySelector('.next-button'); if (btn) { btn.click(); }")
    }

    nonisolated func previousTrack() throws {
        try executeJSInActiveBrowser("var btn = document.querySelector('.ytp-prev-button') || document.querySelector('.previous-button'); if (btn) { btn.click(); } else { history.back(); }")
    }

    nonisolated func restartTrack() throws {
        try executeJSInActiveBrowser("var v = document.querySelector('video'); if (v) { v.currentTime = 0; }")
    }

    nonisolated func setVolume(_ volume: Int) throws {
        let normalized = Double(volume) / 100.0
        try executeJSInActiveBrowser("var v = document.querySelector('video'); if (v) { v.volume = \(normalized); }")
    }

    nonisolated func seekTo(_ position: Double) throws {
        try executeJSInActiveBrowser("var v = document.querySelector('video'); if (v) { v.currentTime = \(position); }")
    }

    nonisolated func toggleShuffle() throws {}
    nonisolated func setRepeatMode(_ mode: RepeatMode) throws {}

    private nonisolated func executeJSInActiveBrowser(_ jsCode: String) throws {
        guard let browser = getRunningBrowser() else { return }
        let isSafari = browser.bundleID == "com.apple.Safari"

        let script: String
        if isSafari {
            script = """
            tell application id "com.apple.Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            do JavaScript "\(jsCode)" in t
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
        } else {
            script = """
            tell application id "\(browser.bundleID)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            execute t javascript "\(jsCode)"
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
        }
        try AppleScriptRunner.run(script)
    }
}
