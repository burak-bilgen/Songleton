import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var bwdStatusItem: NSStatusItem?
    private var mainStatusItem: NSStatusItem?
    private var fwdStatusItem: NSStatusItem?
    private var volStatusItems: [NSStatusItem] = []

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

        // 1st: bwd
        let bwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = bwdItem.button {
            button.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(bwdTapped)
            button.toolTip = NSLocalizedString("Önceki Şarkı", comment: "Previous track")
        }
        self.bwdStatusItem = bwdItem

        // 2nd: main track info
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

        // 3rd: fwd
        let fwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = fwdItem.button {
            button.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(fwdTapped)
            button.toolTip = NSLocalizedString("Sonraki Şarkı", comment: "Next track")
        }
        self.fwdStatusItem = fwdItem

        // 4th to 8th: 5 separate volume status items (created 5 down to 1 so they display 1 to 5 left-to-right)
        var items: [NSStatusItem] = []
        for i in stride(from: 5, through: 1, by: -1) {
            let item = NSStatusBar.system.statusItem(withLength: 10)
            if let button = item.button {
                let barView = NSHostingView(rootView: VolumeBarItemView(barIndex: i))
                barView.frame = NSRect(x: 0, y: 0, width: 10, height: 22)
                barView.autoresizingMask = [.width, .height]
                button.addSubview(barView)
                button.frame = NSRect(x: 0, y: 0, width: 10, height: 22)
                button.tag = i
                button.target = self
                button.action = #selector(volumeBarTapped(_:))
                button.toolTip = "%\(i * 20)"
            }
            items.append(item)
        }
        self.volStatusItems = items

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

    @objc private func volumeBarTapped(_ sender: NSButton) {
        let level = sender.tag * 20
        NowPlayingModel.shared.setVolume(level)
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
