import AppKit
import OSLog

nonisolated enum RepeatMode: String, Sendable {
    case off
    case all
    case one
}

nonisolated struct NowPlayingInfo: Sendable {
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

nonisolated enum MediaControllerError: Error, Sendable {
    case appNotRunning
    case permissionDenied
    case unsupportedCommand
    case scriptFailed(String)
}

nonisolated enum MediaControllerResolution {
    case notRunning
    case permissionDenied
    case loaded(NowPlayingInfo, controller: any MediaController)
}

nonisolated enum MediaControllerResolver {
    static func resolve(controllers: [any MediaController]) -> MediaControllerResolution {
        var pausedCandidate: (any MediaController, NowPlayingInfo)?
        var sawPermissionDenied = false

        for controller in controllers {
            guard controller.isRunning else { continue }

            do {
                let info = try controller.fetchNowPlaying()
                if info.isPlaying {
                    return .loaded(info, controller: controller)
                }
                if pausedCandidate == nil {
                    pausedCandidate = (controller, info)
                }
            } catch MediaControllerError.permissionDenied {
                sawPermissionDenied = true
            } catch {
                continue
            }
        }

        if let (controller, info) = pausedCandidate {
            return .loaded(info, controller: controller)
        }
        return sawPermissionDenied ? .permissionDenied : .notRunning
    }
}

nonisolated enum MediaValue {
    nonisolated static let maximumPosition = 7 * 24 * 60 * 60.0

    nonisolated static func position(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(0, value), maximumPosition)
    }

    nonisolated static func duration(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, maximumPosition)
    }

    nonisolated static func volume(_ value: Int) -> Int {
        min(max(0, value), 100)
    }

    nonisolated static func volume(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(max(0, value), 100).rounded())
    }

    nonisolated static func metadata(_ value: String) -> String {
        RemoteResourceSecurity.sanitizedMetadata(value)
    }
}

enum AppleScriptRunner {
    @discardableResult
    nonisolated static func run(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw MediaControllerError.scriptFailed("AppleScript compilation failed")
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 { throw MediaControllerError.permissionDenied }
            let message = error[NSAppleScript.errorMessage] as? String
                ?? Bundle.main.localizedString(forKey: "media.unknown_error", value: "Unknown error", table: "Localizable")
            throw MediaControllerError.scriptFailed(message)
        }
        return result
    }
}

enum AutomationPermission {
    nonisolated private static let logger = Logger(
        subsystem: "bilgenworks.app.Songleton",
        category: "automation-permission"
    )

    nonisolated enum Status: Equatable, Sendable {
        case notDetermined
        case granted
        case denied
        case targetNotRunning
    }

    nonisolated static func status(bundleID: String, askUser: Bool = false) -> Status {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else {
            return .targetNotRunning
        }
        guard askUser else {
            guard let cached = UserDefaults.standard.object(
                forKey: "permission_\(bundleID)"
            ) as? Bool else { return .notDetermined }
            return cached ? .granted : .denied
        }

        logger.info("Sending access request to \(bundleID, privacy: .public)")
        let status: Status
        do {
            try AppleScriptRunner.run("""
            with timeout of 120 seconds
                tell application id "\(bundleID)" to get player state
            end timeout
            """)
            status = .granted
        } catch MediaControllerError.permissionDenied {
            status = .denied
        } catch {
            logger.error(
                "Player access request failed for \(bundleID, privacy: .public): \(String(describing: error), privacy: .private)"
            )
            status = .notDetermined
        }
        logger.info("Player access request returned for \(bundleID, privacy: .public)")
        if status == .granted || status == .denied {
            UserDefaults.standard.set(status == .granted, forKey: "permission_\(bundleID)")
        }
        return status
    }

    nonisolated static func isGranted(bundleID: String) -> Bool {
        return UserDefaults.standard.object(forKey: "permission_\(bundleID)") as? Bool == true
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
    nonisolated func setVolume(_ volume: Int) throws
    nonisolated func seekTo(_ position: Double) throws
    nonisolated func toggleShuffle() throws
    nonisolated func setRepeatMode(_ mode: RepeatMode) throws
}

extension MediaController {
    nonisolated var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    nonisolated func togglePlayPause() throws { try runCommand("playpause") }
    nonisolated func nextTrack() throws { try runCommand("next track") }
    nonisolated func previousTrack() throws { try runCommand("previous track") }
    nonisolated func setVolume(_ volume: Int) throws {
        try runCommand("set sound volume to \(MediaValue.volume(volume))")
    }
    nonisolated func seekTo(_ position: Double) throws {
        try runCommand("set player position to \(Int(MediaValue.position(position)))")
    }

    nonisolated func runCommand(_ command: String) throws {
        guard isRunning else { throw MediaControllerError.appNotRunning }
        guard AutomationPermission.isGranted(bundleID: bundleID) else { throw MediaControllerError.permissionDenied }
        do {
            try AppleScriptRunner.run("tell application \"\(scriptAppName)\" to \(command)")
        } catch MediaControllerError.permissionDenied {
            UserDefaults.standard.set(false, forKey: "permission_\(bundleID)")
            throw MediaControllerError.permissionDenied
        }
    }

    nonisolated func runInfoScript(_ body: String) throws -> NSAppleEventDescriptor {
        guard isRunning else { throw MediaControllerError.appNotRunning }
        guard AutomationPermission.isGranted(bundleID: bundleID) else { throw MediaControllerError.permissionDenied }
        do {
            return try AppleScriptRunner.run("tell application \"\(scriptAppName)\"\n\(body)\nend tell")
        } catch MediaControllerError.permissionDenied {
            UserDefaults.standard.set(false, forKey: "permission_\(bundleID)")
            throw MediaControllerError.permissionDenied
        }
    }
}

nonisolated final class SpotifyController: MediaController {
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
            throw MediaControllerError.scriptFailed("Unexpected Spotify response")
        }
        let safeTrack = MediaValue.metadata(track)
        let safeArtist = MediaValue.metadata(artist)
        let album = MediaValue.metadata(result.atIndex(3)?.stringValue ?? "")
        let volume = MediaValue.volume(Int(result.atIndex(5)?.int32Value ?? 50))
        let artworkURL = result.atIndex(6)?.stringValue.flatMap { URL(string: $0) }
        let position = MediaValue.position(result.atIndex(7)?.doubleValue ?? 0)
        let rawDuration = result.atIndex(8)?.doubleValue ?? 0
        // Spotify versions have returned both seconds and milliseconds.
        let duration = MediaValue.duration(rawDuration > 10_000 ? rawDuration / 1_000 : rawDuration)
        let isShuffle = result.atIndex(9)?.booleanValue ?? false
        let isRepeatBool = result.atIndex(10)?.booleanValue ?? false

        return NowPlayingInfo(
            track: safeTrack, artist: safeArtist, album: album,
            isPlaying: playerState == "playing",
            volume: volume, artworkURL: artworkURL, artworkData: nil,
            position: position, duration: duration,
            isShuffleEnabled: isShuffle, repeatMode: isRepeatBool ? .all : .off
        )
    }

    nonisolated func toggleShuffle() throws {
        try runCommand("set shuffling to (not shuffling)")
    }

    nonisolated func setRepeatMode(_ mode: RepeatMode) throws {
        let isRep = (mode != .off)
        try runCommand("set repeating to \(isRep)")
    }

}

nonisolated final class AppleMusicController: @unchecked Sendable, MediaController {
    let bundleID = "com.apple.Music"
    let displayName = "Apple Music"
    var scriptAppName: String { "Music" }

    private let artworkLock = NSLock()
    private nonisolated(unsafe) var cachedArtworkTrack: String?
    private nonisolated(unsafe) var cachedArtworkData: Data?

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
        return {t, a, al, s, v, pos, dur, shuf, rep}
        """)
        guard let track = result.atIndex(1)?.stringValue,
              let artist = result.atIndex(2)?.stringValue,
              let playerState = result.atIndex(4)?.stringValue else {
            throw MediaControllerError.scriptFailed("Unexpected Music response")
        }
        let safeTrack = MediaValue.metadata(track)
        let safeArtist = MediaValue.metadata(artist)
        let album = MediaValue.metadata(result.atIndex(3)?.stringValue ?? "")
        let volume = MediaValue.volume(Int(result.atIndex(5)?.int32Value ?? 50))
        let position = MediaValue.position(result.atIndex(6)?.doubleValue ?? 0)
        let duration = MediaValue.duration(result.atIndex(7)?.doubleValue ?? 0)
        let isShuffle = result.atIndex(8)?.booleanValue ?? false
        let repStr = result.atIndex(9)?.stringValue?.lowercased() ?? "off"
        let mode: RepeatMode
        if repStr.contains("one") {
            mode = .one
        } else if repStr.contains("all") {
            mode = .all
        } else {
            mode = .off
        }

        let artworkData = loadArtworkIfNeeded(for: "\(safeTrack)|\(safeArtist)|\(album)")

        return NowPlayingInfo(
            track: safeTrack, artist: safeArtist, album: album,
            isPlaying: playerState == "playing",
            volume: volume, artworkURL: nil, artworkData: artworkData,
            position: position, duration: duration,
            isShuffleEnabled: isShuffle, repeatMode: mode
        )
    }

    private nonisolated func loadArtworkIfNeeded(for trackKey: String) -> Data? {
        artworkLock.lock()
        if cachedArtworkTrack == trackKey {
            let data = cachedArtworkData
            artworkLock.unlock()
            return data
        }
        artworkLock.unlock()

        let data = (try? runInfoScript("""
        try
            return data of artwork 1 of current track
        on error
            return missing value
        end try
        """).data).flatMap { data in
            RemoteResourceSecurity.safeImage(from: data) == nil ? nil : data
        }

        artworkLock.lock()
        cachedArtworkTrack = trackKey
        cachedArtworkData = data
        artworkLock.unlock()
        return data
    }

    nonisolated func toggleShuffle() throws {
        try runCommand("set shuffle enabled to (not shuffle enabled)")
    }

    nonisolated func setRepeatMode(_ mode: RepeatMode) throws {
        let modeStr: String
        switch mode {
        case .off: modeStr = "off"
        case .all: modeStr = "all"
        case .one: modeStr = "one"
        }
        try runCommand("set song repeat to \(modeStr)")
    }
}
