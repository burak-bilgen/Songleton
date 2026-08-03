import AppKit
import SwiftUI

struct CircularMouseGestureView: NSViewRepresentable {
    let onGesture: (CircularGestureDetector.Direction) -> Void

    func makeNSView(context: Context) -> CircularGestureTrackingView {
        let view = CircularGestureTrackingView()
        view.onGesture = onGesture
        return view
    }

    func updateNSView(_ nsView: CircularGestureTrackingView, context: Context) {
        nsView.onGesture = onGesture
    }
}

struct CircularGestureDetector {
    enum Direction: Equatable {
        case clockwise
        case counterClockwise
    }

    private var points: [CGPoint] = []
    private var lastPoint: CGPoint?
    private var lastVector: CGVector?
    private var accumulatedTurn: CGFloat = 0
    private var totalDistance: CGFloat = 0
    private var turnDirection: CGFloat?
    private var directionChanges = 0
    private var cooldownUntil = Date.distantPast

    mutating func update(point: CGPoint, now: Date = Date()) -> Direction? {
        guard now >= cooldownUntil else { return nil }
        points.append(point)
        if points.count > 48 { points.removeFirst() }
        guard points.count >= 4 else { return nil }

        if let lastPoint {
            let vector = CGVector(dx: point.x - lastPoint.x, dy: point.y - lastPoint.y)
            let distance = hypot(vector.dx, vector.dy)
            totalDistance += distance
            if let lastVector, distance > 0 {
                let cross = lastVector.dx * vector.dy - lastVector.dy * vector.dx
                let dot = lastVector.dx * vector.dx + lastVector.dy * vector.dy
                let turn = atan2(cross, dot)
                if abs(turn) <= 1.2, abs(turn) > 0.04 {
                    if let turnDirection, turn.sign != turnDirection.sign {
                        directionChanges += 1
                    }
                    turnDirection = turn
                    accumulatedTurn += turn
                }
            }
            self.lastVector = vector
        }
        self.lastPoint = point

        guard points.count >= 12,
              totalDistance >= 100,
              boundingBoxSize(for: points) >= 30,
              directionChanges <= 12,
              abs(accumulatedTurn) >= 1.3 * .pi else {
            return nil
        }

        let direction: Direction = accumulatedTurn > 0 ? .clockwise : .counterClockwise
        reset(keepingCooldown: true, now: now)
        return direction
    }

    private mutating func reset(keepingCooldown: Bool, now: Date = Date()) {
        points.removeAll(keepingCapacity: true)
        lastPoint = nil
        lastVector = nil
        accumulatedTurn = 0
        totalDistance = 0
        turnDirection = nil
        directionChanges = 0
        if keepingCooldown { cooldownUntil = now.addingTimeInterval(0.9) }
    }

    private func boundingBoxSize(for points: [CGPoint]) -> CGFloat {
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        return min(maxX - minX, maxY - minY)
    }
}

final class CircularGestureTrackingView: NSView {
    var onGesture: ((CircularGestureDetector.Direction) -> Void)?
    private var detector = CircularGestureDetector()

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        if let direction = detector.update(point: convert(event.locationInWindow, from: nil)) {
            onGesture?(direction)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
