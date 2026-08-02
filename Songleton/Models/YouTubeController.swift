import AppKit
import CoreGraphics

final class YouTubeController: MediaController {
    let bundleID = "com.google.Chrome"
    let displayName = "YouTube"
    var scriptAppName: String { "YouTube" }

    private struct BrowserInfo {
        let bundleID: String
        let name: String
    }

    private let browserTargets: [BrowserInfo] = [
        BrowserInfo(bundleID: "com.brave.Browser", name: "Brave"),
        BrowserInfo(bundleID: "com.google.Chrome", name: "Google Chrome"),
        BrowserInfo(bundleID: "company.thebrowser.Browser", name: "Arc"),
        BrowserInfo(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge"),
        BrowserInfo(bundleID: "com.apple.Safari", name: "Safari")
    ]

    private var activeRunningBrowser: BrowserInfo? {
        getRunningBrowser()
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

    // MARK: - Zero-Permission Hardware System Media Key Simulation

    nonisolated func togglePlayPause() throws {
        sendSystemMediaKey(NX_KEYTYPE_PLAY)
    }

    nonisolated func nextTrack() throws {
        sendSystemMediaKey(NX_KEYTYPE_NEXT)
    }

    nonisolated func previousTrack() throws {
        sendSystemMediaKey(NX_KEYTYPE_PREVIOUS)
    }

    nonisolated func restartTrack() throws {
        sendSystemMediaKey(NX_KEYTYPE_PREVIOUS)
    }

    nonisolated func setVolume(_ volume: Int) throws {}
    nonisolated func seekTo(_ position: Double) throws {}
    nonisolated func toggleShuffle() throws {}
    nonisolated func setRepeatMode(_ mode: RepeatMode) throws {}

    /// Simulates macOS system media key event (Play/Pause, Next, Prev) requiring ZERO browser settings or developer permissions.
    private nonisolated func sendSystemMediaKey(_ key: Int32) {
        func postKey(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            ev?.cgEvent?.post(tap: .cghidEventTap)
        }
        postKey(down: true)
        postKey(down: false)
    }
}
