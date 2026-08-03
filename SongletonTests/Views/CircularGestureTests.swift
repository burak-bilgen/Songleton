import Foundation
import CoreGraphics

struct CircularGestureTests {
    func runAllTests() {
        runTest(name: "testClockwiseCircle", test: testClockwiseCircle)
        runTest(name: "testCounterClockwiseCircle", test: testCounterClockwiseCircle)
        runTest(name: "testStraightMovementDoesNotTrigger", test: testStraightMovementDoesNotTrigger)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testClockwiseCircle() {
        var detector = CircularGestureDetector()
        let result = feedCircle(to: &detector, direction: 1)
        assertEqual(result, .clockwise)
    }

    private func testCounterClockwiseCircle() {
        var detector = CircularGestureDetector()
        let result = feedCircle(to: &detector, direction: -1)
        assertEqual(result, .counterClockwise)
    }

    private func testStraightMovementDoesNotTrigger() {
        var detector = CircularGestureDetector()
        var result: CircularGestureDetector.Direction?
        for index in 0..<40 {
            result = detector.update(point: CGPoint(x: CGFloat(index) * 4, y: 40), now: Date(timeIntervalSince1970: 1))
        }
        assertEqual(result, nil)
    }

    private func feedCircle(to detector: inout CircularGestureDetector, direction: CGFloat) -> CircularGestureDetector.Direction? {
        var result: CircularGestureDetector.Direction?
        for index in 0..<32 {
            let angle = direction * CGFloat(index) * 2 * .pi / 32
            result = detector.update(
                point: CGPoint(x: 100 + cos(angle) * 40, y: 100 + sin(angle) * 40),
                now: Date(timeIntervalSince1970: 1 + Double(index) * 0.01)
            ) ?? result
        }
        return result
    }
}
