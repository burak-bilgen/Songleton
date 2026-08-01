import AppKit
import SwiftUI

@MainActor
final class HUDToastManager: NSObject {
    static let shared = HUDToastManager()

    private var popover: NSPopover?
    private var dismissTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func show(track: String, artist: String, artwork: NSImage?, source: String) {
        dismissTask?.cancel()

        if let popover, popover.isShown {
            popover.performClose(nil)
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 290, height: 60)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: HUDToastView(track: track, artist: artist, artwork: artwork, source: source)
        )
        self.popover = popover

        if let button = MenuBarManager.shared.mainButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(3.0))
            if !Task.isCancelled {
                popover.performClose(nil)
            }
        }
    }
}
