import AppKit
import Combine
import OSLog
import SwiftUI

/// Debug timing for the artwork pipeline. Durations only — never track names
/// or any other listening information.
nonisolated private let artworkLogger = Logger(
    subsystem: "bilgenworks.app.Songleton",
    category: "artwork"
)

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

/// Two-layer cache for downloaded artwork: an in-memory table for instant
/// hits within a session, plus a bounded on-disk mirror keyed by URL so
/// covers survive app restarts and revisits never re-download over the
/// network. Spotify's CDN explicitly permits long caching
/// (Cache-Control: max-age=15780000), so honoring it here is safe.
nonisolated final class ArtworkCache: @unchecked Sendable {
    struct Entry {
        let image: NSImage
        let color: Color
    }

    static let shared = ArtworkCache()
    static let maximumMemoryEntries = 100
    static let maximumDiskEntries = 300
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private let diskDirectory: URL

    /// `diskDirectory` is injectable for tests; production uses the app
    /// Caches directory.
    init(diskDirectory: URL? = nil) {
        if let diskDirectory {
            self.diskDirectory = diskDirectory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.diskDirectory = caches.appendingPathComponent("SongletonArtwork", isDirectory: true)
        }
        try? FileManager.default.createDirectory(
            at: self.diskDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Memory-first lookup; a disk hit decodes once and is promoted to memory
    /// (with its color) so every later poll for the same track is instant.
    /// Disk I/O runs here, so callers must not be on the main actor. The
    /// decode and color extraction also run off the calling thread's actor.
    func entry(for url: URL) -> Entry? {
        let key = url.absoluteString
        lock.lock()
        if let hit = entries[key] {
            lock.unlock()
            artworkLogger.debug("ArtworkCache memory hit")
            return hit
        }
        let fileURL = self.fileURL(for: url)
        let data = try? Data(contentsOf: fileURL)
        lock.unlock()
        guard let data else { return nil }

        let start = Date()
        guard let image = RemoteResourceSecurity.safeImage(from: data) else { return nil }
        let color = Self.extractDominantColor(from: image)
        let ms = Date().timeIntervalSince(start) * 1000
        artworkLogger.debug("ArtworkCache disk hit, decode+color: \(ms, format: .fixed(precision: 1))ms")

        lock.lock()
        if entries[key] == nil {
            storeEntryLocked(Entry(image: image, color: color), for: key)
        }
        lock.unlock()
        return Entry(image: image, color: color)
    }

    /// Persists artwork that has already been decoded and validated: no
    /// re-decode, no quality loss. Promotes the entry into memory and mirrors
    /// the raw bytes to disk.
    func store(image: NSImage, color: Color, data: Data, for url: URL) {
        let key = url.absoluteString
        lock.lock()
        defer { lock.unlock() }
        storeEntryLocked(Entry(image: image, color: color), for: key)
        try? data.write(to: self.fileURL(for: url), options: .atomic)
        trimDiskIfNeededLocked()
    }

    /// Callers must hold `lock`.
    private func storeEntryLocked(_ entry: Entry, for key: String) {
        // Bound memory: evict an arbitrary entry once the cache is full.
        if entries.count >= Self.maximumMemoryEntries, entries[key] == nil {
            entries.removeValue(forKey: entries.keys.first ?? "")
        }
        entries[key] = entry
    }

    private func fileURL(for url: URL) -> URL {
        diskDirectory.appendingPathComponent(Self.fileName(for: url))
    }

    /// Stable 64-bit FNV-1a of the absolute URL — deterministic across
    /// launches, unlike String.hashValue, so the same track always maps to
    /// the same file.
    static func fileName(for url: URL) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in url.absoluteString.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash) + ".img"
    }

    /// Keeps the disk mirror bounded: when it exceeds the cap, evict the
    /// oldest files by modification date. Callers must hold `lock`.
    private func trimDiskIfNeededLocked() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ), files.count > Self.maximumDiskEntries else { return }

        let sorted = files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }
        for file in sorted.prefix(files.count - Self.maximumDiskEntries) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Vibrant dominant color from the cover, boosted to stay vivid. Pure CPU
    /// work — safe to call off the main actor.
    static func extractDominantColor(from image: NSImage) -> Color {
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

    // MARK: - Test hooks

    var memoryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    var diskFileCount: Int {
        (try? FileManager.default.contentsOfDirectory(at: diskDirectory, includingPropertiesForKeys: nil))?.count ?? 0
    }

    func resetForTesting() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
        try? FileManager.default.removeItem(at: diskDirectory)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }
}

/// Pure decision helpers for the artwork pipeline — extracted so retry,
/// staleness, and cache-key rules are unit-testable without a live player.
nonisolated enum ArtworkPipeline {
    /// Minimum wait after a failed artwork download before retrying, so a dead
    /// network doesn't re-hit the CDN on every 0.5s poll forever.
    static let retryInterval: TimeInterval = 5.0

    /// True when a download for `key` should be attempted at `now`.
    static func shouldAttemptDownload(
        key: String,
        lastFailureKey: String?,
        lastFailureAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard lastFailureKey == key, let lastFailureAt else { return true }
        return now.timeIntervalSince(lastFailureAt) >= retryInterval
    }

    /// Stable identity for a track's artwork: source + artwork URL when
    /// present, otherwise a track/artist/album composite.
    static func key(
        source: String,
        artworkURL: URL?,
        track: String,
        artist: String,
        album: String
    ) -> String {
        if let artworkURL {
            return "\(source)|\(artworkURL.absoluteString)"
        }
        return "\(source)|\(track)|\(artist)|\(album)"
    }

    /// Final guard: a result may only be published if it still belongs to the
    /// currently loading key; anything older is dropped.
    static func shouldPublish(resultKey: String, currentKey: String?) -> Bool {
        resultKey == currentKey
    }

    /// Optimizes artwork URL to fetch appropriate resolution (e.g. 300x300 for Spotify)
    /// which reduces network payload by ~80% and dramatically speeds up cover loading.
    static func optimizeArtworkURL(_ url: URL) -> URL {
        let str = url.absoluteString
        if str.contains("i.scdn.co/image/ab67616d0000b273") {
            let optimized = str.replacingOccurrences(of: "ab67616d0000b273", with: "ab67616d00001e02")
            return URL(string: optimized) ?? url
        }
        return url
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
    private var artworkTask: Task<Void, Never>?
    // Bounded-retry bookkeeping: the last artwork key whose download failed and
    // when it failed, so a dead network doesn't re-hit the CDN every poll.
    private var lastArtworkFailureKey: String?
    private var lastArtworkFailureAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadedKey: String?
    private var pendingToast: (track: String, artist: String)?
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

        // 0.5s cadence halves the worst-case latency between a track change and
        // its artwork download (poll detection + network). The fetch itself is
        // cheap (AppleScript reads); commands are separately queued.
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
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

    var activeControllerDisplayName: String? {
        activeController?.displayName
    }

    var isSpotifyActive: Bool {
        if let name = activeController?.displayName.lowercased(), name.contains("spotify") {
            return true
        }
        if case .loaded(_, let source) = state, source.lowercased().contains("spotify") {
            return true
        }
        return SpotifyController().isRunning
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

                var pendingToast: (track: String, artist: String)?
                if case .loaded(let info, let src) = result.state {
                    let key = "\(src)|\(info.track)|\(info.artist)"
                    let previousKey = self.lastLoadedKey
                    if key != previousKey {
                        self.lastLoadedKey = key
                        let srcLower = src.lowercased()
                        let isDesktopMusicApp = srcLower.contains("spotify") || srcLower.contains("music")
                        if previousKey != nil,
                           settings.showTrackNotifications,
                           isDesktopMusicApp {
                            pendingToast = (track: info.track, artist: info.artist)
                        }
                    }
                } else if case .permissionDenied = result.state {
                    self.checkAutomationPermission()
                }

                // Unlock the poll loop immediately — a slow artwork download
                // must never stall the next metadata refresh.
                self.isFetching = false

                // Save pending toast if a new track was loaded; it will pop up
                // as soon as artwork loading finishes (or fails), ensuring the
                // notification opens with the cover photo viewable right away.
                if let pendingToast {
                    self.pendingToast = pendingToast
                    self.dominantColor = Color(red: 0.38, green: 0.42, blue: 0.95)
                }

                // Artwork loading runs in its own cancellable task: when the
                // track changes, the previous task is cancelled (which aborts
                // its in-flight URLSession request) so stale downloads never
                // complete or overwrite the newer track's cover.
                self.startArtworkSync(for: result.state)
            } else {
                self.state = .notRunning
                self.activeController = nil
                self.isFetching = false
                self.startArtworkSync(for: .notRunning)
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

    /// Starts (or reuses) the artwork load for `state`. Called from every poll:
    /// if the artwork key is unchanged the in-flight task keeps running;
    /// otherwise the old task is cancelled (aborting its URLSession request)
    /// and a fresh one is started for the new track.
    private func startArtworkSync(for state: State) {
        let desiredKey: String?
        if case .loaded(let info, let source) = state {
            desiredKey = ArtworkPipeline.key(
                source: source,
                artworkURL: info.artworkURL,
                track: info.track,
                artist: info.artist,
                album: info.album
            )
        } else {
            desiredKey = nil
        }
        if desiredKey == currentArtworkKey {
            triggerPendingToastIfMatching()
            return
        }

        // Bounded retry: don't re-hit the network for a key that failed
        // recently. The poll loop keeps running; only the download backs off.
        if let desiredKey,
           !ArtworkPipeline.shouldAttemptDownload(
               key: desiredKey,
               lastFailureKey: lastArtworkFailureKey,
               lastFailureAt: lastArtworkFailureAt
           ) {
            triggerPendingToastIfMatching()
            return
        }

        // Claim the key synchronously — before the new task's body runs — so a
        // stale continuation resumed in the meantime (e.g. the previous track's
        // download finishing right as the track changed) sees the new key and
        // drops instead of flashing the old cover under the new title.
        currentArtworkKey = desiredKey
        guard let desiredKey else {
            artworkTask?.cancel()
            artworkTask = nil
            artwork = nil
            dominantColor = .accentColor
            triggerPendingToastIfMatching()
            return
        }
        dominantColor = Color(red: 0.38, green: 0.42, blue: 0.95)
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            await self?.syncArtwork(with: state, key: desiredKey)
        }
    }

    private func syncArtwork(with state: State, key: String) async {
        guard case .loaded(let info, _) = state else {
            triggerPendingToastIfMatching()
            return
        }
        // `startArtworkSync` already claimed this key synchronously. If this
        // task was superseded before its body ran (track changed again), drop
        // out without touching the current artwork.
        guard ArtworkPipeline.shouldPublish(resultKey: key, currentKey: currentArtworkKey),
              !Task.isCancelled else { return }
        let loadStart = Date()

        if let data = info.artworkData {
            // Decode and color extraction happen off the main actor; only the
            // final published values touch the UI.
            let (image, color) = await Self.decodeArtwork(data: data)
            // Stale? Drop silently. Decode failed for the current track? Back
            // off so later polls don't re-decode the same bad bytes forever.
            guard ArtworkPipeline.shouldPublish(resultKey: key, currentKey: currentArtworkKey) else { return }
            guard let image else {
                recordFailure(for: key)
                triggerPendingToastIfMatching()
                return
            }
            publishArtwork(image, color: color, loadStart: loadStart, key: key)
            return
        }
        if let url = info.artworkURL, url.scheme?.lowercased() == "https" {
            let (image, color) = await Self.downloadArtworkAndColor(from: url)
            guard ArtworkPipeline.shouldPublish(resultKey: key, currentKey: currentArtworkKey) else { return }
            guard let image else {
                // Transient failure (timeout, offline): remember it so the next
                // poll backs off instead of hammering the CDN every 0.5s.
                recordFailure(for: key)
                triggerPendingToastIfMatching()
                return
            }
            publishArtwork(image, color: color, loadStart: loadStart, key: key)
            return
        }
        // No artwork URL (e.g. Apple Music): the controller can expose the
        // cover through a separate, slower call. Run it off the main actor so
        // the metadata poll is never blocked by it, and bound the wait so a
        // hung AppleScript can't stall the track-change toast indefinitely
        // (the fetch itself keeps running off-thread; its result is discarded
        // once the cap wins).
        guard let controller = activeController else {
            triggerPendingToastIfMatching()
            return
        }
        let controllerKey = "\(info.track)|\(info.artist)|\(info.album)"
        let fetchTask = Task.detached(priority: .utility) { () throws -> Data? in
            try controller.fetchArtworkData(for: controllerKey)
        }
        let data = await withTaskGroup(of: Data?.self) { group -> Data? in
            group.addTask { try? await fetchTask.value }
            group.addTask {
                try? await Task.sleep(for: .seconds(4))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        // Stale? Drop silently. Fetch or decode failed for the current track?
        // Back off so later polls don't re-run the same slow AppleScript.
        guard ArtworkPipeline.shouldPublish(resultKey: key, currentKey: currentArtworkKey) else { return }
        guard let data else {
            recordFailure(for: key)
            triggerPendingToastIfMatching()
            return
        }
        let (image, color) = await Self.decodeArtwork(data: data)
        guard ArtworkPipeline.shouldPublish(resultKey: key, currentKey: currentArtworkKey) else { return }
        guard let image else {
            recordFailure(for: key)
            triggerPendingToastIfMatching()
            return
        }
        publishArtwork(image, color: color, loadStart: loadStart, key: key)
    }

    private func publishArtwork(_ image: NSImage, color: Color?, loadStart: Date, key: String) {
        guard currentArtworkKey == key else { return }
        lastArtworkFailureKey = nil
        lastArtworkFailureAt = nil
        let ms = Date().timeIntervalSince(loadStart) * 1000
        artworkLogger.debug("artwork published in \(ms, format: .fixed(precision: 1))ms")
        artwork = image
        dominantColor = color ?? ArtworkCache.extractDominantColor(from: image)
        triggerPendingToastIfMatching()
    }

    private func recordFailure(for key: String) {
        lastArtworkFailureKey = key
        lastArtworkFailureAt = Date()
        currentArtworkKey = nil
        artwork = nil
    }

    private func triggerPendingToastIfMatching() {
        guard let toast = self.pendingToast else { return }
        self.pendingToast = nil

        if settings.showTrackNotifications,
           !MenuBarManager.shared.isHoverPopoverShown,
           !AmbientModeManager.shared.isPresented {
            HUDToastManager.shared.show(
                track: toast.track,
                artist: toast.artist,
                artwork: self.artwork
            )
        }
    }

    /// Decodes raw image bytes and extracts the dominant color, entirely off
    /// the main actor. The artworkData path (Apple Music) uses this; the URL
    /// path goes through `downloadArtworkAndColor`.
    nonisolated private static func decodeArtwork(data: Data) async -> (NSImage?, Color?) {
        let start = Date()
        guard let image = RemoteResourceSecurity.safeImage(from: data) else {
            return (nil, nil)
        }
        let color = ArtworkCache.extractDominantColor(from: image)
        artworkLogger.debug("artwork decode+color \(Date().timeIntervalSince(start) * 1000, format: .fixed(precision: 1))ms")
        return (image, color)
    }

    nonisolated private static func downloadArtworkAndColor(from rawURL: URL) async -> (NSImage?, Color?) {
        let url = ArtworkPipeline.optimizeArtworkURL(rawURL)
        let lookupStart = Date()
        if let cached = ArtworkCache.shared.entry(for: url) {
            let ms = Date().timeIntervalSince(lookupStart) * 1000
            artworkLogger.debug("artwork cache hit: \(ms, format: .fixed(precision: 1))ms")
            return (cached.image, cached.color)
        }
        let downloadStart = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let data = try? await SecureRemoteResource.data(for: request, kind: .artwork),
              let image = RemoteResourceSecurity.safeImage(from: data) else {
            artworkLogger.debug("artwork download failed after \(Date().timeIntervalSince(downloadStart) * 1000, format: .fixed(precision: 1))ms")
            return (nil, nil)
        }
        let decodeStart = Date()
        let color = ArtworkCache.extractDominantColor(from: image)
        let totalMs = Date().timeIntervalSince(downloadStart) * 1000
        artworkLogger.debug("artwork download+decode \(totalMs, format: .fixed(precision: 1))ms (decode/color \(Date().timeIntervalSince(decodeStart) * 1000, format: .fixed(precision: 1))ms)")
        ArtworkCache.shared.store(image: image, color: color, data: data, for: url)
        return (image, color)
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
