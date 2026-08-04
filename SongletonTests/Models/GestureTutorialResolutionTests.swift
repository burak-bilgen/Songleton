import Foundation

@MainActor
final class GestureTutorialResolutionTests {
    func runAllTests() {
        runTest(name: "testOnlyCompletionOrExplicitSkipUnlocksControls", test: testOnlyCompletionOrExplicitSkipUnlocksControls)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testOnlyCompletionOrExplicitSkipUnlocksControls() {
        assertFalse(GestureTutorialManager.Resolution.notStarted.unlocksControls)
        assertTrue(GestureTutorialManager.Resolution.completed.unlocksControls)
        assertTrue(GestureTutorialManager.Resolution.skipped.unlocksControls)
        assertFalse(GestureTutorialManager.Resolution.dismissed.unlocksControls)
    }
}
