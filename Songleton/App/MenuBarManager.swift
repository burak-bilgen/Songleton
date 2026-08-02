import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var bwdStatusItem: NSStatusItem?
    private var mainStatusItem: NSStatusItem?
    private var fwdStatusItem: NSStatusItem?

    private var volumePopover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var hoverWorkItem: DispatchWorkItem?
    private var closeWorkItem: DispatchWorkItem?

    var mainButton: NSStatusBarButton? { mainStatusItem?.button }

    var isHoverPopoverShown: Bool {
        volumePopover?.isShown == true
    }

    private override init() { super.init() }

    func setup() {
        guard mainStatusItem == nil else { return }

        // Hover ile Açılan Birleşik Modern Detay & Ses Ayar Paneli
        let volPopover = NSPopover()
        volPopover.behavior = .transient
        volPopover.animates = true
        let hostingController = NSHostingController(rootView: UnifiedHoverPanelView())
        hostingController.sizingOptions = [.preferredContentSize]
        volPopover.contentViewController = hostingController
        self.volumePopover = volPopover

        // AppKit appends status items from Left to Right.
        // Desired Screen Layout (Left to Right):
        // [ ⏮ ]  [ Albüm Kapağı & Şarkı Adı ]  [ ⏭ ]

        // 1st created: Önceki Şarkı (Pos 1 - En Sol)
        let bwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = bwdItem.button {
            button.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(bwdTapped)
            button.toolTip = NSLocalizedString("Önceki Şarkı", comment: "Previous track")
        }
        self.bwdStatusItem = bwdItem

        // 2nd created: Albüm Kapağı & Şarkı Adı (Pos 2 - Ortada)
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
            button.sendAction(on: [.leftMouseUp])
            button.toolTip = NSLocalizedString("Tıkla: Oynat/Durdur | Hover: Detay & Ses Paneli", comment: "Menu bar tooltip")

            let trackingView = MenuBarTrackingAreaView(frame: button.bounds)
            trackingView.autoresizingMask = [.width, .height]
            trackingView.onMouseEntered = { [weak self] in
                self?.showVolumePopover()
            }
            trackingView.onMouseExited = { [weak self] in
                self?.scheduleCloseVolumePopover()
            }
            button.addSubview(trackingView)
        }
        mainItem.length = fittingWidth
        self.mainStatusItem = mainItem

        // 3rd created: Sonraki Şarkı (Pos 3 - En Sağ)
        let fwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = fwdItem.button {
            button.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(fwdTapped)
            button.toolTip = NSLocalizedString("Sonraki Şarkı", comment: "Next track")
        }
        self.fwdStatusItem = fwdItem

        NowPlayingModel.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                let isNotRunning: Bool
                if case .notRunning = state { isNotRunning = true } else { isNotRunning = false }
                self?.mainStatusItem?.isVisible = !isNotRunning
                self?.bwdStatusItem?.isVisible = !isNotRunning
                self?.fwdStatusItem?.isVisible = !isNotRunning
                self?.updateWidth()
            }
            .store(in: &cancellables)

        SettingsModel.shared.$menuBarWidth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateWidth() }
            .store(in: &cancellables)
    }

    func updateWidth() {
        guard let mainItem = mainStatusItem, let button = mainItem.button else { return }
        guard volumePopover?.isShown != true else { return }
        if let hosting = button.subviews.first as? NSHostingView<MenuBarMainLabelView> {
            hosting.invalidateIntrinsicContentSize()
            let fittingWidth = min(max(50, hosting.fittingSize.width + 4), SettingsModel.shared.menuBarWidth + 16)
            let newFrame = NSRect(x: 0, y: 0, width: fittingWidth, height: 22)
            hosting.frame = newFrame
            button.frame = newFrame
            mainItem.length = fittingWidth
        }
    }

    @objc private func mainItemClicked() {
        if let type = NSApp.currentEvent?.type, type == .rightMouseUp || type == .rightMouseDown {
            return
        }
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()
        if let volPopover = volumePopover, volPopover.isShown {
            volPopover.performClose(nil)
        }
        NowPlayingModel.shared.togglePlayPause()
    }

    @objc private func bwdTapped() {
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()
        NowPlayingModel.shared.previousTrack()
    }

    @objc private func fwdTapped() {
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()
        NowPlayingModel.shared.nextTrack()
    }

    func showVolumePopover() {
        guard let volPopover = volumePopover, let button = mainStatusItem?.button else { return }
        closeWorkItem?.cancel()

        if volPopover.isShown { return }

        hoverWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let button = self.mainStatusItem?.button else { return }
            guard self.volumePopover?.isShown != true else { return }
            self.volumePopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        hoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    func scheduleCloseVolumePopover() {
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self, let volPopover = self.volumePopover, volPopover.isShown else { return }
            let mouseLocation = NSEvent.mouseLocation

            var isInsideButton = false
            if let button = self.mainStatusItem?.button, let window = button.window {
                let buttonRect = button.convert(button.bounds, to: nil)
                let windowRect = window.convertToScreen(buttonRect)
                isInsideButton = windowRect.contains(mouseLocation)
            }

            var isInsidePopover = false
            if let popoverWindow = volPopover.contentViewController?.view.window {
                let popoverRect = popoverWindow.frame
                isInsidePopover = popoverRect.contains(mouseLocation)
            }

            if !isInsideButton && !isInsidePopover {
                volPopover.performClose(nil)
            } else if isInsideButton || isInsidePopover {
                self.scheduleCloseVolumePopover()
            }
        }
        closeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
    }
}

// MARK: - MenuBarTrackingAreaView

final class MenuBarTrackingAreaView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
