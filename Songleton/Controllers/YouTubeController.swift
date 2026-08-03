import AppKit
import CoreGraphics

final class YouTubeController: MediaController {
    let bundleID = "com.google.Chrome"
    nonisolated var displayName: String { activeBrowserName ?? "Browser" }
    var scriptAppName: String { "Google Chrome" }

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

    var isRunning: Bool {
        browserTargets.contains { isBrowserRunning($0) }
    }

    nonisolated var activeBundleID: String? {
        try? browserWithYouTubeTab()?.bundleID
    }

    nonisolated var activeBrowserName: String? {
        try? browserWithYouTubeTab()?.name
    }

    nonisolated func fetchNowPlaying() throws -> NowPlayingInfo {
        var permissionDenied = false

        for browser in browserTargets where isBrowserRunning(browser) {
            do {
                return try fetchNowPlaying(from: browser)
            } catch MediaControllerError.permissionDenied {
                permissionDenied = true
            } catch {
                continue
            }
        }

        if permissionDenied { throw MediaControllerError.permissionDenied }
        throw MediaControllerError.appNotRunning
    }

    private nonisolated func fetchNowPlaying(from browser: BrowserInfo) throws -> NowPlayingInfo {
        let javascript = """
        (function() {
            var v = document.querySelector('video');
            var p = document.getElementById('movie_player');
            var volume = p && typeof p.getVolume === 'function' ? p.getVolume() : (v ? v.volume * 100 : 0);
            return JSON.stringify({
                paused: v ? v.paused : true,
                currentTime: v && Number.isFinite(v.currentTime) ? v.currentTime : 0,
                duration: v && Number.isFinite(v.duration) ? v.duration : 0,
                volume: Number.isFinite(volume) ? volume : 0
            });
        })();
        """
        let escapedJS = escapeForAppleScript(javascript)
        let titleProperty = browser.bundleID == "com.apple.Safari" ? "name" : "title"
        let javascriptCommand = browser.bundleID == "com.apple.Safari"
            ? "do JavaScript \"\(escapedJS)\" in t"
            : "execute t javascript \"\(escapedJS)\""

        let script = """
        tell application id "\(browser.bundleID)"
            if (count of windows) > 0 then
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            set tabTitle to \(titleProperty) of t
                            set playerState to \(javascriptCommand)
                            return {tabTitle, playerState}
                        end if
                    end repeat
                end repeat
            end if
        end tell
        return {"", ""}
        """

        let result: NSAppleEventDescriptor
        do {
            result = try AppleScriptRunner.run(script)
        } catch MediaControllerError.scriptFailed(let message) where isJavaScriptAutomationError(message) {
            return try fetchTitleFallback(from: browser)
        }
        guard let rawTitle = result.atIndex(1)?.stringValue, !rawTitle.isEmpty,
              let stateString = result.atIndex(2)?.stringValue,
              let stateData = stateString.data(using: .utf8),
              let state = try? JSONSerialization.jsonObject(with: stateData) as? [String: Any] else {
            throw MediaControllerError.appNotRunning
        }

        let isPlaying = !(state["paused"] as? Bool ?? true)
        let position = MediaValue.position(state["currentTime"] as? Double ?? 0)
        let duration = MediaValue.duration(state["duration"] as? Double ?? 0)
        let volume = MediaValue.volume(state["volume"] as? Double ?? 0)
        let (track, artist) = parseYouTubeTitle(rawTitle)

        return NowPlayingInfo(
            track: track,
            artist: artist,
            album: "",
            isPlaying: isPlaying,
            volume: volume,
            artworkURL: nil,
            artworkData: nil,
            position: position,
            duration: duration,
            isShuffleEnabled: false,
            repeatMode: .off
        )
    }

    private nonisolated func fetchTitleFallback(from browser: BrowserInfo) throws -> NowPlayingInfo {
        let titleScript = """
        tell application id "\(browser.bundleID)"
            if (count of windows) > 0 then
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then return title of t
                    end repeat
                end repeat
            end if
        end tell
        return ""
        """
        let result = try AppleScriptRunner.run(titleScript)
        guard let rawTitle = result.stringValue, !rawTitle.isEmpty else {
            throw MediaControllerError.appNotRunning
        }

        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isPlaying = frontmostBundleID == browser.bundleID
        let (track, artist) = parseYouTubeTitle(rawTitle)
        return NowPlayingInfo(
            track: track,
            artist: artist,
            album: "",
            isPlaying: isPlaying,
            volume: 80,
            artworkURL: nil,
            artworkData: nil,
            position: 0,
            duration: 0,
            isShuffleEnabled: false,
            repeatMode: .off
        )
    }

    nonisolated func isJavaScriptAutomationError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("javascript") &&
            (normalized.contains("apple events") || normalized.contains("applescript") || normalized.contains("turned off"))
    }

    private nonisolated func isBrowserRunning(_ browser: BrowserInfo) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleID).isEmpty
    }

    private nonisolated func browserWithYouTubeTab() throws -> BrowserInfo? {
        for browser in browserTargets where isBrowserRunning(browser) {
            let script = """
            tell application id "\(browser.bundleID)"
                if (count of windows) > 0 then
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "youtube.com" then return true
                        end repeat
                    end repeat
                end if
            end tell
            return false
            """

            do {
                if try AppleScriptRunner.run(script).booleanValue { return browser }
            } catch MediaControllerError.permissionDenied {
                throw MediaControllerError.permissionDenied
            } catch {
                continue
            }
        }
        return nil
    }

    nonisolated func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    nonisolated func parseYouTubeTitle(_ rawTitle: String) -> (track: String, artist: String) {
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

    nonisolated func togglePlayPause() throws {
        let js = """
        (function() {
            var p = document.getElementById('movie_player');
            if (p && typeof p.getPlayerState === 'function') {
                var s = p.getPlayerState();
                if (s === 1) { p.pauseVideo(); } else { p.playVideo(); }
            } else {
                var v = document.querySelector('video');
                if (v) { v.paused ? v.play() : v.pause(); }
            }
        })();
        """
        do {
            try executeJSInActiveBrowser(js)
        } catch MediaControllerError.scriptFailed(let message) where isJavaScriptAutomationError(message) {
            guard sendSystemMediaKey(16) else { throw MediaControllerError.scriptFailed("Unable to post play/pause media key") }
        }
    }

    nonisolated func nextTrack() throws {
        let js = """
        (function() {
            var p = document.getElementById('movie_player');
            if (p && typeof p.nextVideo === 'function') { p.nextVideo(); }
            else {
                var btn = document.querySelector('.ytp-next-button') || document.querySelector('.next-button');
                if (btn) btn.click();
            }
        })();
        """
        do {
            try executeJSInActiveBrowser(js)
        } catch MediaControllerError.scriptFailed(let message) where isJavaScriptAutomationError(message) {
            guard sendSystemMediaKey(17) else { throw MediaControllerError.scriptFailed("Unable to post next media key") }
        }
    }

    nonisolated func previousTrack() throws {
        let js = """
        (function() {
            var p = document.getElementById('movie_player');
            if (p && typeof p.previousVideo === 'function') { p.previousVideo(); }
            else {
                var btn = document.querySelector('.ytp-prev-button') || document.querySelector('.previous-button');
                if (btn) btn.click();
            }
        })();
        """
        do {
            try executeJSInActiveBrowser(js)
        } catch MediaControllerError.scriptFailed(let message) where isJavaScriptAutomationError(message) {
            guard sendSystemMediaKey(18) else { throw MediaControllerError.scriptFailed("Unable to post previous media key") }
        }
    }

    nonisolated func setVolume(_ volume: Int) throws {
        let safeVolume = min(100, max(0, volume))
        let js = """
        (function() {
            var p = document.getElementById('movie_player');
            if (p && typeof p.setVolume === 'function') { p.setVolume(\(safeVolume)); }
            else {
                var v = document.querySelector('video');
                if (v) v.volume = \(Double(safeVolume) / 100.0);
            }
        })();
        """
        try executeJSInActiveBrowser(js)
    }

    nonisolated func seekTo(_ position: Double) throws {
        let safePosition = max(0, position.isFinite ? position : 0)
        let js = """
        (function() {
            var p = document.getElementById('movie_player');
            if (p && typeof p.seekTo === 'function') { p.seekTo(\(safePosition), true); }
            else {
                var v = document.querySelector('video');
                if (v) v.currentTime = \(safePosition);
            }
        })();
        """
        try executeJSInActiveBrowser(js)
    }

    nonisolated func toggleShuffle() throws { throw MediaControllerError.unsupportedCommand }
    nonisolated func setRepeatMode(_ mode: RepeatMode) throws { throw MediaControllerError.unsupportedCommand }

    private nonisolated func executeJSInActiveBrowser(_ jsCode: String) throws {
        guard let browser = try browserWithYouTubeTab() else {
            throw MediaControllerError.appNotRunning
        }
        let escapedJS = escapeForAppleScript(jsCode)

        let script: String
        if browser.bundleID == "com.apple.Safari" {
            script = """
            tell application id "com.apple.Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            do JavaScript "\(escapedJS)" in t
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
                            execute t javascript "\(escapedJS)"
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
        }
        try AppleScriptRunner.run(script)
    }

    private nonisolated func sendSystemMediaKey(_ key: Int32) -> Bool {
        let flags = NSEvent.ModifierFlags(rawValue: 0xa00)
        let data1 = Int((key << 16) | 0xa00)
        let keyDown = NSEvent.otherEvent(
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
        let keyUp = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((key << 16) | 0xb00),
            data2: -1
        )
        guard let keyDownEvent = keyDown?.cgEvent, let keyUpEvent = keyUp?.cgEvent else { return false }
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        return true
    }
}
