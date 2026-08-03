import AppKit
import Combine
import SwiftUI

struct RecentTrack: Identifiable {
    let id = UUID()
    let track: String
    let artist: String
    let source: String
    let playedAt: Date
}

private actor MediaCommandQueue {
    func execute(_ action: @escaping @Sendable () throws -> Void) async throws {
        try Task.checkCancellation()
        try action()
        try await Task.sleep(for: .milliseconds(300))
    }
}

@MainActor
final class NowPlayingModel: ObservableObject {
    static let shared = NowPlayingModel()

    enum State {
        case notRunning
        case permissionDenied
        case loaded(NowPlayingInfo, source: String)
    }

    enum AutomationStatus {
        case notDetermined
        case granted
        case denied
    }

    @Published private(set) var state: State = .notRunning
    @Published private(set) var artwork: NSImage?
    @Published private(set) var dominantColor: Color = .accentColor
    @Published var automationStatus: AutomationStatus = .notDetermined
    @Published private(set) var recentTracks: [RecentTrack] = []

    let controllers: [any MediaController] = [SpotifyController(), AppleMusicController(), YouTubeController()]
    private var activeController: (any MediaController)?
    private var isFetching = false
    private var currentArtworkKey: String?
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadedKey: String?
    private var lastFetchTime: Date = Date()
    private var timerCancellable: AnyCancellable?
    private let commandQueue = MediaCommandQueue()
    private var volumeTask: Task<Void, Never>?

    var currentPosition: Double {
        guard case .loaded(let info, _) = state else { return 0 }
        if info.isPlaying {
            let elapsed = Date().timeIntervalSince(lastFetchTime)
            let position = info.position.isFinite ? max(0, info.position) : 0
            let safeElapsed = elapsed.isFinite ? max(0, elapsed) : 0
            return min(info.duration > 0 ? info.duration : Double.infinity, position + safeElapsed)
        }
        return info.position.isFinite ? max(0, info.position) : 0
    }

    private init() {
        SettingsModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }

        refresh()
    }

    var menuBarTitle: String? {
        guard case .loaded(let info, _) = state else { return nil }
        if SettingsModel.shared.showArtistInMenuBar && !info.artist.isEmpty {
            return "\(info.artist) - \(info.track)"
        }
        return info.track
    }

    var activeBundleID: String? { activeController?.activeBundleID }

    var platformAccentColor: Color {
        guard SettingsModel.shared.useDynamicColor else {
            return .white
        }
        if activeController is YouTubeController {
            return Color(red: 255 / 255, green: 0 / 255, blue: 0 / 255)
        }
        guard case .loaded(_, let source) = state else {
            return Color(red: 29/255, green: 185/255, blue: 84/255)
        }
        let src = source.lowercased()
        if src.contains("spotify") {
            return Color(red: 29/255, green: 185/255, blue: 84/255) // Spotify Green #1DB954
        } else if src.contains("youtube") {
            return Color(red: 255/255, green: 0/255, blue: 0/255) // YouTube Red #FF0000
        } else {
            return Color(red: 250/255, green: 36/255, blue: 60/255) // Apple Music Pink #FA243C
        }
    }

    func togglePlayPause() { send { try $0.togglePlayPause() } }
    func nextTrack() { send { try $0.nextTrack() } }
    func previousTrack() { send { try $0.previousTrack() } }
    func setVolume(_ volume: Int) {
        volumeTask?.cancel()
        let safeVolume = min(max(0, volume), 100)
        guard let controller = activeController else { return }
        volumeTask = Task { [weak self] in
            do {
                try await self?.commandQueue.execute { try controller.setVolume(safeVolume) }
            } catch is CancellationError {
                return
            } catch {
                print("Media command failed: \(error)")
            }
            self?.refresh()
        }
    }
    func seekTo(_ position: Double) { send { try $0.seekTo(position) } }
    func toggleShuffle() { send { try $0.toggleShuffle() } }

    func cycleRepeatMode() {
        guard case .loaded(let info, let src) = state else { return }

        let isSpotify = src.lowercased().contains("spotify")
        let nextMode: RepeatMode

        if isSpotify {
            // Spotify AppleScript only exposes boolean (Off <-> All)
            nextMode = (info.repeatMode == .off) ? .all : .off
        } else {
            // Apple Music AppleScript supports 3 states (Off -> All -> One -> Off)
            switch info.repeatMode {
            case .off: nextMode = .all
            case .all: nextMode = .one
            case .one: nextMode = .off
            }
        }

        let updatedInfo = NowPlayingInfo(
            track: info.track,
            artist: info.artist,
            album: info.album,
            isPlaying: info.isPlaying,
            volume: info.volume,
            artworkURL: info.artworkURL,
            artworkData: info.artworkData,
            position: info.position,
            duration: info.duration,
            isShuffleEnabled: info.isShuffleEnabled,
            repeatMode: nextMode
        )
        state = .loaded(updatedInfo, source: src)
        send { try $0.setRepeatMode(nextMode) }
    }

    func checkAutomationPermission(askUser: Bool) {
        var allGranted = true
        var anyDenied = false

        let mainControllers = controllers.filter { !($0 is YouTubeController) }
        for controller in mainControllers {
            let status = AutomationPermission.status(bundleID: controller.bundleID, askUser: askUser)
            switch status {
            case noErr: continue
            case OSStatus(errAEEventNotPermitted):
                allGranted = false
                anyDenied = true
            default:
                allGranted = false
            }
        }

        let result: AutomationStatus = allGranted ? .granted : (anyDenied ? .denied : .notDetermined)
        automationStatus = result
        if result == .granted {
            UserDefaults.standard.set(true, forKey: "hasGrantedAutomation")
        }
    }

    func permissionStatus(for bundleID: String, askUser: Bool = false) -> AutomationStatus {
        let status = AutomationPermission.status(bundleID: bundleID, askUser: askUser)
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .notDetermined
        }
    }

    func requestPermissionFor(bundleID: String) {
        guard let controller = controllers.first(where: { $0.bundleID == bundleID }) else { return }
        _ = AutomationPermission.status(bundleID: bundleID, askUser: true)

        let src = """
        tell application "\(controller.scriptAppName)"
            get name
        end tell
        """
        if let script = NSAppleScript(source: src) {
            var errDict: NSDictionary?
            _ = script.executeAndReturnError(&errDict)
        }

        checkAutomationPermission(askUser: false)
        refresh()
    }

    func requestPermissionByScript() {
        for controller in controllers where !(controller is YouTubeController) {
            requestPermissionFor(bundleID: controller.bundleID)
        }
        checkAutomationPermission(askUser: false)
        refresh()
    }

    func copyTrackInfo() -> String? {
        guard case .loaded(let info, _) = state else { return nil }
        let text = info.artist.isEmpty ? info.track : "\(info.artist) - \(info.track)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return text
    }

    func refresh() {
        guard !isFetching else { return }
        isFetching = true
        Task {
            let result = await fetchAll()
            if let result {
                state = result.state
                lastFetchTime = Date()
                activeController = result.active
                await syncArtwork(with: result.state)

                if case .loaded(let info, let src) = result.state {
                    let key = "\(src)|\(info.track)|\(info.artist)"
                    if key != lastLoadedKey {
                        lastLoadedKey = key
                        let recent = RecentTrack(track: info.track, artist: info.artist, source: src, playedAt: Date())
                        recentTracks.insert(recent, at: 0)
                        if recentTracks.count > 20 { recentTracks = Array(recentTracks.prefix(20)) }
                        let srcLower = src.lowercased()
                        let isDesktopMusicApp = srcLower.contains("spotify") || srcLower.contains("music")
                        if SettingsModel.shared.showTrackNotifications,
                           !MenuBarManager.shared.isHoverPopoverShown,
                           isDesktopMusicApp {
                            HUDToastManager.shared.show(track: info.track, artist: info.artist, artwork: self.artwork)
                        }
                    }
                }
            } else {
                state = .notRunning
                activeController = nil
                await syncArtwork(with: .notRunning)
            }
            isFetching = false
        }
    }

    private struct FetchResult {
        let state: State
        let active: (any MediaController)?
    }

    nonisolated private func fetchAll() async -> FetchResult? {
        var pausedCandidate: (any MediaController, NowPlayingInfo)?
        var sawPermissionDenied = false
        for controller in controllers {
            guard controller.isRunning else { continue }
            do {
                let info = try controller.fetchNowPlaying()
                if info.isPlaying {
                    return FetchResult(state: .loaded(info, source: controller.displayName), active: controller)
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
            return FetchResult(state: .loaded(info, source: controller.displayName), active: controller)
        }
        if sawPermissionDenied { return FetchResult(state: .permissionDenied, active: nil) }
        return FetchResult(state: .notRunning, active: nil)
    }

    private func syncArtwork(with state: State) async {
        guard case .loaded(let info, _) = state else {
            if currentArtworkKey != nil {
                currentArtworkKey = nil
                artwork = nil
                dominantColor = .accentColor
            }
            return
        }
        let source = switch state {
        case .loaded(_, let source): source
        case .notRunning, .permissionDenied: ""
        }
        let key = "\(source)|\(info.artworkURL?.absoluteString ?? "\(info.track)|\(info.artist)|\(info.album)")"
        guard key != currentArtworkKey else { return }
        currentArtworkKey = key

        if let data = info.artworkData, let image = NSImage(data: data) {
            artwork = image
            dominantColor = extractColor(from: image)
            return
        }
        guard let url = info.artworkURL, url.scheme?.lowercased() == "https" else {
            artwork = nil
            dominantColor = .accentColor
            return
        }
        let (image, color) = await Self.downloadArtworkAndColor(from: url)
        if currentArtworkKey == key {
            artwork = image
            if let color {
                dominantColor = color
            } else if let image {
                dominantColor = extractColor(from: image)
            } else {
                dominantColor = .accentColor
            }
        }
    }

    private func extractColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .accentColor
        }
        let width = 16, height = 16
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .accentColor }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        var validPixelCount: CGFloat = 0

        for i in 0..<(width * height) {
            let r = CGFloat(data[i * 4]) / 255.0
            let g = CGFloat(data[i * 4 + 1]) / 255.0
            let b = CGFloat(data[i * 4 + 2]) / 255.0
            let a = CGFloat(data[i * 4 + 3]) / 255.0
            if a < 0.5 { continue }

            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let brightness = (maxC + minC) / 2
            let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC

            if brightness > 0.08 && brightness < 0.92 {
                let weight = 1.0 + saturation * 2.0
                totalR += r * weight
                totalG += g * weight
                totalB += b * weight
                validPixelCount += weight
            }
        }

        guard validPixelCount > 0 else { return .accentColor }

        var avgR = totalR / validPixelCount
        var avgG = totalG / validPixelCount
        var avgB = totalB / validPixelCount

        let avgLuminance = 0.2126 * avgR + 0.7152 * avgG + 0.0722 * avgB
        let boost: CGFloat = 1.35
        avgR = min(1.0, max(0.0, avgLuminance + (avgR - avgLuminance) * boost))
        avgG = min(1.0, max(0.0, avgLuminance + (avgG - avgLuminance) * boost))
        avgB = min(1.0, max(0.0, avgLuminance + (avgB - avgLuminance) * boost))

        return Color(red: avgR, green: avgG, blue: avgB)
    }

    nonisolated private static func downloadArtworkAndColor(from url: URL) async -> (NSImage?, Color?) {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count <= 10 * 1024 * 1024,
              let image = NSImage(data: data) else { return (nil, nil) }
        return (image, nil)
    }

    private func send(_ action: @escaping @Sendable (any MediaController) throws -> Void) {
        guard let controller = activeController else { return }
        enqueue(action, on: controller)
    }

    private func enqueue(
        _ action: @escaping @Sendable (any MediaController) throws -> Void,
        on controller: any MediaController
    ) {
        Task { [weak self] in
            do {
                try await self?.commandQueue.execute { try action(controller) }
            } catch {
                print("Media command failed: \(error)")
            }
            self?.refresh()
        }
    }
}
