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
    private var globalClickMonitor: Any? = nil

    var mainButton: NSStatusBarButton? { mainStatusItem?.button }

    var isHoverPopoverShown: Bool {
        volumePopover?.isShown == true
    }

    private override init() { super.init() }

    func setup() {
        guard mainStatusItem == nil else { return }
        MouseGestureManager.shared.updateMonitoring()

        // Unified detail and volume panel opened on hover.
        let volPopover = NSPopover()
        volPopover.behavior = .transient
        volPopover.animates = true
        let hostingController = NSHostingController(rootView: UnifiedHoverPanelView())
        hostingController.sizingOptions = [.preferredContentSize]
        volPopover.contentViewController = hostingController
        self.volumePopover = volPopover

        // AppKit places status items from right to left as they are created.
        // To achieve [Song Title] [Next Track ▶] [Previous Track ◀] from left to right:
        // 1. Create bwdItem (Rightmost)
        // 2. Create fwdItem (Middle)
        // 3. Create mainItem (Leftmost)

        // 1. Previous track item (Rightmost).
        let bwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = bwdItem.button {
            button.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(bwdTapped)
            button.toolTip = LocalizationManager.shared.string("menu.previous_track")
        }
        self.bwdStatusItem = bwdItem

        // 2. Next track item (Middle).
        let fwdItem = NSStatusBar.system.statusItem(withLength: 22)
        if let button = fwdItem.button {
            button.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(fwdTapped)
            button.toolTip = LocalizationManager.shared.string("menu.next_track")
        }
        self.fwdStatusItem = fwdItem

        // 3. Album artwork and track label item (Leftmost).
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
            button.toolTip = LocalizationManager.shared.string("menu.main_item_tooltip")

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

        // Always ensure menu bar status items remain visible
        setStatusItemsVisible(true)

        NowPlayingModel.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateStatusItemVisibility(for: state)
            }
            .store(in: &cancellables)

        SettingsModel.shared.$menuBarWidth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateWidth() }
            .store(in: &cancellables)

        LocalizationManager.shared.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTooltips() }
            .store(in: &cancellables)
    }

    private func updateTooltips() {
        bwdStatusItem?.button?.toolTip = LocalizationManager.shared.string("menu.previous_track")
        mainStatusItem?.button?.toolTip = LocalizationManager.shared.string("menu.main_item_tooltip")
        fwdStatusItem?.button?.toolTip = LocalizationManager.shared.string("menu.next_track")
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

    private func updateStatusItemVisibility(for state: NowPlayingModel.State) {
        setStatusItemsVisible(true)
    }

    func refreshNavButtonVisibility() {
        setStatusItemsVisible(true)
    }

    func setStatusItemsVisible(_ isVisible: Bool) {
        let navVisible = isVisible && SettingsModel.shared.showMenuBarNavButtons
        mainStatusItem?.isVisible = isVisible
        bwdStatusItem?.isVisible = navVisible
        fwdStatusItem?.isVisible = navVisible
        if isVisible { updateWidth() }
    }

    private var isBlockedByGuide: Bool {
        let isOnboardingOpen = NSApp.windows.contains(where: { $0.identifier?.rawValue == "onboardingWindow" && $0.isVisible })
        return isOnboardingOpen || GestureTutorialManager.shared.isPresented
    }

    @objc private func mainItemClicked() {
        if isBlockedByGuide { return }

        if let event = NSApp.currentEvent, (event.type == .rightMouseUp || event.type == .rightMouseDown) {
            closeVolumePopoverImmediately()

            // Option/Alt key held -> Show Context Menu (Settings, Onboarding, Quit)
            if event.modifierFlags.contains(.option) {
                let menu = NSMenu()
                let settingsItem = NSMenuItem(title: LocalizationManager.shared.string("menu.settings"), action: #selector(openSettingsMenu), keyEquivalent: ",")
                settingsItem.target = self
                menu.addItem(settingsItem)

                let onboardingItem = NSMenuItem(title: LocalizationManager.shared.string("menu.onboarding"), action: #selector(openOnboardingGuide), keyEquivalent: "o")
                onboardingItem.target = self
                menu.addItem(onboardingItem)

                menu.addItem(NSMenuItem.separator())

                let quitItem = NSMenuItem(title: LocalizationManager.shared.string("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
                quitItem.target = self
                menu.addItem(quitItem)

                if let button = mainStatusItem?.button {
                    NSMenu.popUpContextMenu(menu, with: event, for: button)
                }
                return
            }

            // Direct Right-Click -> Instant Ambient Mode launch!
            AmbientModeManager.shared.show()
            return
        }
        
        // Left-Click -> Open Ambient Mode
        closeVolumePopoverImmediately()
        AmbientModeManager.shared.show()
    }

    @objc private func openSettingsMenu() {
        if NSApp.windows.contains(where: { $0.title.contains("Songleton") || $0.identifier?.rawValue == "settings" }) {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: SettingsModel.shared)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        window.title = LocalizationManager.shared.string("settings.title")
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openOnboardingGuide() {
        NotificationCenter.default.post(name: Notification.Name("showOnboardingGuide"), object: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func bwdTapped() {
        if isBlockedByGuide { return }
        closeVolumePopoverImmediately()
        NowPlayingModel.shared.previousTrack()
    }

    @objc private func fwdTapped() {
        if isBlockedByGuide { return }
        closeVolumePopoverImmediately()
        NowPlayingModel.shared.nextTrack()
    }

    func showVolumePopover() {
        if isBlockedByGuide { return }
        guard let volPopover = volumePopover, mainStatusItem?.button != nil else { return }
        closeWorkItem?.cancel()

        if volPopover.isShown { return }

        hoverWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let button = self.mainStatusItem?.button else { return }
            guard self.volumePopover?.isShown != true else { return }
            self.volumePopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self.setupGlobalClickMonitor()
        }
        hoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
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
                self.closeVolumePopoverImmediately()
            }
        }
        closeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    func closeVolumePopoverImmediately() {
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()
        removeGlobalClickMonitor()
        if let volPopover = volumePopover, volPopover.isShown {
            volPopover.performClose(nil)
            updateWidth()
        }
    }

    private func setupGlobalClickMonitor() {
        removeGlobalClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closeVolumePopoverImmediately()
            }
        }
    }

    private func removeGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}

// MARK: - MenuBarTrackingAreaView

final class MenuBarTrackingAreaView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    // The overlay only exists for hover tracking; let all clicks pass through
    // to the status bar button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

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
