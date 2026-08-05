import Foundation

final class TutorialPointerMotionTests {
    func runAllTests() {
        runTest(name: "testMinimumJerkUsesNaturalEndpoints", test: testMinimumJerkUsesNaturalEndpoints)
        runTest(name: "testLongerPointerTravelTakesLonger", test: testLongerPointerTravelTakesLonger)
        runTest(name: "testPointerPathBendsAndSettlesOnTarget", test: testPointerPathBendsAndSettlesOnTarget)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testMinimumJerkUsesNaturalEndpoints() {
        assertEqual(TutorialPointerMotion.minimumJerk(0), 0)
        assertEqual(TutorialPointerMotion.minimumJerk(0.5), 0.5)
        assertEqual(TutorialPointerMotion.minimumJerk(1), 1)

        let samples = stride(from: CGFloat(0), through: 1, by: 0.05)
            .map(TutorialPointerMotion.minimumJerk)
        for pair in zip(samples, samples.dropFirst()) {
            assertTrue(pair.0 <= pair.1, "Natural pointer easing must remain monotonic")
        }
    }

    private func testLongerPointerTravelTakesLonger() {
        let short = TutorialPointerMotion.duration(distance: 40, requested: 0.2)
        let long = TutorialPointerMotion.duration(distance: 640, requested: 0.2)

        assertTrue(long > short)
        assertTrue(long <= 0.92)
        assertTrue(short >= 0.2)
    }

    private func testPointerPathBendsAndSettlesOnTarget() {
        let start = CGPoint(x: 100, y: 100)
        let end = CGPoint(x: 700, y: 420)
        let controls = TutorialPointerMotion.controlPoints(from: start, to: end, sequence: 1)
        let beginning = TutorialPointerMotion.point(
            from: start,
            to: end,
            firstControl: controls.first,
            secondControl: controls.second,
            progress: 0
        )
        let middle = TutorialPointerMotion.point(
            from: start,
            to: end,
            firstControl: controls.first,
            secondControl: controls.second,
            progress: 0.5
        )
        let finish = TutorialPointerMotion.point(
            from: start,
            to: end,
            firstControl: controls.first,
            secondControl: controls.second,
            progress: 1
        )
        let straightMidpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)

        assertEqual(beginning, start)
        assertEqual(finish, end)
        assertTrue(hypot(middle.x - straightMidpoint.x, middle.y - straightMidpoint.y) > 1)
    }
}
