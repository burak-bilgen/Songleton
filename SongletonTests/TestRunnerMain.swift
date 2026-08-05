import Foundation

final class TestObserver {
    static let shared = TestObserver()
    var totalCount = 0
    var failedCount = 0
}

@main
struct TestRunnerMain {
    static func main() async {
        print("==================================================")
        print("🧪 Executing Songleton Unit Tests")
        print("==================================================")

        let settingsTests = SettingsModelTests()
        print("▶ Running SettingsModelTests...")
        settingsTests.runAllTests()

        let nowPlayingTests = NowPlayingModelTests()
        print("▶ Running NowPlayingModelTests...")
        await nowPlayingTests.runAllTests()

        let lyricsTests = LyricsServiceTests()
        print("▶ Running LyricsServiceTests...")
        lyricsTests.runAllTests()

        let securityTests = SecurityBoundaryTests()
        print("▶ Running SecurityBoundaryTests...")
        securityTests.runAllTests()

        let mouseGestureTests = MouseGestureManagerTests()
        print("▶ Running MouseGestureManagerTests...")
        mouseGestureTests.runAllTests()

        let notificationLayoutTests = TrackNotificationLayoutTests()
        print("▶ Running TrackNotificationLayoutTests...")
        notificationLayoutTests.runAllTests()

        let tutorialResolutionTests = GestureTutorialResolutionTests()
        print("▶ Running GestureTutorialResolutionTests...")
        tutorialResolutionTests.runAllTests()

        let tutorialPointerMotionTests = TutorialPointerMotionTests()
        print("▶ Running TutorialPointerMotionTests...")
        tutorialPointerMotionTests.runAllTests()

        let localizationTests = LocalizationModelTests()
        print("▶ Running LocalizationModelTests...")
        localizationTests.runAllTests()

        print("==================================================")
        if TestObserver.shared.failedCount == 0 {
            print("✅ ALL \(TestObserver.shared.totalCount) TESTS PASSED SUCCESSFULLY!")
            print("==================================================")
        } else {
            print("❌ \(TestObserver.shared.failedCount) TEST(S) FAILED OUT OF \(TestObserver.shared.totalCount)")
            print("==================================================")
            exit(1)
        }
    }
}
