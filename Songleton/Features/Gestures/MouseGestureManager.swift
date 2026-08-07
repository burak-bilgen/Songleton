import AppKit
@preconcurrency import ApplicationServices
import Combine
@preconcurrency import CoreFoundation
import CoreGraphics
import OSLog
import SwiftUI

nonisolated fileprivate final class MouseMoveThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private let minimumInterval: TimeInterval
    private var lastForwardedAt: TimeInterval = 0

    init(maximumUpdatesPerSecond: Double) {
        minimumInterval = 1 / max(1, maximumUpdatesPerSecond)
    }

    func shouldForward(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard now - lastForwardedAt >= minimumInterval else { return false }
        lastForwardedAt = now
        return true
    }
}

private func mouseEventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<MouseGestureManager>.fromOpaque(userInfo).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in
            if let tap = manager.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        }
    } else if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged {
        guard manager.mouseMoveThrottle.shouldForward() else {
            return Unmanaged.passUnretained(event)
        }
        let location = event.location
        let flags = event.flags
        Task { @MainActor in
            manager.handleGlobalMouseLocation(location, flags: flags, now: Date())
        }
    } else if type == .leftMouseDown || type == .leftMouseUp || type == .rightMouseDown || type == .rightMouseUp {
        let location = event.location
        let flags = event.flags
        Task { @MainActor in
            manager.handleGlobalMouseEvent(type, flags: flags, location: location)
        }
    } else if type == .flagsChanged {
        let flags = event.flags
        Task { @MainActor in
            manager.handleFlagsChanged(flags)
        }
    }
    return Unmanaged.passUnretained(event)
}

@MainActor
final class MouseGestureManager: ObservableObject {
    enum EdgeZone: Equatable {
        case previous
        case playPause
        case next
    }

    static let shared = AppContainer.shared.mouseGestures

    fileprivate var eventTap: CFMachPort?
    nonisolated fileprivate let mouseMoveThrottle = MouseMoveThrottle(maximumUpdatesPerSecond: 60)
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var activeZone: EdgeZone?
    private var pendingWorkItem: DispatchWorkItem?
    private var zoneExitWorkItem: DispatchWorkItem?
    private static let zoneExitGrace: TimeInterval = 0.30
    private var edgeProgressTask: Task<Void, Never>?
    private var cursorGestureWindow: NSPanel?
    private var edgeGestureStartedAt = Date.distantPast
    private var edgeGestureDuration = 0.5
    private var lastTriggeredAt = Date.distantPast
    @Published private(set) var isAccessibilityTrusted = false
    @Published private(set) var isVolumeGestureActive = false
    @Published private(set) var gestureVolume = 50
    @Published private(set) var edgeGestureProgress = 0.0
    @Published private(set) var edgeGestureBurst = 0
    @Published private(set) var edgeGestureCancelBurst = 0
    private var pressedButtons = Set<Int64>()
    private var volumeGestureStartY: CGFloat = 0
    private var volumeGestureStartValue = 50
    private var volumeGestureWindow: NSPanel?
    private let logger = Logger(subsystem: "bilgenworks.app.Songleton", category: "mouse-gesture")
    private var lastEventLogDate = Date.distantPast

    init() {
        refreshAccessibilityStatus()
    }

    func simulateEdgeGestureProgress(_ progress: CGFloat) {
        edgeGestureProgress = progress
    }

    func simulateEdgeGestureBurst() {
        edgeGestureBurst += 1
    }

    func simulateEdgeGestureCancelBurst() {
        edgeGestureCancelBurst += 1
    }

    func simulateGestureVolume(_ volume: Int) {
        gestureVolume = volume
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    func updateMonitoring() {
        refreshAccessibilityStatus()
        guard isMusicPlayerAvailable else {
            logger.info("Gesture monitoring suppressed because no supported music player is running")
            stop()
            return
        }
        let isOnboardingOpen = NSApp.windows.contains(where: { $0.identifier?.rawValue == "onboardingWindow" && $0.isVisible })
        let isSetupRecoveryOpen = NSApp.windows.contains(where: { $0.identifier?.rawValue == "setupRecoveryWindow" && $0.isVisible })
        if isOnboardingOpen || isSetupRecoveryOpen || GestureTutorialManager.shared.isPresented {
            logger.info("Gesture monitoring suppressed while onboarding, setup recovery, or the gesture tutorial is open")
            stop()
            return
        }

        let shouldMonitor = SettingsModel.shared.horizontalGesturesEnabled
            || SettingsModel.shared.verticalGesturesEnabled

        if shouldMonitor {
            start()
        } else {
            stop()
        }
    }

    private var isMusicPlayerAvailable: Bool {
        if case .loaded = NowPlayingModel.shared.state {
            return true
        }
        return false
    }

    func start() {
        guard eventTap == nil else { return }
        guard requestAccessibilityAccess(promptForPermission: false) else {
            logger.warning("Accessibility permission is not granted; global mouse monitor was not started")
            return
        }

        let eventTypes: [CGEventType] = [
            .mouseMoved, .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp, .leftMouseDragged,
            .rightMouseDragged, .flagsChanged
        ]
        var mouseMovedMask: CGEventMask = 0
        for type in eventTypes {
            mouseMovedMask |= (1 << type.rawValue)
        }
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mouseMovedMask,
            callback: { proxy, type, event, userInfo in
                mouseEventTapCallback(proxy, type, event, userInfo)
            },
            userInfo: userInfo
        ) else {
            logger.error("Could not create global mouse event tap")
            return
        }
        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = eventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("Global mouse event tap started")
    }

    @discardableResult
    func requestAccessibilityAccess(promptForPermission: Bool = true) -> Bool {
        refreshAccessibilityStatus()
        guard !isAccessibilityTrusted else {
            logger.debug("Accessibility permission is granted")
            return true
        }
        guard promptForPermission else { return false }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        logger.notice("Requesting Accessibility permission")
        let result = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        refreshAccessibilityStatus()
        return result
    }

    func stop() {
        if let source = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTapRunLoopSource = nil
        if let eventTap { CFMachPortInvalidate(eventTap) }
        eventTap = nil
        activeZone = nil
        edgeProgressTask?.cancel()
        edgeProgressTask = nil
        hideCursorGestureOverlay()
        edgeGestureProgress = 0
        pressedButtons.removeAll()
        endVolumeGesture()
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        zoneExitWorkItem?.cancel()
        zoneExitWorkItem = nil
        lastTriggeredAt = .distantPast
        logger.info("Global mouse monitor stopped")
    }

    fileprivate func handleFlagsChanged(_ flags: CGEventFlags) {
        let isCmdOptionPressed = flags.contains(.maskCommand) && flags.contains(.maskAlternate)
        let isBothPressed = pressedButtons.contains(0) && pressedButtons.contains(1)

        if !isCmdOptionPressed && !isBothPressed && isVolumeGestureActive {
            endVolumeGesture()
        }
    }

    fileprivate func handleGlobalMouseLocation(_ location: CGPoint, flags: CGEventFlags, now: Date) {
        let appKitLocation = NSEvent.mouseLocation
        let isBothPressed = pressedButtons.contains(0) && pressedButtons.contains(1)
        let isCmdOptionPressed = flags.contains(.maskCommand) && flags.contains(.maskAlternate)

        if isBothPressed || isCmdOptionPressed {
            if !isVolumeGestureActive { startVolumeGesture(at: location.y, screenLocation: appKitLocation) }
            updateVolumeGesture(at: location.y)
            return
        } else if isVolumeGestureActive {
            endVolumeGesture()
        }
        handleMouseLocation(appKitLocation, now: now)
    }

    fileprivate func handleGlobalMouseEvent(_ type: CGEventType, flags: CGEventFlags, location: CGPoint) {
        let appKitLocation = NSEvent.mouseLocation
        let button: Int64?
        switch type {
        case .leftMouseDown, .leftMouseUp: button = 0
        case .rightMouseDown, .rightMouseUp: button = 1
        default: button = nil
        }

        if let button {
            if type == .leftMouseDown || type == .rightMouseDown {
                pressedButtons.insert(button)
            } else {
                pressedButtons.remove(button)
            }
        }

        let isBothPressed = pressedButtons.contains(0) && pressedButtons.contains(1)
        let isCmdOptionPressed = flags.contains(.maskCommand) && flags.contains(.maskAlternate)

        if isBothPressed || isCmdOptionPressed {
            if !isVolumeGestureActive { startVolumeGesture(at: location.y, screenLocation: appKitLocation) }
            updateVolumeGesture(at: location.y)
        } else if isVolumeGestureActive {
            endVolumeGesture()
        }
    }

    private func handleMouseLocation(_ location: NSPoint, now: Date) {
        let zone = edgeZone(at: location)

        // Grace period: a cursor that briefly dips out of the active edge zone
        // (hand jitter, thin top strip) must not instantly cancel a nearly
        // complete gesture. Only cancel once it stays out for the grace time.
        if zone == nil, activeZone != nil {
            guard zoneExitWorkItem == nil else { return }
            let exitItem = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.cancelEdgeGesture()
                }
            }
            zoneExitWorkItem = exitItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.zoneExitGrace, execute: exitItem)
            return
        }
        zoneExitWorkItem?.cancel()
        zoneExitWorkItem = nil

        guard zone != activeZone else { return }

        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        edgeProgressTask?.cancel()
        edgeProgressTask = nil

        if cursorGestureWindow != nil {
            edgeGestureCancelBurst += 1
            cancelCursorGestureOverlay()
        } else {
            edgeGestureProgress = 0
            hideCursorGestureOverlay()
        }
        activeZone = zone
        guard let zone else { return }

        scheduleZoneGesture(zone, now: now)
    }

    /// Cancels any in-flight edge gesture and clears the active zone. Used when
    /// the cursor leaves the zone past the grace period (or monitoring stops).
    private func cancelEdgeGesture() {
        zoneExitWorkItem?.cancel()
        zoneExitWorkItem = nil
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        edgeProgressTask?.cancel()
        edgeProgressTask = nil
        if cursorGestureWindow != nil {
            edgeGestureCancelBurst += 1
            cancelCursorGestureOverlay()
        } else {
            edgeGestureProgress = 0
            hideCursorGestureOverlay()
        }
        activeZone = nil
    }

    private func scheduleZoneGesture(_ zone: EdgeZone, now: Date) {
        // If a gesture was triggered recently, wait out the remaining cooldown
        // before recognizing the new zone, so the gesture is never silently lost.
        let cooldownDelay = max(0, 1.0 - now.timeIntervalSince(lastTriggeredAt))
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.activeZone == zone else { return }
            let duration = zone == .playPause
                ? SettingsModel.shared.topEdgeHoldDuration
                : SettingsModel.shared.horizontalEdgeHoldDuration
            self.edgeGestureDuration = duration
            self.edgeGestureStartedAt = Date()
            self.edgeGestureProgress = 0
            self.showCursorGestureOverlay(for: zone)

            self.edgeProgressTask = Task { @MainActor [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    let progress = min(1, Date().timeIntervalSince(self.edgeGestureStartedAt) / self.edgeGestureDuration)
                    self.edgeGestureProgress = progress
                    self.updateCursorGestureOverlayPosition()
                    if progress >= 1 { return }
                    do {
                        try await Task.sleep(for: .milliseconds(16))
                    } catch {
                        return
                    }
                }
            }

            let trigger = DispatchWorkItem { [weak self] in
                guard let self, self.activeZone == zone else { return }
                self.lastTriggeredAt = Date()
                self.pendingWorkItem = nil
                self.edgeProgressTask?.cancel()
                self.edgeProgressTask = nil
                self.edgeGestureProgress = 1
                self.edgeGestureBurst += 1
                self.burstCursorGestureOverlay()
                self.logger.info("Screen edge gesture recognized: \(String(describing: zone), privacy: .public)")
                switch zone {
                case .previous:
                    NowPlayingModel.shared.previousTrack()
                    GestureOutcomeFeedback.shared.show(.previous)
                case .playPause:
                    let willPause = playbackIsPlaying
                    NowPlayingModel.shared.togglePlayPause()
                    GestureOutcomeFeedback.shared.show(willPause ? .pause : .resume)
                case .next:
                    NowPlayingModel.shared.nextTrack()
                    GestureOutcomeFeedback.shared.show(.next)
                }
            }
            self.pendingWorkItem = trigger
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: trigger)
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownDelay, execute: workItem)
    }

    private var playbackIsPlaying: Bool {
        if case .loaded(let info, _) = NowPlayingModel.shared.state {
            return info.isPlaying
        }
        return false
    }

    private func showCursorGestureOverlay(for zone: EdgeZone) {
        guard cursorGestureWindow == nil else { return }

        let hostingController = NSHostingController(rootView: CursorGestureOverlayView(manager: self, zone: zone))
        let size = NSSize(width: 112, height: 112)
        let panel = NSPanel(
            contentRect: NSRect(origin: cursorOverlayOrigin(for: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hostingController
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        cursorGestureWindow = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func updateCursorGestureOverlayPosition() {
        guard let panel = cursorGestureWindow else { return }
        panel.setFrameOrigin(cursorOverlayOrigin(for: panel.frame.size))
    }

    private func cursorOverlayOrigin(for size: NSSize) -> NSPoint {
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main
        let bounds = screen?.frame ?? .zero
        let x = min(max(cursor.x + 8, bounds.minX + 6), bounds.maxX - size.width - 6)
        let y = min(max(cursor.y - size.height - 8, bounds.minY + 6), bounds.maxY - size.height - 6)
        return NSPoint(x: x, y: y)
    }

    private func hideCursorGestureOverlay() {
        guard let panel = cursorGestureWindow else { return }
        cursorGestureWindow = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
            }
        }
    }

    private func cancelCursorGestureOverlay() {
        guard let panel = cursorGestureWindow else { return }
        cursorGestureWindow = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
            }
        }
    }

    private func burstCursorGestureOverlay() {
        guard let panel = cursorGestureWindow else { return }
        cursorGestureWindow = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
            }
        }
    }

    private func edgeZone(at location: NSPoint) -> EdgeZone? {
        // A cursor pushed against the physical top/right edge reports exactly
        // frame.maxY/frame.maxX, and NSRect.contains excludes max edges — which
        // silently killed the top (play/pause) and right (next) zones. Prefer
        // the exact frame first so displays sharing an edge (stacked or
        // side-by-side) keep their ownership, then fall back to a hair-expanded
        // frame to catch a cursor pinned to a max edge.
        let tolerance: CGFloat = 1
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) })
            ?? NSScreen.screens.first(where: { $0.frame.insetBy(dx: -tolerance, dy: -tolerance).contains(location) })
        else { return nil }
        return Self.edgeZone(
            at: location,
            in: screen.frame,
            horizontalEnabled: SettingsModel.shared.horizontalGesturesEnabled,
            verticalEnabled: SettingsModel.shared.verticalGesturesEnabled
        )
    }

    /// Edge detection uses AppKit coordinates, where each screen's visual top
    /// is `maxY`. Keeping this pure protects vertically arranged displays too.
    static func edgeZone(
        at location: NSPoint,
        in frame: NSRect,
        horizontalEnabled: Bool,
        verticalEnabled: Bool,
        edgeInset: CGFloat = 4,
        topInset: CGFloat = 8
    ) -> EdgeZone? {
        if horizontalEnabled {
            if location.x <= frame.minX + edgeInset { return .previous }
            if location.x >= frame.maxX - edgeInset { return .next }
        }
        if verticalEnabled, location.y >= frame.maxY - topInset {
            return .playPause
        }
        return nil
    }

    private func startVolumeGesture(at y: CGFloat, screenLocation: CGPoint) {
        guard SettingsModel.shared.verticalGesturesEnabled else { return }
        guard case .loaded(let info, _) = NowPlayingModel.shared.state else { return }
        isVolumeGestureActive = true
        volumeGestureStartY = y
        volumeGestureStartValue = info.volume
        gestureVolume = info.volume
        showVolumeGestureHUD(at: screenLocation)
        logger.info("Volume gesture started")
    }

    private func updateVolumeGesture(at y: CGFloat) {
        guard isVolumeGestureActive else { return }
        let delta = Int((volumeGestureStartY - y) / 5.0)
        let newVolume = min(100, max(0, volumeGestureStartValue + delta))
        guard newVolume != gestureVolume else { return }
        gestureVolume = newVolume
        NowPlayingModel.shared.setVolume(newVolume)
    }

    private func endVolumeGesture() {
        guard isVolumeGestureActive else { return }
        isVolumeGestureActive = false
        guard let panel = volumeGestureWindow else { return }
        let view = panel.contentView

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0
            view?.layer?.setAffineTransform(CGAffineTransform(translationX: 0, y: 18))
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor [weak self, weak panel] in
                panel?.orderOut(nil)
                guard let self, self.volumeGestureWindow === panel else { return }
                self.volumeGestureWindow = nil
            }
        }
        logger.info("Volume gesture ended at \(self.gestureVolume, privacy: .public)%")
    }

    private func showVolumeGestureHUD(at location: CGPoint) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) ?? NSScreen.main
        guard let screen else { return }

        let hostingController = NSHostingController(rootView: VolumeGestureHUDView(manager: self))
        hostingController.sizingOptions = [.intrinsicContentSize]
        let fittingSize = hostingController.view.fittingSize
        let hudSize = NSSize(width: max(fittingSize.width, 40), height: max(fittingSize.height, 160))

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hudSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hostingController

        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.maxX - hudSize.width - 6
        let y = visibleFrame.maxY - hudSize.height - 4

        panel.setFrame(NSRect(x: x, y: y, width: hudSize.width, height: hudSize.height), display: true)
        volumeGestureWindow = panel
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // Top-to-bottom slide entrance (+18 -> 0) with gentle spring bounce
        let view = panel.contentView!
        view.wantsLayer = true
        view.layer?.setAffineTransform(CGAffineTransform(translationX: 0, y: 18))

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.25)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1
            view.layer?.setAffineTransform(.identity)
        }
    }

    isolated deinit {
        if let eventTap { CFMachPortInvalidate(eventTap) }
    }
}
