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

    let controllers: [any MediaController] = [SpotifyController(), AppleMusicController()]
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

    var platformAccentColor: Color {
        guard case .loaded(_, let source) = state else {
            return Color(red: 29/255, green: 185/255, blue: 84/255)
        }
        let src = source.lowercased()
        if src.contains("spotify") {
            return Color(red: 29/255, green: 185/255, blue: 84/255) // Spotify Green #1DB954
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

    var hasAnyPlayerPermission: Bool {
        permissionStatus(for: "com.spotify.client") == .granted ||
        permissionStatus(for: "com.apple.Music") == .granted
    }

    func checkAutomationPermission(askUser: Bool) {
        var anyGranted = false
        var anyDenied = false

        for controller in controllers {
            let status = permissionStatus(for: controller.bundleID, askUser: askUser)
            switch status {
            case .granted:
                anyGranted = true
            case .denied:
                anyDenied = true
            case .notDetermined:
                break
            }
        }

        let result: AutomationStatus = anyGranted ? .granted : (anyDenied ? .denied : .notDetermined)
        automationStatus = result
        if anyGranted {
            UserDefaults.standard.set(true, forKey: "hasGrantedAutomation")
        }
    }

    func permissionStatus(for bundleID: String, askUser: Bool = false) -> AutomationStatus {
        let status = AutomationPermission.status(bundleID: bundleID, askUser: askUser)
        if status == noErr {
            UserDefaults.standard.set(true, forKey: "permission_\(bundleID)")
            return .granted
        } else if status == OSStatus(errAEEventNotPermitted) {
            UserDefaults.standard.set(false, forKey: "permission_\(bundleID)")
            return .denied
        }

        if UserDefaults.standard.bool(forKey: "permission_\(bundleID)") {
            return .granted
        }

        return .notDetermined
    }

    func requestPermissionFor(bundleID: String) {
        guard let controller = controllers.first(where: { $0.bundleID == bundleID }) else { return }

        let src = """
        tell application "\(controller.scriptAppName)"
            get player state
        end tell
        """
        if let script = NSAppleScript(source: src) {
            var errDict: NSDictionary?
            _ = script.executeAndReturnError(&errDict)
            if let errDict = errDict {
                let code = errDict[NSAppleScript.errorNumber] as? Int ?? 0
                if code == -1743 {
                    UserDefaults.standard.set(false, forKey: "permission_\(bundleID)")
                } else {
                    UserDefaults.standard.set(true, forKey: "permission_\(bundleID)")
                }
            } else {
                UserDefaults.standard.set(true, forKey: "permission_\(bundleID)")
            }
        }

        checkAutomationPermission(askUser: false)
        refresh()
    }

    func requestPermissionByScript() {
        for controller in controllers {
            requestPermissionFor(bundleID: controller.bundleID)
        }
        checkAutomationPermission(askUser: false)
        refresh()
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
                           !AmbientModeManager.shared.isPresented,
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
        switch MediaControllerResolver.resolve(controllers: controllers) {
        case .loaded(let info, let controller):
            return FetchResult(state: .loaded(info, source: controller.displayName), active: controller)
        case .permissionDenied:
            return FetchResult(state: .permissionDenied, active: nil)
        case .notRunning:
            return FetchResult(state: .notRunning, active: nil)
        }
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
            dominantColor = Color(red: 0.38, green: 0.42, blue: 0.95)
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
                dominantColor = Color(red: 0.38, green: 0.42, blue: 0.95)
            }
        }
    }

    private func extractColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return Color(red: 0.38, green: 0.42, blue: 0.95)
        }
        let width = 32, height = 32
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Color(red: 0.38, green: 0.42, blue: 0.95) }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var maxVibrancyScore: CGFloat = -1
        var bestR: CGFloat = 0.38
        var bestG: CGFloat = 0.42
        var bestB: CGFloat = 0.95

        for i in 0..<(width * height) {
            let r = CGFloat(data[i * 4]) / 255.0
            let g = CGFloat(data[i * 4 + 1]) / 255.0
            let b = CGFloat(data[i * 4 + 2]) / 255.0
            let a = CGFloat(data[i * 4 + 3]) / 255.0
            if a < 0.5 { continue }

            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let delta = maxC - minC
            let lightness = (maxC + minC) / 2.0

            guard maxC > 0 else { continue }
            let saturation = delta / maxC

            // Filter out dull muds, grays, near-blacks, and near-whites
            if lightness > 0.15 && lightness < 0.88 && saturation > 0.18 {
                // Score favors vibrant, saturated hues over muddy averages
                let score = saturation * 3.5 + (1.0 - abs(lightness - 0.5)) * 1.5
                if score > maxVibrancyScore {
                    maxVibrancyScore = score
                    bestR = r
                    bestG = g
                    bestB = b
                }
            }
        }

        // Convert best RGB to HSL and boost saturation and brightness so it's NEVER muddy!
        let nsColor = NSColor(red: bestR, green: bestG, blue: bestB, alpha: 1.0)
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getHue(&hue, saturation: &sat, brightness: &brightness, alpha: &alpha)

        // Boost saturation to at least 0.70 and normalize brightness to 0.65-0.88
        sat = max(sat, 0.70)
        brightness = min(max(brightness, 0.65), 0.88)

        let vibrantNSColor = NSColor(hue: hue, saturation: sat, brightness: brightness, alpha: 1.0)
        return Color(nsColor: vibrantNSColor)
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
