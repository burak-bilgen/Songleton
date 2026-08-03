import Foundation

final class LyricsServiceTests {
    func runAllTests() {
        runTest(name: "testLRCParsingAndSorting", test: testLRCParsingAndSorting)
        runTest(name: "testLRCSupportsMultipleTimestamps", test: testLRCSupportsMultipleTimestamps)
        runTest(name: "testLRCFiltersMetadataAndMalformedLines", test: testLRCFiltersMetadataAndMalformedLines)
        runTest(name: "testPlainLyricsParsing", test: testPlainLyricsParsing)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testLRCParsingAndSorting() {
        let lines = LyricsService.parseLRC("[00:10.5]Late\n[00:02.25]Early")
        assertEqual(lines.map(\.text), ["Early", "Late"])
        assertAccuracy(lines[0].timestamp, 2.25, accuracy: 0.001)
        assertAccuracy(lines[1].timestamp, 10.5, accuracy: 0.001)
    }

    private func testLRCSupportsMultipleTimestamps() {
        let lines = LyricsService.parseLRC("[00:01.2][00:03:45]Shared line")
        assertEqual(lines.count, 2)
        assertAccuracy(lines[0].timestamp, 1.2, accuracy: 0.001)
        assertAccuracy(lines[1].timestamp, 3.45, accuracy: 0.001)
        assertEqual(lines[0].text, "Shared line")
    }

    private func testLRCFiltersMetadataAndMalformedLines() {
        let lrc = "[ar:Artist]\n[ti:Title]\nnot a lyric\n[01:99]Invalid seconds?\n[01:05]Valid"
        let lines = LyricsService.parseLRC(lrc)
        assertEqual(lines.count, 1)
        assertEqual(lines[0].text, "Valid")
    }

    private func testPlainLyricsParsing() {
        let lines = LyricsService.parsePlainLyrics(" First line \n\nSecond line\n  \nThird")
        assertEqual(lines.map(\.text), ["First line", "Second line", "Third"])
        assertEqual(lines.map(\.timestamp), [0, 4, 8])
        assertTrue(LyricsService.parsePlainLyrics(" \n\n").isEmpty)
    }
}
