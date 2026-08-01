import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var bwdStatusItem: NSStatusItem?
    private var mainStatusItem: NSStatusItem?
    private var fwdStatusItem: NSStatusItem?

    private var volTextStatusItem: NSStatusItem?
    private var volPlusStatusItem: NSStatusItem?
    private var volMinusStatusItem: NSStatusItem?

    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var lastPreMuteVolume: Int = 50

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

        // 1st: Previous Track (rightmost)
        let bwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = bwdItem.button {
            button.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(bwdTapped)
            button.toolTip = NSLocalizedString("Önceki Şarkı", comment: "Previous track")
        }
        self.bwdStatusItem = bwdItem

        // 2nd: Main Track Info Label
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

        // 3rd: Next Track
        let fwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = fwdItem.button {
            button.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(fwdTapped)
            button.toolTip = NSLocalizedString("Sonraki Şarkı", comment: "Next track")
        }
        self.fwdStatusItem = fwdItem

        // Volume Group Creation (created Minus -> Plus -> Text)
        // Screen left-to-right order: [ %50 ] [ + ] [ - ]

        // 4th created: - Button (rightmost of volume group)
        let minusItem = NSStatusBar.system.statusItem(withLength: 20)
        if let button = minusItem.button {
            button.title = "-"
            button.font = NSFont.systemFont(ofSize: 13, weight: .bold)
            button.target = self
            button.action = #selector(volMinusTapped)
            button.toolTip = NSLocalizedString("Sesi Azalt (-20%)", comment: "Volume Down")
        }
        self.volMinusStatusItem = minusItem

        // 5th created: + Button (middle of volume group)
        let plusItem = NSStatusBar.system.statusItem(withLength: 20)
        if let button = plusItem.button {
            button.title = "+"
            button.font = NSFont.systemFont(ofSize: 13, weight: .bold)
            button.target = self
            button.action = #selector(volPlusTapped)
            button.toolTip = NSLocalizedString("Sesi Artır (+20%)", comment: "Volume Up")
        }
        self.volPlusStatusItem = plusItem

        // 6th created: Volume Percentage Text Display (leftmost of volume group)
        let textItem = NSStatusBar.system.statusItem(withLength: 34)
        let textHosting = NSHostingView(rootView: VolumePercentTextView())
        textHosting.frame = NSRect(x: 0, y: 0, width: 34, height: 22)
        textHosting.autoresizingMask = [.width, .height]
        if let button = textItem.button {
            button.addSubview(textHosting)
            button.frame = textHosting.frame
            button.target = self
            button.action = #selector(volTextTapped)
            button.toolTip = NSLocalizedString("Sesi Kapat / Aç (Sessiz)", comment: "Toggle Mute")
        } else {
            textItem.view = textHosting
        }
        self.volTextStatusItem = textItem

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

    @objc private func volMinusTapped() {
        guard case .loaded(let info, _) = NowPlayingModel.shared.state else { return }
        let newVol = max(0, info.volume - 20)
        NowPlayingModel.shared.setVolume(newVol)
    }

    @objc private func volPlusTapped() {
        guard case .loaded(let info, _) = NowPlayingModel.shared.state else { return }
        let newVol = min(100, info.volume + 20)
        NowPlayingModel.shared.setVolume(newVol)
    }

    @objc private func volTextTapped() {
        guard case .loaded(let info, _) = NowPlayingModel.shared.state else { return }
        if info.volume > 0 {
            lastPreMuteVolume = info.volume
            NowPlayingModel.shared.setVolume(0)
        } else {
            NowPlayingModel.shared.setVolume(lastPreMuteVolume > 0 ? lastPreMuteVolume : 50)
        }
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
