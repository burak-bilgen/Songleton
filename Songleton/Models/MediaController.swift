import AppKit

// MARK: - Data Types

struct NowPlayingInfo {
    let track: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let volume: Int
    let artworkURL: URL?
    let artworkData: Data?
    let position: Double  // seconds
    let duration: Double  // seconds (0 = unknown)
}

// MARK: - Errors

enum MediaControllerError: Error {
    case appNotRunning
    case permissionDenied
    case scriptFailed(String)
}

// MARK: - AppleScript Runner

enum AppleScriptRunner {
    @discardableResult
    nonisolated static func run(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw MediaControllerError.scriptFailed("AppleScript derlenemedi")
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 { throw MediaControllerError.permissionDenied }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Bilinmeyen hata"
            throw MediaControllerError.scriptFailed(message)
        }
        return result
    }
}

// MARK: - Automation Permission

enum AutomationPermission {
    nonisolated static func status(bundleID: String, askUser: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, askUser)
    }
}

// MARK: - Protocol

protocol MediaController: Sendable {
    nonisolated var bundleID: String { get }
    nonisolated var displayName: String { get }
    nonisolated var scriptAppName: String { get }
    nonisolated var isRunning: Bool { get }

    nonisolated func fetchNowPlaying() throws -> NowPlayingInfo
    nonisolated func togglePlayPause() throws
    nonisolated func nextTrack() throws
    nonisolated func previousTrack() throws
    nonisolated func restartTrack() throws
    nonisolated func setVolume(_ volume: Int) throws
    nonisolated func seekTo(_ position: Double) throws
}

// MARK: - Default Implementations

extension MediaController {
    nonisolated var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    nonisolated func togglePlayPause() throws { try sendCommand("playpause") }
    nonisolated func nextTrack() throws { try sendCommand("next track") }
    nonisolated func previousTrack() throws { try sendCommand("previous track") }
    nonisolated func restartTrack() throws { try sendCommand("set player position to 0") }
    nonisolated func setVolume(_ volume: Int) throws { try sendCommand("set sound volume to \(volume)") }
    nonisolated func seekTo(_ position: Double) throws { try sendCommand("set player position to \(Int(position))") }

    private nonisolated func sendCommand(_ command: String) throws {
        guard isRunning else { throw MediaControllerError.appNotRunning }
        try AppleScriptRunner.run("tell application \"\(scriptAppName)\" to \(command)")
    }

    nonisolated func runInfoScript(_ body: String) throws -> NSAppleEventDescriptor {
        guard isRunning else { throw MediaControllerError.appNotRunning }
        return try AppleScriptRunner.run("tell application \"\(scriptAppName)\"\n\(body)\nend tell")
    }
}

// MARK: - Spotify

final class SpotifyController: MediaController {
    let bundleID = "com.spotify.client"
    let displayName = "Spotify"
    var scriptAppName: String { "Spotify" }

    nonisolated func fetchNowPlaying() throws -> NowPlayingInfo {
        let result = try runInfoScript("""
        set t to name of current track
        set a to artist of current track
        set al to album of current track
        set s to player state as string
        set v to sound volume
        set u to artwork url of current track
        set pos to player position
        set dur to duration of current track
        return {t, a, al, s, v, u, pos, dur}
        """)
        guard let track = result.atIndex(1)?.stringValue,
              let artist = result.atIndex(2)?.stringValue,
              let playerState = result.atIndex(4)?.stringValue else {
            throw MediaControllerError.scriptFailed("Spotify'dan beklenmeyen yanıt")
        }
        let album = result.atIndex(3)?.stringValue ?? ""
        let volume = Int(result.atIndex(5)?.int32Value ?? 50)
        let artworkURL = result.atIndex(6)?.stringValue.flatMap { URL(string: $0) }
        let position = result.atIndex(7)?.doubleValue ?? 0
        // Spotify returns duration in ms
        let duration = (result.atIndex(8)?.doubleValue ?? 0) / 1000.0
        return NowPlayingInfo(
            track: track, artist: artist, album: album,
            isPlaying: playerState == "playing",
            volume: volume, artworkURL: artworkURL, artworkData: nil,
            position: position, duration: duration
        )
    }
}

// MARK: - Apple Music

final class AppleMusicController: MediaController {
    let bundleID = "com.apple.Music"
    let displayName = "Apple Music"
    var scriptAppName: String { "Music" }

    nonisolated func fetchNowPlaying() throws -> NowPlayingInfo {
        let result = try runInfoScript("""
        set t to name of current track
        set a to artist of current track
        set al to album of current track
        set s to player state as string
        set v to sound volume
        set pos to player position
        set dur to duration of current track
        set d to missing value
        try
            set d to data of artwork 1 of current track
        end try
        return {t, a, al, s, v, pos, dur, d}
        """)
        guard let track = result.atIndex(1)?.stringValue,
              let artist = result.atIndex(2)?.stringValue,
              let playerState = result.atIndex(4)?.stringValue else {
            throw MediaControllerError.scriptFailed("Music'ten beklenmeyen yanıt")
        }
        let album = result.atIndex(3)?.stringValue ?? ""
        let volume = Int(result.atIndex(5)?.int32Value ?? 50)
        let position = result.atIndex(6)?.doubleValue ?? 0
        let duration = result.atIndex(7)?.doubleValue ?? 0
        let rawData = result.atIndex(8)?.data
        let artworkData = (rawData?.isEmpty == false) ? rawData : nil
        return NowPlayingInfo(
            track: track, artist: artist, album: album,
            isPlaying: playerState == "playing",
            volume: volume, artworkURL: nil, artworkData: artworkData,
            position: position, duration: duration
        )
    }
}
