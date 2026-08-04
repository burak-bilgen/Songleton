import AppKit

final class TrackNotificationLayoutTests {
    func runAllTests() {
        runTest(name: "testNotificationUsesMinimumWidthForShortMetadata", test: testNotificationUsesMinimumWidthForShortMetadata)
        runTest(name: "testNotificationExpandsForLongTrackName", test: testNotificationExpandsForLongTrackName)
        runTest(name: "testNotificationWrapsWithinScreenWidth", test: testNotificationWrapsWithinScreenWidth)
        runTest(name: "testNotificationMotionStartsOutsideSelectedEdges", test: testNotificationMotionStartsOutsideSelectedEdges)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testNotificationUsesMinimumWidthForShortMetadata() {
        let layout = TrackNotificationLayout.make(
            track: "Song",
            artist: "Artist",
            in: NSRect(x: 0, y: 0, width: 1440, height: 900)
        )
        assertEqual(layout.size.width, TrackNotificationLayout.minimumWidth)
        assertEqual(layout.size.height, TrackNotificationLayout.minimumHeight)
        assertEqual(
            layout.panelSize.width,
            TrackNotificationLayout.minimumWidth + TrackNotificationLayout.shadowInset * 2
        )
    }

    private func testNotificationExpandsForLongTrackName() {
        let layout = TrackNotificationLayout.make(
            track: "A deliberately long song title that deserves to be readable without an arbitrary truncation",
            artist: "Artist",
            in: NSRect(x: 0, y: 0, width: 1440, height: 900)
        )
        assertTrue(layout.size.width > TrackNotificationLayout.minimumWidth)
        assertTrue(layout.size.width <= TrackNotificationLayout.maximumPreferredWidth)
    }

    private func testNotificationWrapsWithinScreenWidth() {
        let layout = TrackNotificationLayout.make(
            track: String(repeating: "Very long title ", count: 18),
            artist: "Artist",
            in: NSRect(x: 0, y: 0, width: 420, height: 900)
        )
        assertTrue(layout.size.width <= 380)
        assertTrue(layout.size.height > TrackNotificationLayout.minimumHeight)
    }

    private func testNotificationMotionStartsOutsideSelectedEdges() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelSize = NSSize(width: 338, height: 132)
        let finalOrigin = NSPoint(x: 1_000, y: 34)

        let bottomTrailing = TrackNotificationMotion.offscreenOrigin(
            finalOrigin: finalOrigin,
            panelSize: panelSize,
            in: screen,
            position: .bottomTrailing
        )
        assertEqual(bottomTrailing.x, finalOrigin.x)
        assertTrue(bottomTrailing.y + panelSize.height <= screen.minY)

        let topLeading = TrackNotificationMotion.offscreenOrigin(
            finalOrigin: finalOrigin,
            panelSize: panelSize,
            in: screen,
            position: .topLeading
        )
        assertEqual(topLeading.x, finalOrigin.x)
        assertTrue(topLeading.y >= screen.maxY)
    }
}
