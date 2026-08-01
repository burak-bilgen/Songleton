import AppKit
import SwiftUI

// MARK: - MenuBarManager

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var stackNSView: MenuBarStackNSView?

    private override init() {
        super.init()
    }

    func setup() {
        guard statusItem == nil else { return }

        // Create NSPopover for PlayerPanelView
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PlayerPanelView(model: NowPlayingModel.shared)
        )
        self.popover = popover

        // Create single unified NSStatusItem with variable length
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let stackView = MenuBarStackNSView(
            model: NowPlayingModel.shared,
            settings: SettingsModel.shared,
            onTogglePanel: { [weak self] in
                self?.togglePopover()
            }
        )

        item.view = stackView
        self.stackNSView = stackView
        self.statusItem = item

        updateWidth()
    }

    func updateWidth() {
        guard let stackNSView = stackNSView, let statusItem = statusItem else { return }
        stackNSView.updateLayout()
        statusItem.length = stackNSView.frame.width
    }

    func togglePopover() {
        guard let popover = popover, let view = statusItem?.view else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }
}
