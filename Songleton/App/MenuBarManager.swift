import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarManager

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var mainStatusItem: NSStatusItem?
    private var bwdStatusItem: NSStatusItem?
    private var playPauseStatusItem: NSStatusItem?
    private var fwdStatusItem: NSStatusItem?

    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    func setup() {
        guard mainStatusItem == nil else { return }

        // 1. Create NSPopover for PlayerPanelView
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PlayerPanelView(model: NowPlayingModel.shared)
        )
        self.popover = popover

        // 2. Main Status Item: [ Artwork + Song Marquee Title ] -> Opens Popover
        let mainItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let mainLabel = MenuBarMainLabelView(
            model: NowPlayingModel.shared,
            settings: SettingsModel.shared
        )
        let hosting = NSHostingView(rootView: mainLabel)
        let width = SettingsModel.shared.menuBarWidth + 30
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 22)
        hosting.autoresizingMask = [.width, .height]
        
        if let button = mainItem.button {
            button.addSubview(hosting)
            button.frame = hosting.frame
            button.target = self
            button.action = #selector(mainItemTapped)
        } else {
            mainItem.view = hosting
        }
        self.mainStatusItem = mainItem

        // 3. Forward Status Item [⏭]
        let fwdItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = fwdItem.button {
            button.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Sonraki Şarkı")
            button.target = self
            button.action = #selector(fwdTapped)
            button.toolTip = "Sonraki Şarkı"
        }
        self.fwdStatusItem = fwdItem

        // 4. Play/Pause Status Item [⏯]
        let ppItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = ppItem.button {
            button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Oynat / Duraklat")
            button.target = self
            button.action = #selector(playPauseTapped)
            button.toolTip = "Oynat / Duraklat"
        }
        self.playPauseStatusItem = ppItem

        // 5. Backward Status Item [⏮]
        let bwdItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = bwdItem.button {
            button.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Önceki Şarkı")
            button.target = self
            button.action = #selector(bwdTapped)
            button.toolTip = "Önceki Şarkı"
        }
        self.bwdStatusItem = bwdItem

        // Listen to model state changes to update Play/Pause icon
        NowPlayingModel.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updatePlayPauseIcon(state: state)
            }
            .store(in: &cancellables)
    }

    func updateWidth() {
        guard let mainItem = mainStatusItem, let button = mainItem.button else { return }
        let width = SettingsModel.shared.menuBarWidth + 30
        let newFrame = NSRect(x: 0, y: 0, width: width, height: 22)
        if let hosting = button.subviews.first {
            hosting.frame = newFrame
        }
        button.frame = newFrame
        mainItem.length = width
    }

    private func updatePlayPauseIcon(state: NowPlayingModel.State) {
        let isPlaying: Bool
        if case .loaded(let info, _) = state {
            isPlaying = info.isPlaying
        } else {
            isPlaying = false
        }
        playPauseStatusItem?.button?.image = NSImage(
            systemSymbolName: isPlaying ? "pause.fill" : "play.fill",
            accessibilityDescription: nil
        )
    }

    // MARK: - Actions

    @objc private func mainItemTapped() {
        togglePopover()
    }

    @objc private func bwdTapped() {
        NowPlayingModel.shared.previousTrack()
    }

    @objc private func playPauseTapped() {
        NowPlayingModel.shared.togglePlayPause()
    }

    @objc private func fwdTapped() {
        NowPlayingModel.shared.nextTrack()
    }

    func togglePopover() {
        guard let popover = popover, let button = mainStatusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
