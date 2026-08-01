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
        return SettingsModel.shared.showArtistInMenuBar
            ? "\(info.track) - \(info.artist)"
            : info.track
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

    /// Triggers the macOS "Songleton wants to control X" permission dialog
    /// by actually executing an AppleScript targeting each player app.
    func requestPermissionByScript() {
        var results: [String] = []

        for controller in controllers {
            let src = """
            tell application "\(controller.scriptAppName)"
                get name
            end tell
            """
            guard let script = NSAppleScript(source: src) else {
                results.append("❌ \(controller.displayName): Script oluşturulamadı")
                continue
            }
            var errDict: NSDictionary?
            let result = script.executeAndReturnError(&errDict)

            if let err = errDict {
                let code    = err[NSAppleScript.errorNumber] as? Int ?? 0
                let message = err[NSAppleScript.errorMessage] as? String ?? "Bilinmeyen hata"
                if code == -1743 {
                    results.append("🔒 \(controller.displayName): İzin reddedildi (kod: \(code))")
                } else if code == -600 {
                    results.append("⚠️ \(controller.displayName): Uygulama çalışmıyor (kod: \(code))")
                } else {
                    results.append("❌ \(controller.displayName): \(message) (kod: \(code))")
                }
            } else {
                results.append("✅ \(controller.displayName): İzin alındı — \(result.stringValue ?? "ok")")
            }
        }

        // Show debug alert with results
        let alert = NSAlert()
        alert.messageText = "İzin İsteği Sonucu"
        alert.informativeText = results.joined(separator: "\n\n")
        alert.alertStyle = results.allSatisfy({ $0.hasPrefix("✅") }) ? .informational : .warning
        alert.addButton(withTitle: "Tamam")
        alert.runModal()

        checkAutomationPermission(askUser: false)
        refresh()
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
            dominantColor = color ?? .accentColor
        }
    }

    private func extractColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .accentColor
        }
        let width = 8
        let height = 8
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .accentColor }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        let count = CGFloat(width * height)
        for i in 0..<(width * height) {
            r += CGFloat(data[i * 4]) / 255.0
            g += CGFloat(data[i * 4 + 1]) / 255.0
            b += CGFloat(data[i * 4 + 2]) / 255.0
        }
        // Boost saturation to make color more vibrant
        let avg = (r / count + g / count + b / count) / 3
        let boost: CGFloat = 1.4
        let fr = min(1, avg + (r / count - avg) * boost)
        let fg = min(1, avg + (g / count - avg) * boost)
        let fb = min(1, avg + (b / count - avg) * boost)
        return Color(red: fr, green: fg, blue: fb)
    }

    nonisolated private static func downloadArtworkAndColor(from url: URL) async -> (NSImage?, Color?) {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return (nil, nil) }
        return (image, nil) // color extracted on main after
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
