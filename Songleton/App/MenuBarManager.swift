import AppKit
import SwiftUI

// MARK: - MenuBarManager

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hostingView: NSHostingView<MenuBarUnifiedStackView>?

    private override init() {
        super.init()
    }

    func setup() {
        guard statusItem == nil else { return }

        // Create NSPopover for PlayerPanelView
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PlayerPanelView(model: NowPlayingModel.shared)
        )
        self.popover = popover

        // Create single unified NSStatusItem
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let stackView = MenuBarUnifiedStackView(
            model: NowPlayingModel.shared,
            settings: SettingsModel.shared,
            onTogglePanel: { [weak self] in
                self?.togglePopover()
            }
        )

        let hosting = NSHostingView(rootView: stackView)
        hosting.frame = NSRect(x: 0, y: 0, width: 220, height: 22)
        hosting.autoresizingMask = [.width, .height]

        if let button = item.button {
            button.addSubview(hosting)
            button.frame = hosting.frame
        } else {
            item.view = hosting
        }

        self.hostingView = hosting
        self.statusItem = item
    }

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
