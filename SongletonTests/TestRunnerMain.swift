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

        let nowPlayingTests = await NowPlayingModelTests()
        print("▶ Running NowPlayingModelTests...")
        await nowPlayingTests.runAllTests()

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
