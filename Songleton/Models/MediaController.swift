import AppKit

enum RepeatMode: String, Sendable {
    case off
    case all
    case one
}

struct NowPlayingInfo {
    let track: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let volume: Int
    let artworkURL: URL?
    let artworkData: Data?
    let position: Double
    let duration: Double
    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode
}

enum MediaControllerError: Error {
    case appNotRunning
    case permissionDenied
    case scriptFailed(String)
}

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

enum AutomationPermission {
    nonisolated static func status(bundleID: String, askUser: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, askUser)
    }
}

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
    nonisolated func toggleShuffle() throws
    nonisolated func setRepeatMode(_ mode: RepeatMode) throws
}

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
        set shuf to shuffling
        set rep to repeating
        return {t, a, al, s, v, u, pos, dur, shuf, rep}
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
        let duration = (result.atIndex(8)?.doubleValue ?? 0) / 1000.0
        let isShuffle = result.atIndex(9)?.booleanValue ?? false
        let isRepeatBool = result.atIndex(10)?.booleanValue ?? false

        return NowPlayingInfo(
            track: track, artist: artist, album: album,
            isPlaying: playerState == "playing",
            volume: volume, artworkURL: artworkURL, artworkData: nil,
            position: position, duration: duration,
            isShuffleEnabled: isShuffle, repeatMode: isRepeatBool ? .all : .off
        )
    }

    nonisolated func toggleShuffle() throws {
        try AppleScriptRunner.run("tell application \"Spotify\" to set shuffling to (not shuffling)")
    }

    nonisolated func setRepeatMode(_ mode: RepeatMode) throws {
        let isRep = (mode != .off)
        try AppleScriptRunner.run("tell application \"Spotify\" to set repeating to \(isRep)")
    }
}

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
        set shuf to shuffle enabled
        set rep to song repeat as string
        set d to missing value
        try
            set d to data of artwork 1 of current track
        end try
        return {t, a, al, s, v, pos, dur, shuf, rep, d}
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
        let isShuffle = result.atIndex(8)?.booleanValue ?? false
        let repStr = result.atIndex(9)?.stringValue?.lowercased() ?? "off"
        let rawData = result.atIndex(10)?.data
        let artworkData = (rawData?.isEmpty == false) ? rawData : nil

        let mode: RepeatMode
        if repStr.contains("one") {
            mode = .one
        } else if repStr.contains("all") {
            mode = .all
        } else {
            mode = .off
        }

        return NowPlayingInfo(
            track: track, artist: artist, album: album,
            isPlaying: playerState == "playing",
            volume: volume, artworkURL: nil, artworkData: artworkData,
            position: position, duration: duration,
            isShuffleEnabled: isShuffle, repeatMode: mode
        )
    }

    nonisolated func toggleShuffle() throws {
        try AppleScriptRunner.run("tell application \"Music\" to set shuffle enabled to (not shuffle enabled)")
    }

    nonisolated func setRepeatMode(_ mode: RepeatMode) throws {
        let modeStr: String
        switch mode {
        case .off: modeStr = "off"
        case .all: modeStr = "all"
        case .one: modeStr = "one"
        }
        try AppleScriptRunner.run("tell application \"Music\" to set song repeat to \(modeStr)")
    }
}
