import AppKit

final class YouTubeController: MediaController {
    let bundleID = "com.google.Chrome" // General web browser target indicator
    let displayName = "YouTube"
    var scriptAppName: String { "YouTube" }

    // List of supported web browsers to inspect for YouTube tabs
    private struct BrowserTarget {
        let bundleID: String
        let name: String
        let kind: BrowserKind
    }

    private enum BrowserKind {
        case chromeStyle
        case safariStyle
    }

    private let supportedBrowsers: [BrowserTarget] = [
        BrowserTarget(bundleID: "com.google.Chrome", name: "Google Chrome", kind: .chromeStyle),
        BrowserTarget(bundleID: "company.thebrowser.Browser", name: "Arc", kind: .chromeStyle),
        BrowserTarget(bundleID: "com.brave.Browser", name: "Brave Browser", kind: .chromeStyle),
        BrowserTarget(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge", kind: .chromeStyle),
        BrowserTarget(bundleID: "com.apple.Safari", name: "Safari", kind: .safariStyle)
    ]

    private var activeBrowser: BrowserTarget? {
        supportedBrowsers.first { target in
            !NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).isEmpty
        }
    }

    var isRunning: Bool {
        activeBrowser != nil
    }

    nonisolated func fetchNowPlaying() throws -> NowPlayingInfo {
        // Attempt to find YouTube tab across running browsers
        let script = """
        -- Safari Check
        if application "Safari" is running then
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            set tabTitle to name of t
                            set tabUrl to URL of t
                            return {"Safari", tabTitle, tabUrl}
                        end if
                    end repeat
                end repeat
            end tell
        end if

        -- Chrome / Arc / Brave / Edge Check
        set chromeApps to {"Google Chrome", "Arc", "Brave Browser", "Microsoft Edge"}
        repeat with appName in chromeApps
            try
                if application appName is running then
                    using terms from application "Google Chrome"
                        tell application appName
                            repeat with w in windows
                                repeat with t in tabs of w
                                    if URL of t contains "youtube.com" then
                                        set tabTitle to title of t
                                        set tabUrl to URL of t
                                        return {appName, tabTitle, tabUrl}
                                    end if
                                end repeat
                            end repeat
                        end tell
                    end using terms from
                end if
            end try
        end repeat

        return {"none", "", ""}
        """

        let res = try AppleScriptRunner.run(script)
        guard let browserName = res.atIndex(1)?.stringValue, browserName != "none",
              let rawTitle = res.atIndex(2)?.stringValue, !rawTitle.isEmpty else {
            throw MediaControllerError.appNotRunning
        }

        // Parse YouTube Title
        let (track, artist) = parseYouTubeTitle(rawTitle)

        return NowPlayingInfo(
            track: track,
            artist: artist.isEmpty ? "YouTube" : artist,
            album: "YouTube Music",
            isPlaying: true, // Active YouTube stream assumption
            volume: 80,
            artworkURL: nil,
            artworkData: nil,
            position: 0,
            duration: 0,
            isShuffleEnabled: false,
            repeatMode: .off
        )
    }

    private nonisolated func parseYouTubeTitle(_ rawTitle: String) -> (track: String, artist: String) {
        var cleanTitle = rawTitle
            .replacingOccurrences(of: " - YouTube Music", with: "")
            .replacingOccurrences(of: " - YouTube", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip notifications count like "(3) Track Name"
        if let range = cleanTitle.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) {
            cleanTitle.removeSubrange(range)
        }

        // If title contains " - ", split artist and track
        let components = cleanTitle.components(separatedBy: " - ")
        if components.count >= 2 {
            let artist = components[0].trimmingCharacters(in: .whitespaces)
            let track = components[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            return (track, artist)
        }

        return (cleanTitle, "YouTube")
    }

    nonisolated func togglePlayPause() throws {
        try executeJavaScriptInYouTubeTab("var v = document.querySelector('video'); if (v) { v.paused ? v.play() : v.pause(); }")
    }

    nonisolated func nextTrack() throws {
        try executeJavaScriptInYouTubeTab("""
        var nextBtn = document.querySelector('.ytp-next-button') || document.querySelector('.next-button');
        if (nextBtn) { nextBtn.click(); }
        """)
    }

    nonisolated func previousTrack() throws {
        try executeJavaScriptInYouTubeTab("""
        var prevBtn = document.querySelector('.ytp-prev-button') || document.querySelector('.previous-button');
        if (prevBtn) { prevBtn.click(); } else { history.back(); }
        """)
    }

    nonisolated func restartTrack() throws {
        try executeJavaScriptInYouTubeTab("var v = document.querySelector('video'); if (v) { v.currentTime = 0; }")
    }

    nonisolated func setVolume(_ volume: Int) throws {
        let normalized = Double(volume) / 100.0
        try executeJavaScriptInYouTubeTab("var v = document.querySelector('video'); if (v) { v.volume = \(normalized); }")
    }

    nonisolated func seekTo(_ position: Double) throws {
        try executeJavaScriptInYouTubeTab("var v = document.querySelector('video'); if (v) { v.currentTime = \(position); }")
    }

    nonisolated func toggleShuffle() throws {}
    nonisolated func setRepeatMode(_ mode: RepeatMode) throws {}

    private nonisolated func executeJavaScriptInYouTubeTab(_ jsCode: String) throws {
        let script = """
        -- Safari
        if application "Safari" is running then
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            do JavaScript "\(jsCode)" in t
                            return
                        end if
                    end repeat
                end repeat
            end tell
        end if

        -- Chromium Browsers
        set chromeApps to {"Google Chrome", "Arc", "Brave Browser", "Microsoft Edge"}
        repeat with appName in chromeApps
            try
                if application appName is running then
                    using terms from application "Google Chrome"
                        tell application appName
                            repeat with w in windows
                                repeat with t in tabs of w
                                    if URL of t contains "youtube.com" then
                                        execute t javascript "\(jsCode)"
                                        return
                                    end if
                                end repeat
                            end repeat
                        end tell
                    end using terms from
                end if
            end try
        end repeat
        """
        try AppleScriptRunner.run(script)
    }
}
