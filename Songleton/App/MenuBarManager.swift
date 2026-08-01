import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarManager

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var bwdStatusItem: NSStatusItem?
    private var mainStatusItem: NSStatusItem?
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

        // 2. Forward Status Item [⏭] (Created 1st -> Placed on the Far Right)
        let fwdItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = fwdItem.button {
            button.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Sonraki Şarkı")
            button.target = self
            button.action = #selector(fwdTapped)
            button.toolTip = "Sonraki Şarkı"
        }
        self.fwdStatusItem = fwdItem

        // 3. Main Status Item: [ Artwork + Centered Song Title ] (Created 2nd -> Placed in the Center)
        let mainItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let mainLabel = MenuBarMainLabelView(
            model: NowPlayingModel.shared,
            settings: SettingsModel.shared
        )
        let hosting = NSHostingView(rootView: mainLabel)
        let fittingWidth = max(80, min(hosting.fittingSize.width + 12, SettingsModel.shared.menuBarWidth + 30))
        hosting.frame = NSRect(x: 0, y: 0, width: fittingWidth, height: 22)
        hosting.autoresizingMask = [.width, .height]

        if let button = mainItem.button {
            button.addSubview(hosting)
            button.frame = hosting.frame
            button.target = self
            button.action = #selector(mainItemTapped)
        } else {
            mainItem.view = hosting
        }
        mainItem.length = fittingWidth
        self.mainStatusItem = mainItem

        // 4. Backward Status Item [⏮] (Created 3rd -> Placed on the Far Left)
        let bwdItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = bwdItem.button {
            button.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Önceki Şarkı")
            button.target = self
            button.action = #selector(bwdTapped)
            button.toolTip = "Önceki Şarkı"
        }
        self.bwdStatusItem = bwdItem

        // Listen to title changes to adjust menu bar width dynamically without empty space
        NowPlayingModel.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWidth()
            }
            .store(in: &cancellables)
    }

    func updateWidth() {
        guard let mainItem = mainStatusItem, let button = mainItem.button else { return }
        if let hosting = button.subviews.first as? NSHostingView<MenuBarMainLabelView> {
            let fittingWidth = max(80, min(hosting.fittingSize.width + 12, SettingsModel.shared.menuBarWidth + 30))
            let newFrame = NSRect(x: 0, y: 0, width: fittingWidth, height: 22)
            hosting.frame = newFrame
            button.frame = newFrame
            mainItem.length = fittingWidth
        }
    }

    // MARK: - Actions

    @objc private func mainItemTapped() {
        togglePopover()
    }

    @objc private func bwdTapped() {
        NowPlayingModel.shared.previousTrack()
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
