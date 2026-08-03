import AppKit
import ApplicationServices
import OSLog

@MainActor
final class MouseGestureManager {
    static let shared = MouseGestureManager()

    private var monitor: Any?
    private var detector = CircularGestureDetector()
    private let logger = Logger(subsystem: "bilgenworks.app.Songleton", category: "mouse-gesture")

    private init() {}

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func start() {
        guard monitor == nil else {
            logger.debug("Global mouse monitor is already running")
            return
        }
        guard requestAccessibilityAccess() else {
            logger.warning("Accessibility permission is not granted; global mouse monitor was not started")
            return
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard SettingsModel.shared.circularGesturesEnabled else { return }
            let point = event.locationInWindow
            DispatchQueue.main.async {
                guard let self else { return }
                if let direction = self.detector.update(point: point) {
                    self.logger.info("Circular gesture recognized: \(String(describing: direction), privacy: .public)")
                    switch direction {
                    case .clockwise:
                        NowPlayingModel.shared.nextTrack()
                    case .counterClockwise:
                        NowPlayingModel.shared.previousTrack()
                    }
                }
            }
        }
        logger.info("Global mouse monitor started")
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
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        detector = CircularGestureDetector()
        logger.info("Global mouse monitor stopped")
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
