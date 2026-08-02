import Foundation

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) {
    if a != b {
        print("  ❌ Assertion Failed: '\(a)' is not equal to '\(b)'. \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
        TestObserver.shared.failedCount += 1
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if !condition {
        print("  ❌ Assertion Failed: Expected true, got false. \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
        TestObserver.shared.failedCount += 1
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if condition {
        print("  ❌ Assertion Failed: Expected false, got true. \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
        TestObserver.shared.failedCount += 1
    }
}

func assertAccuracy(_ a: Double, _ b: Double, accuracy: Double, _ message: String = "", file: String = #file, line: Int = #line) {
    if abs(a - b) > accuracy {
        print("  ❌ Assertion Failed: \(a) is not within \(accuracy) of \(b). \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
        TestObserver.shared.failedCount += 1
    }
}
