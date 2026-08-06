import AppKit
import Combine
import SwiftUI

@MainActor
final class EasterEggManager: ObservableObject {
    static let shared = AppContainer.shared.easterEgg

    @Published private(set) var isPresented = false
    @Published private(set) var tapProgress: Int = 0

    private var tapCount: Int = 0
    private var lastTapTime: Date = .distantPast
    private var window: NSWindow?
    private var resetWorkItem: DispatchWorkItem?
    private var keyMonitor: Any?

    let playlistURLString = "https://open.spotify.com/playlist/5E8nulnUsbxaCuv6D8pnIg?si=f1f4e70057584f44"
    let playlistURI = "spotify:playlist:5E8nulnUsbxaCuv6D8pnIg"

    init() {}

    func registerAlbumTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

        // Count rapid consecutive taps (within 1.8s of each other)
        if timeSinceLastTap > 1.8 {
            tapCount = 1
        } else {
            tapCount += 1
        }
        lastTapTime = now

        tapProgress = tapCount

        // Reset progress after 2.0s of inactivity
        resetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.tapCount = 0
            self?.tapProgress = 0
        }
        resetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)

        // Haptic feedback on tap
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

        // 5 consecutive rapid taps!
        if tapCount >= 5 {
            tapCount = 0
            tapProgress = 0
            resetWorkItem?.cancel()
            triggerEasterEgg()
        }
    }

    func triggerEasterEgg() {
        // 1. Show topmost full screen transparent overlay FIRST
        show()

        // 2. Start Spotify playlist shuffle playback in background without pulling Spotify to front
        startSpotifyPlaylistShuffle()
    }

    func checkIsSpotifyActive() -> Bool {
        if let name = NowPlayingModel.shared.activeControllerDisplayName?.lowercased(),
           name.contains("spotify") {
            return true
        }
        if case .loaded(_, let source) = NowPlayingModel.shared.state,
           source.lowercased().contains("spotify") {
            return true
        }
        return SpotifyController().isRunning
    }

    func startSpotifyPlaylistShuffle() {
        let script = """
        tell application "Spotify"
            set shuffling to true
            play track "\(playlistURI)"
        end tell
        """
        do {
            try AppleScriptRunner.run(script)
        } catch {
            if let url = URL(string: playlistURI) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func show() {
        guard !isPresented else { return }

        // Close hover panel popover if open
        MenuBarManager.shared.closeVolumePopoverImmediately()

        let pointerLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let easterEggView = EasterEggView(
            onOpenSpotify: { [weak self] in
                guard let self else { return }
                if let url = URL(string: self.playlistURLString) {
                    NSWorkspace.shared.open(url)
                }
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isReleasedWhenClosed = false
        // Place window at screenSaver level (ABOVE Spotify and all other windows!)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: easterEggView)
        window.setFrame(screen.frame, display: true)

        self.window = window
        self.isPresented = true

        NSApp.setActivationPolicy(.regular)
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }

        setupKeyMonitor()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false

        removeKeyMonitor()

        if let win = window {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                win.animator().alphaValue = 0.0
            }, completionHandler: {
                Task { @MainActor in
                    win.orderOut(nil)
                    win.contentView = nil
                    win.close()
                }
            })
        }
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isPresented else { return event }
            if event.keyCode == 53 { // ESC key
                self.dismiss()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
