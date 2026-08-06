import AppKit
import Combine
import OSLog
import SwiftUI

private actor MediaCommandQueue {
    func execute(_ action: @escaping @Sendable () throws -> Void) async throws {
        try Task.checkCancellation()
        try action()
        try await Task.sleep(for: .milliseconds(300))
    }
}

private actor AutomationPermissionQueue {
    func request(bundleID: String) -> AutomationPermission.Status {
        AutomationPermission.status(bundleID: bundleID, askUser: true)
    }
}

/// Small in-memory cache for downloaded artwork so revisiting a track (or
/// polling the same track) never re-downloads its cover over the network.
nonisolated private final class ArtworkCache: @unchecked Sendable {
    static let shared = ArtworkCache()
    private static let maximumEntries = 50
    private let lock = NSLock()
    private var images: [String: NSImage] = [:]

    func image(for url: URL) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        return images[url.absoluteString]
    }

    func store(_ image: NSImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        // Bound memory: evict an arbitrary entry once the cache is full.
        if images.count >= Self.maximumEntries, images[url.absoluteString] == nil {
            images.removeValue(forKey: images.keys.first ?? "")
        }
        images[url.absoluteString] = image
    }
}

@MainActor
final class NowPlayingModel: ObservableObject {
    static let shared = AppContainer.shared.nowPlaying

    enum State: Sendable {
        case notRunning
        case permissionDenied
        case loaded(NowPlayingInfo, source: String)
    }

    enum AutomationStatus: Sendable {
        case notDetermined
        case granted
        case denied
    }

    @Published private(set) var state: State = .notRunning
    @Published private(set) var artwork: NSImage?
    @Published private(set) var dominantColor: Color = .accentColor
    @Published var automationStatus: AutomationStatus = .notDetermined
    @Published private(set) var permissionRequestsInFlight: Set<String> = []
    @Published private(set) var isGrantAllInProgress = false

    let controllers: [any MediaController] = [
        SpotifyController(),
        AppleMusicController(),
        TidalController(),
        DeezerController(),
        AmazonMusicController(),
        YouTubeMusicController(),
        SoundCloudController(),
        QobuzController()
    ]
    private var activeController: (any MediaController)?
    private var isFetching = false
    private var currentArtworkKey: String?
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadedKey: String?
    private var timerCancellable: AnyCancellable?
    private let commandQueue = MediaCommandQueue()
    private let automationPermissionQueue = AutomationPermissionQueue()
    private let logger = Logger(subsystem: "bilgenworks.app.Songleton", category: "media-command")
    private var volumeTask: Task<Void, Never>?
    private let settings: SettingsModel

    init(settings: SettingsModel) {
        self.settings = settings
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.hasAnyPlayerPermission else { return }
                self.refresh()
            }
    }

    var menuBarTitle: String? {
        guard case .loaded(let info, _) = state else { return nil }
        if settings.showArtistInMenuBar && !info.artist.isEmpty {
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
                self?.logger.error("Media command failed: \(String(describing: error), privacy: .private)")
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
        controllers.contains(where: { permissionStatus(for: $0.permissionBundleID) == .granted })
    }

    /// Only the players that are actually installed on this Mac, in the
    /// original controller order.
    var installedControllers: [any MediaController] {
        controllers.filter { $0.isInstalled }
    }

    func checkAutomationPermission() {
        let statuses = controllers.map { controller in
            let cached = UserDefaults.standard.object(
                forKey: "permission_\(controller.permissionBundleID)"
            ) as? Bool
            return (
                controller.permissionBundleID,
                cached.map { $0 ? AutomationStatus.granted : .denied } ?? .notDetermined
            )
        }
        applyAutomationStatuses(statuses)
        if statuses.contains(where: { $0.1 == .granted }) {
            refresh()
        }
    }

    private func applyAutomationStatuses(_ statuses: [(String, AutomationStatus)]) {
        var anyGranted = false
        var anyDenied = false

        for (bundleID, status) in statuses {
            switch status {
            case .granted:
                anyGranted = true
                UserDefaults.standard.set(true, forKey: "permission_\(bundleID)")
            case .denied:
                anyDenied = true
                UserDefaults.standard.set(false, forKey: "permission_\(bundleID)")
            case .notDetermined:
                UserDefaults.standard.removeObject(forKey: "permission_\(bundleID)")
            }
        }

        automationStatus = anyGranted ? .granted : (anyDenied ? .denied : .notDetermined)
    }

    func permissionStatus(for bundleID: String) -> AutomationStatus {
        if let cached = UserDefaults.standard.object(forKey: "permission_\(bundleID)") as? Bool {
            return cached ? .granted : .denied
        }
        return .notDetermined
    }

    func permissionStatus(for controller: any MediaController) -> AutomationStatus {
        permissionStatus(for: controller.permissionBundleID)
    }

    func requestPermissionFor(_ controller: any MediaController) {
        guard controllers.contains(where: { $0.bundleID == controller.bundleID }) else { return }
        guard permissionRequestsInFlight.insert(controller.bundleID).inserted else { return }

        Task { [weak self] in
            guard let self else { return }
            defer { permissionRequestsInFlight.remove(controller.bundleID) }
            await performPermissionRequest(for: controller, openSettingsOnDeny: true)
        }
    }

    /// Requests Automation permission for every installed player that has not
    /// been granted yet, one at a time. macOS still shows one system prompt
    /// per target app (a TCC limitation), but the user only taps this once.
    func requestPermissionsForAllInstalled() {
        let targets = installedControllers.filter { permissionStatus(for: $0) != .granted }
        guard !targets.isEmpty, !isGrantAllInProgress else { return }
        isGrantAllInProgress = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isGrantAllInProgress = false }
            for controller in targets {
                guard !Task.isCancelled else { return }
                if permissionRequestsInFlight.contains(controller.bundleID) { continue }
                await performPermissionRequest(for: controller, openSettingsOnDeny: false)
            }
        }
    }

    private func performPermissionRequest(
        for controller: any MediaController,
        openSettingsOnDeny: Bool
    ) async {
        NSApp.activate(ignoringOtherApps: true)
        logger.info("Requesting player access for \(controller.bundleID, privacy: .public)")
        let status = await requestAutomationPermission(for: controller)
        applyAutomationStatuses([(controller.permissionBundleID, status)])
        logger.info(
            "Player access request finished for \(controller.bundleID, privacy: .public): \(String(describing: status), privacy: .public)"
        )
        if status == .granted {
            refresh()
        } else if status == .denied, openSettingsOnDeny {
            Self.openAutomationSettings()
        }
    }

    private func requestAutomationPermission(
        for controller: any MediaController
    ) async -> AutomationStatus {
        // Window-title players are gated on System Events, which is always
        // available — there is no need to launch the player just to ask.
        // Only scriptable players (Spotify, Apple Music) need to be running
        // for their probe to resolve.
        if controller.permissionBundleID == controller.bundleID {
            guard await Self.launchPlayerIfNeeded(bundleID: controller.bundleID) else {
                return .notDetermined
            }
        }
        NSApp.activate(ignoringOtherApps: true)

        switch await automationPermissionQueue.request(bundleID: controller.permissionBundleID) {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .notDetermined, .targetNotRunning:
            return .notDetermined
        }
    }

    private static func launchPlayerIfNeeded(bundleID: String) async -> Bool {
        if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            return true
        }

        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            ) { application, error in
                continuation.resume(returning: application != nil && error == nil)
            }
        }
    }

    private static func openAutomationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func refresh() {
        guard !isFetching else { return }
        let permittedControllers = controllers.filter {
            permissionStatus(for: $0.permissionBundleID) == .granted
        }
        guard !permittedControllers.isEmpty else {
            state = .notRunning
            activeController = nil
            return
        }
        isFetching = true
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Self.fetchAll(controllers: permittedControllers)
            }.value
            guard let self else { return }
            if let result {
                self.state = result.state
                self.activeController = result.active

                var shownToastKey: String?
                if case .loaded(let info, let src) = result.state {
                    let key = "\(src)|\(info.track)|\(info.artist)"
                    let previousKey = self.lastLoadedKey
                    if key != previousKey {
                        self.lastLoadedKey = key
                        let srcLower = src.lowercased()
                        let isDesktopMusicApp = srcLower.contains("spotify") || srcLower.contains("music")
                        if previousKey != nil,
                           settings.showTrackNotifications,
                           !MenuBarManager.shared.isHoverPopoverShown,
                           !AmbientModeManager.shared.isPresented,
                           isDesktopMusicApp {
                            HUDToastManager.shared.show(track: info.track, artist: info.artist, artwork: nil, trackKey: key)
                            shownToastKey = key
                        }
                    }
                } else if case .permissionDenied = result.state {
                    self.checkAutomationPermission()
                }

                // Unlock the poll loop immediately — a slow artwork download
                // must never stall the next metadata refresh.
                self.isFetching = false

                await self.syncArtwork(with: result.state)

                if let shownToastKey {
                    HUDToastManager.shared.updateArtwork(self.artwork, for: shownToastKey)
                }
            } else {
                self.state = .notRunning
                self.activeController = nil
                self.isFetching = false
                await self.syncArtwork(with: .notRunning)
            }
        }
    }

    nonisolated private struct FetchResult: Sendable {
        let state: State
        let active: (any MediaController)?
    }

    nonisolated private static func fetchAll(
        controllers: [any MediaController]
    ) -> FetchResult? {
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
        // Never leave the previous track's cover under the new title while the
        // artwork loads — fall back to the placeholder immediately.
        artwork = nil
        dominantColor = Color(red: 0.38, green: 0.42, blue: 0.95)

        if let data = info.artworkData, let image = RemoteResourceSecurity.safeImage(from: data) {
            artwork = image
            dominantColor = extractColor(from: image)
            return
        }
        if let url = info.artworkURL, url.scheme?.lowercased() == "https" {
            let (image, color) = await Self.downloadArtworkAndColor(from: url)
            guard currentArtworkKey == key else { return }
            artwork = image
            if let color {
                dominantColor = color
            } else if let image {
                dominantColor = extractColor(from: image)
            } else {
                dominantColor = Color(red: 0.38, green: 0.42, blue: 0.95)
            }
            return
        }
        // No artwork URL (e.g. Apple Music): the controller can expose the
        // cover through a separate, slower call. Run it off the main actor so
        // the metadata poll is never blocked by it.
        guard let controller = activeController else { return }
        let controllerKey = "\(info.track)|\(info.artist)|\(info.album)"
        let data = await Task.detached(priority: .utility) { () -> Data? in
            try? controller.fetchArtworkData(for: controllerKey)
        }.value
        guard currentArtworkKey == key,
              let data,
              let image = RemoteResourceSecurity.safeImage(from: data) else { return }
        artwork = image
        dominantColor = extractColor(from: image)
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
        if let cached = ArtworkCache.shared.image(for: url) {
            return (cached, nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let data = try? await SecureRemoteResource.data(for: request, kind: .artwork),
              let image = RemoteResourceSecurity.safeImage(from: data) else { return (nil, nil) }
        ArtworkCache.shared.store(image, for: url)
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
                self?.logger.error("Media command failed: \(String(describing: error), privacy: .private)")
            }
            self?.refresh()
        }
    }

    func setMockStateForTutorial() {
        let mockInfo = NowPlayingInfo(
            track: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            isPlaying: true,
            volume: 78,
            artworkURL: nil,
            artworkData: nil,
            position: 140,
            duration: 243,
            isShuffleEnabled: false,
            repeatMode: .off
        )
        self.state = .loaded(mockInfo, source: "Spotify")
        // Matches the synthwave cover (sunset orange -> violet) used in the
        // tutorial's mock menu bar / hover panel artwork.
        self.dominantColor = Color(red: 0.85, green: 0.36, blue: 0.45)
    }
}
