import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import OSLog
import SwiftUI

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
        let location = event.location
        Task { @MainActor in
            manager.handleFlagsChanged(flags, location: location)
        }
    }
    return Unmanaged.passUnretained(event)
}

@MainActor
final class MouseGestureManager: ObservableObject {
    private enum EdgeZone: Equatable {
        case previous
        case playPause
        case next
    }

    static let shared = MouseGestureManager()

    fileprivate var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var activeZone: EdgeZone?
    private var pendingWorkItem: DispatchWorkItem?
    private var lastTriggeredAt = Date.distantPast
    @Published private(set) var isVolumeGestureActive = false
    @Published private(set) var gestureVolume = 50
    private var pressedButtons = Set<Int64>()
    private var volumeGestureStartY: CGFloat = 0
    private var volumeGestureStartValue = 50
    private var volumeGestureWindow: NSPanel?
    private let logger = Logger(subsystem: "bilgenworks.app.Songleton", category: "mouse-gesture")
    private var lastEventLogDate = Date.distantPast

    private init() {}

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func start() {
        guard eventTap == nil else {
            logger.debug("Global mouse monitor is already running")
            return
        }
        guard requestAccessibilityAccess() else {
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
    func requestAccessibilityAccess() -> Bool {
        guard !AXIsProcessTrusted() else {
            logger.debug("Accessibility permission is granted")
            return true
        }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        logger.notice("Requesting Accessibility permission")
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func stop() {
        if let source = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTapRunLoopSource = nil
        if let eventTap { CFMachPortInvalidate(eventTap) }
        eventTap = nil
        activeZone = nil
        pressedButtons.removeAll()
        endVolumeGesture()
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        lastTriggeredAt = .distantPast
        logger.info("Global mouse monitor stopped")
    }

    fileprivate func handleFlagsChanged(_ flags: CGEventFlags, location: CGPoint) {
        let isCmdPressed = flags.contains(.maskCommand)
        let isBothPressed = pressedButtons.contains(0) && pressedButtons.contains(1)

        if !isCmdPressed && !isBothPressed && isVolumeGestureActive {
            endVolumeGesture()
        }
    }

    fileprivate func handleGlobalMouseLocation(_ location: CGPoint, flags: CGEventFlags, now: Date) {
        guard SettingsModel.shared.circularGesturesEnabled else { return }
        if now.timeIntervalSince(lastEventLogDate) >= 1.0 {
            lastEventLogDate = now
            logger.debug("Global mouse move event received")
        }
        let isBothPressed = pressedButtons.contains(0) && pressedButtons.contains(1)
        let isCmdPressed = flags.contains(.maskCommand)

        if isBothPressed || isCmdPressed {
            if !isVolumeGestureActive { startVolumeGesture(at: location.y, screenLocation: location) }
            updateVolumeGesture(at: location.y)
            return
        } else if isVolumeGestureActive {
            endVolumeGesture()
        }
        handleMouseLocation(NSPoint(x: location.x, y: location.y), now: now)
    }

    fileprivate func handleGlobalMouseEvent(_ type: CGEventType, flags: CGEventFlags, location: CGPoint) {
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
        let isCmdPressed = flags.contains(.maskCommand)

        if isBothPressed || isCmdPressed {
            if !isVolumeGestureActive { startVolumeGesture(at: location.y, screenLocation: location) }
            updateVolumeGesture(at: location.y)
        } else if isVolumeGestureActive {
            endVolumeGesture()
        }
    }

    private func handleMouseLocation(_ location: NSPoint, now: Date) {
        let zone = edgeZone(at: location)
        guard zone != activeZone else { return }

        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        activeZone = zone
        guard let zone else { return }
        guard now.timeIntervalSince(lastTriggeredAt) >= 1.0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.activeZone == zone else { return }
            self.lastTriggeredAt = Date()
            self.pendingWorkItem = nil
            self.logger.info("Screen edge gesture recognized: \(String(describing: zone), privacy: .public)")
            switch zone {
            case .previous: NowPlayingModel.shared.previousTrack()
            case .playPause: NowPlayingModel.shared.togglePlayPause()
            case .next: NowPlayingModel.shared.nextTrack()
            }
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func edgeZone(at location: NSPoint) -> EdgeZone? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else { return nil }
        let frame = screen.frame
        if location.x <= frame.minX + 4 { return .previous }
        if location.x >= frame.maxX - 4 { return .next }
        if location.y <= frame.minY + 4 { return .playPause }
        return nil
    }

    private func startVolumeGesture(at y: CGFloat, screenLocation: CGPoint) {
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
        let delta = Int((volumeGestureStartY - y) / 6.0)
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
            panel?.orderOut(nil)
            self?.volumeGestureWindow = nil
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

    deinit {
        if let eventTap { CFMachPortInvalidate(eventTap) }
    }
}
