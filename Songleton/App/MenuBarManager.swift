import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var bwdStatusItem: NSStatusItem?
    private var mainStatusItem: NSStatusItem?
    private var fwdStatusItem: NSStatusItem?
    private var volSliderItem: NSStatusItem?

    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    var mainButton: NSStatusBarButton? { mainStatusItem?.button }

    private override init() {
        super.init()
    }

    func setup() {
        guard mainStatusItem == nil else { return }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 460)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PlayerPanelView(model: NowPlayingModel.shared)
        )
        self.popover = popover

        // bwd — created 1st, appears rightmost
        let bwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = bwdItem.button {
            button.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(bwdTapped)
            button.toolTip = NSLocalizedString("Önceki Şarkı", comment: "Previous track")
        }
        self.bwdStatusItem = bwdItem

        // main — created 2nd, appears center
        let mainItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let mainLabel = MenuBarMainLabelView(model: NowPlayingModel.shared, settings: SettingsModel.shared)
        let hosting = NSHostingView(rootView: mainLabel)
        let fittingWidth = min(max(50, hosting.fittingSize.width + 4), SettingsModel.shared.menuBarWidth + 16)
        hosting.frame = NSRect(x: 0, y: 0, width: fittingWidth, height: 22)
        hosting.autoresizingMask = [.width, .height]

        if let button = mainItem.button {
            button.addSubview(hosting)
            button.frame = hosting.frame
            button.target = self
            button.action = #selector(mainItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = NSLocalizedString("Sol Tık: Oynat/Durdur | Sağ Tık: Detay Paneli", comment: "Menu bar tooltip")
        } else {
            mainItem.view = hosting
        }
        mainItem.length = fittingWidth
        self.mainStatusItem = mainItem

        // fwd — created 3rd, appears left of main
        let fwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = fwdItem.button {
            button.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(fwdTapped)
            button.toolTip = NSLocalizedString("Sonraki Şarkı", comment: "Next track")
        }
        self.fwdStatusItem = fwdItem

        // volume slider — single item, created last → appears leftmost
        // Uses statusItem.view so the custom NSView can capture drag events
        let volItem = NSStatusBar.system.statusItem(withLength: 60)
        let volView = VolumeStatusNSView(frame: NSRect(x: 0, y: 0, width: 60, height: 22))
        volItem.view = volView
        self.volSliderItem = volItem

        NowPlayingModel.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateWidth() }
            .store(in: &cancellables)
    }

    func updateWidth() {
        guard let mainItem = mainStatusItem, let button = mainItem.button else { return }
        guard popover?.isShown != true else { return }
        if let hosting = button.subviews.first as? NSHostingView<MenuBarMainLabelView> {
            let fittingWidth = min(max(50, hosting.fittingSize.width + 4), SettingsModel.shared.menuBarWidth + 16)
            let newFrame = NSRect(x: 0, y: 0, width: fittingWidth, height: 22)
            hosting.frame = newFrame
            button.frame = newFrame
            mainItem.length = fittingWidth
        }
    }

    @objc private func mainItemClicked() {
        guard let event = NSApp.currentEvent else { togglePopover(); return }
        if event.type == .rightMouseUp {
            togglePopover()
        } else {
            if let popover = popover, popover.isShown {
                popover.performClose(nil)
            } else {
                NowPlayingModel.shared.togglePlayPause()
            }
        }
    }

    @objc private func bwdTapped() { NowPlayingModel.shared.previousTrack() }
    @objc private func fwdTapped() { NowPlayingModel.shared.nextTrack() }

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
