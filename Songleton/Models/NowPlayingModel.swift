import AppKit
import Combine
import SwiftUI

// MARK: - Recent Track

struct RecentTrack: Identifiable {
    let id = UUID()
    let track: String
    let artist: String
    let source: String
    let playedAt: Date
}

// MARK: - NowPlayingModel

@MainActor
final class NowPlayingModel: ObservableObject {
    static let shared = NowPlayingModel()

    enum State {
        case notRunning
        case permissionDenied
        case loaded(NowPlayingInfo, source: String)
    }

    enum AutomationStatus {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var state: State = .notRunning
    @Published private(set) var artwork: NSImage?
    @Published private(set) var dominantColor: Color = .accentColor
    @Published var automationStatus: AutomationStatus = .unknown
    @Published private(set) var recentTracks: [RecentTrack] = []

    let controllers: [any MediaController] = [SpotifyController(), AppleMusicController()]
    private var activeController: (any MediaController)?
    private var isFetching = false
    private var currentArtworkKey: String?
    private var cancellables = Set<AnyCancellable>()
    private var lastLoadedKey: String?

    private init() {
        SettingsModel.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        refresh()
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    // MARK: - Computed

    var menuBarTitle: String? {
        guard case .loaded(let info, _) = state else { return nil }
        return info.track
    }

    var activeBundleID: String? { activeController?.bundleID }

    // MARK: - Controls

    func togglePlayPause() { send { try $0.togglePlayPause() } }
    func nextTrack() { send { try $0.nextTrack() } }
    func previousTrack() { send { try $0.previousTrack() } }
    func restartTrack() { send { try $0.restartTrack() } }
    func setVolume(_ volume: Int) { send { try $0.setVolume(volume) } }
    func seekTo(_ position: Double) { send { try $0.seekTo(position) } }

    // MARK: - Permissions

    /// Checks automation permission status.
    /// IMPORTANT: AEDeterminePermissionToAutomateTarget must be called from
    /// the main thread — otherwise macOS cannot show the permission dialog.
    /// Since NowPlayingModel is @MainActor, this method already runs on main.
    func checkAutomationPermission(askUser: Bool) {
        var allGranted = true
        var anyDenied  = false

        for controller in controllers {
            let status = AutomationPermission.status(bundleID: controller.bundleID, askUser: askUser)
            switch status {
            case noErr:
                continue
            case OSStatus(errAEEventNotPermitted):
                allGranted = false
                anyDenied  = true
            default:
                allGranted = false
            }
        }

        let result: AutomationStatus = allGranted ? .granted : (anyDenied ? .denied : .unknown)
        automationStatus = result
        if result == .granted {
            UserDefaults.standard.set(true, forKey: "hasGrantedAutomation")
        }
    }

    /// Checks status for a specific app bundle identifier
    func permissionStatus(for bundleID: String, askUser: Bool = false) -> AutomationStatus {
        let status = AutomationPermission.status(bundleID: bundleID, askUser: askUser)
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .unknown
        }
    }

    /// Triggers macOS permission prompt for a specific player app
    func requestPermissionFor(bundleID: String) {
        guard let controller = controllers.first(where: { $0.bundleID == bundleID }) else { return }
        
        // Try AEDeterminePermissionToAutomateTarget first with askUser: true
        _ = AutomationPermission.status(bundleID: bundleID, askUser: true)

        // Fallback: run AppleScript to ensure macOS triggers dialog
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

    /// Triggers the macOS "Songleton wants to control X" permission dialog
    /// by actually executing an AppleScript targeting each player app.
    func requestPermissionByScript() {
        for controller in controllers {
            requestPermissionFor(bundleID: controller.bundleID)
        }
        checkAutomationPermission(askUser: false)
        refresh()
    }


    /// Copies currently playing track and artist to system pasteboard
    func copyTrackInfo() -> String? {
        guard case .loaded(let info, _) = state else { return nil }
        let text = "\(info.track) - \(info.artist)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return text
    }

    // MARK: - Refresh

    func refresh() {
        guard !isFetching else { return }
        isFetching = true
        Task {
            let result = await fetchAll()
            if let result {
                // Track change → add to recents
                if case .loaded(let info, let src) = result.state {
                    let key = "\(info.track)|\(info.artist)"
                    if key != lastLoadedKey {
                        lastLoadedKey = key
                        let recent = RecentTrack(track: info.track, artist: info.artist, source: src, playedAt: Date())
                        recentTracks.insert(recent, at: 0)
                        if recentTracks.count > 20 { recentTracks = Array(recentTracks.prefix(20)) }

                        // Trigger HUD popup toast on song change
                        HUDToastManager.shared.show(
                            track: info.track,
                            artist: info.artist,
                            artwork: artwork,
                            source: src
                        )
                    }
                }
                state = result.state
                activeController = result.active
                await syncArtwork(with: result.state)
            }
            isFetching = false
        }
    }

    // MARK: - Fetch All

    private struct FetchResult {
        let state: State
        let active: (any MediaController)?
    }

    nonisolated private func fetchAll() async -> FetchResult? {
        var pausedCandidate: (any MediaController, NowPlayingInfo)?
        var sawPermissionDenied = false
        var anyRunning = false

        for controller in controllers {
            guard controller.isRunning else { continue }
            anyRunning = true
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
        if sawPermissionDenied {
            return FetchResult(state: .permissionDenied, active: nil)
        }
        if !anyRunning {
            return FetchResult(state: .notRunning, active: nil)
        }
        return nil
    }

    // MARK: - Artwork + Color

    private func syncArtwork(with state: State) async {
        guard case .loaded(let info, _) = state else {
            if currentArtworkKey != nil {
                currentArtworkKey = nil
                artwork = nil
                dominantColor = .accentColor
            }
            return
        }
        let key = info.artworkURL?.absoluteString ?? "\(info.track)|\(info.artist)"
        guard key != currentArtworkKey else { return }
        currentArtworkKey = key

        if let data = info.artworkData, let image = NSImage(data: data) {
            artwork = image
            dominantColor = extractColor(from: image)
            return
        }
        guard let url = info.artworkURL else {
            artwork = nil
            dominantColor = .accentColor
            return
        }
        let (image, color) = await Self.downloadArtworkAndColor(from: url)
        if currentArtworkKey == key {
            artwork = image
            dominantColor = color ?? (image != nil ? extractColor(from: image!) : .accentColor)
        }
    }

    private func extractColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .accentColor
        }
        let width = 16
        let height = 16
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

            // Filter out near-black and near-white pixels for better vibrancy
            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let brightness = (maxC + minC) / 2
            let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC

            // Ignore pure black, pure white, or non-saturated pixels unless there are few options
            if brightness > 0.08 && brightness < 0.92 {
                let weight = 1.0 + saturation * 2.0 // Prefer saturated colors
                totalR += r * weight
                totalG += g * weight
                totalB += b * weight
                validPixelCount += weight
            }
        }

        if validPixelCount == 0 {
            return .accentColor
        }

        var avgR = totalR / validPixelCount
        var avgG = totalG / validPixelCount
        var avgB = totalB / validPixelCount

        // Boost saturation for a rich UI background glow
        let avgLuminance = 0.2126 * avgR + 0.7152 * avgG + 0.0722 * avgB
        let boost: CGFloat = 1.35
        avgR = min(1.0, max(0.0, avgLuminance + (avgR - avgLuminance) * boost))
        avgG = min(1.0, max(0.0, avgLuminance + (avgG - avgLuminance) * boost))
        avgB = min(1.0, max(0.0, avgLuminance + (avgB - avgLuminance) * boost))

        return Color(red: avgR, green: avgG, blue: avgB)
    }

    nonisolated private static func downloadArtworkAndColor(from url: URL) async -> (NSImage?, Color?) {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return (nil, nil) }
        return (image, nil)
    }


    // MARK: - Send Command

    private func send(_ action: @escaping @Sendable (any MediaController) throws -> Void) {
        guard let controller = activeController else { return }
        Task.detached {
            try? action(controller)
            try? await Task.sleep(for: .milliseconds(300))
            await self.refresh()
        }
    }
}
