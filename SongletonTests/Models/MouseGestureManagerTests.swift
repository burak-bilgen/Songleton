import AppKit

@MainActor
final class MouseGestureManagerTests {
    func runAllTests() {
        runTest(name: "testEdgeZonesUseScreenTopForPlayPause", test: testEdgeZonesUseScreenTopForPlayPause)
        runTest(name: "testEdgeZonesRespectEnabledGestureGroups", test: testEdgeZonesRespectEnabledGestureGroups)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testEdgeZonesUseScreenTopForPlayPause() {
        let frame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        assertEqual(
            MouseGestureManager.edgeZone(
                at: NSPoint(x: 720, y: 1),
                in: frame,
                horizontalEnabled: true,
                verticalEnabled: true
            ),
            .playPause
        )
        assertEqual(
            MouseGestureManager.edgeZone(
                at: NSPoint(x: 720, y: 899),
                in: frame,
                horizontalEnabled: true,
                verticalEnabled: true
            ),
            nil
        )
    }

    private func testEdgeZonesRespectEnabledGestureGroups() {
        let frame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        assertEqual(
            MouseGestureManager.edgeZone(
                at: NSPoint(x: 1, y: 450),
                in: frame,
                horizontalEnabled: true,
                verticalEnabled: false
            ),
            .previous
        )
        assertEqual(
            MouseGestureManager.edgeZone(
                at: NSPoint(x: 1439, y: 450),
                in: frame,
                horizontalEnabled: true,
                verticalEnabled: false
            ),
            .next
        )
        assertEqual(
            MouseGestureManager.edgeZone(
                at: NSPoint(x: 720, y: 899),
                in: frame,
                horizontalEnabled: true,
                verticalEnabled: false
            ),
            nil
        )
    }
}
