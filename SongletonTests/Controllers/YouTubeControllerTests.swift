import Foundation

final class YouTubeControllerTests {
    func runAllTests() {
        runTest(name: "testAppleScriptEscaping", test: testAppleScriptEscaping)
        runTest(name: "testJavaScriptAutomationErrorClassification", test: testJavaScriptAutomationErrorClassification)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testAppleScriptEscaping() {
        let value = "line1\\\"line2\nline3\r"
        let escaped = YouTubeController().escapeForAppleScript(value)
        assertEqual(escaped, "line1\\\\\\\"line2 line3 ")
    }

    private func testJavaScriptAutomationErrorClassification() {
        let controller = YouTubeController()
        assertTrue(controller.isJavaScriptAutomationError("JavaScript execution requires Apple Events"))
        assertTrue(controller.isJavaScriptAutomationError("JavaScript is turned off"))
        assertFalse(controller.isJavaScriptAutomationError("tab not found"))
        assertFalse(controller.isJavaScriptAutomationError("JavaScript syntax error"))
    }
}
