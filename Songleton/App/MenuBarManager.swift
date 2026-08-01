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
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PlayerPanelView(model: NowPlayingModel.shared)
        )
        self.popover = popover

        // Create single unified NSStatusItem with variable length
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let stackView = MenuBarUnifiedStackView(
            model: NowPlayingModel.shared,
            settings: SettingsModel.shared,
            onTogglePanel: { [weak self] in
                self?.togglePopover()
            }
        )

        let hosting = NSHostingView(rootView: stackView)
        // Calculate initial dynamic size
        let initialWidth = SettingsModel.shared.menuBarWidth + 90
        hosting.frame = NSRect(x: 0, y: 0, width: initialWidth, height: 22)
        hosting.autoresizingMask = [.width, .height]

        // Crucial: Use item.view directly so sub-buttons receive independent click events
        item.view = hosting

        self.hostingView = hosting
        self.statusItem = item
    }

    func updateWidth() {
        guard let hostingView = hostingView, let statusItem = statusItem else { return }
        let newWidth = SettingsModel.shared.menuBarWidth + 90
        hostingView.frame = NSRect(x: 0, y: 0, width: newWidth, height: 22)
        statusItem.length = newWidth
    }

    func togglePopover() {
        guard let popover = popover, let view = statusItem?.view ?? statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }
}
