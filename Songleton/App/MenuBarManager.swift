import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarManager

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private override init() {
        super.init()
    }

    func setup() {
        guard statusItem == nil else { return }

        // 1. Create NSPopover for PlayerPanelView
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PlayerPanelView(model: NowPlayingModel.shared)
        )
        self.popover = popover

        // 2. Single Unified Status Item containing [bwd] [Artwork + Text] [fwd]
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let unifiedView = MenuBarMainLabelView(
            model: NowPlayingModel.shared,
            settings: SettingsModel.shared,
            onPrevious: { NowPlayingModel.shared.previousTrack() },
            onNext: { NowPlayingModel.shared.nextTrack() },
            onOpenPanel: { [weak self] in self?.togglePopover() }
        )
        let hosting = NSHostingView(rootView: unifiedView)
        let totalWidth = SettingsModel.shared.menuBarWidth + 74
        hosting.frame = NSRect(x: 0, y: 0, width: totalWidth, height: 22)
        hosting.autoresizingMask = [.width, .height]

        if let button = item.button {
            button.addSubview(hosting)
            button.frame = hosting.frame
        } else {
            item.view = hosting
        }
        item.length = totalWidth
        self.statusItem = item
    }

    func updateWidth() {
        guard let statusItem = statusItem, let button = statusItem.button else { return }
        let totalWidth = SettingsModel.shared.menuBarWidth + 74
        let newFrame = NSRect(x: 0, y: 0, width: totalWidth, height: 22)
        if let hosting = button.subviews.first {
            hosting.frame = newFrame
        }
        button.frame = newFrame
        statusItem.length = totalWidth
    }

    // MARK: - Actions

    func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
