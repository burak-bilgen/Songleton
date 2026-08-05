import Foundation

final class SecurityBoundaryTests {
    func runAllTests() {
        runTest(name: "testLyricsURLAllowlist", test: testLyricsURLAllowlist)
        runTest(name: "testArtworkURLAllowlist", test: testArtworkURLAllowlist)
        runTest(name: "testResponseValidation", test: testResponseValidation)
        runTest(name: "testMetadataSanitization", test: testMetadataSanitization)
        runTest(name: "testInvalidImageRejected", test: testInvalidImageRejected)
        runTest(name: "testLyricsParsingIsBounded", test: testLyricsParsingIsBounded)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        test()
    }

    private func testLyricsURLAllowlist() {
        assertTrue(isAllowed("https://lrclib.net/api/get", kind: .lyrics))
        assertTrue(isAllowed("https://lrclib.net:443/api/search?q=test", kind: .lyrics))
        assertFalse(isAllowed("http://lrclib.net/api/get", kind: .lyrics))
        assertFalse(isAllowed("https://lrclib.net.evil.example/api/get", kind: .lyrics))
        assertFalse(isAllowed("https://user:pass@lrclib.net/api/get", kind: .lyrics))
        assertFalse(isAllowed("https://lrclib.net:444/api/get", kind: .lyrics))
        assertFalse(isAllowed("file:///etc/passwd", kind: .lyrics))
    }

    private func testArtworkURLAllowlist() {
        assertTrue(isAllowed("https://i.scdn.co/image/abc", kind: .artwork))
        assertTrue(isAllowed("https://image-cdn-ak.spotifycdn.com/image/abc", kind: .artwork))
        assertFalse(isAllowed("http://i.scdn.co/image/abc", kind: .artwork))
        assertFalse(isAllowed("https://scdn.co.evil.example/image/abc", kind: .artwork))
        assertFalse(isAllowed("https://127.0.0.1/image/abc", kind: .artwork))
        assertFalse(isAllowed("data:image/png;base64,AAAA", kind: .artwork))
    }

    private func testResponseValidation() {
        let url = URL(string: "https://lrclib.net/api/get")!
        let valid = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "application/json", "Content-Length": "512"]
        )!
        let wrongType = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "text/html"]
        )!
        let broadImageType = HTTPURLResponse(
            url: URL(string: "https://i.scdn.co/image/abc")!,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "image/svg+xml"]
        )!
        let oversized = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "application/json", "Content-Length": "3000000"]
        )!
        let redirect = HTTPURLResponse(
            url: url,
            statusCode: 302,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "application/json"]
        )!

        assertTrue(RemoteResourceSecurity.accepts(valid, for: .lyrics))
        assertFalse(RemoteResourceSecurity.accepts(wrongType, for: .lyrics))
        assertFalse(RemoteResourceSecurity.accepts(oversized, for: .lyrics))
        assertFalse(RemoteResourceSecurity.accepts(redirect, for: .lyrics))
        assertFalse(RemoteResourceSecurity.accepts(broadImageType, for: .artwork))
    }

    private func testMetadataSanitization() {
        let unsafe = "  Track\nName\u{200B}\u{202E}gpj.exe\u{0000}  "
        assertEqual(RemoteResourceSecurity.sanitizedMetadata(unsafe), "Track Name gpj.exe")
        assertEqual(MediaValue.metadata(String(repeating: "a", count: 400)).count, 256)
        assertEqual(RemoteResourceSecurity.sanitizedMetadata("\n\t"), "")
    }

    private func testInvalidImageRejected() {
        assertTrue(RemoteResourceSecurity.safeImage(from: Data()) == nil)
        assertTrue(RemoteResourceSecurity.safeImage(from: Data("not an image".utf8)) == nil)
    }

    private func testLyricsParsingIsBounded() {
        let excessive = (0..<5_500).map { "[00:01]line\($0)" }.joined(separator: "\n")
        assertEqual(LyricsService.parseLRC(excessive).count, 5_000)
        let longLine = "[00:01]" + String(repeating: "x", count: 3_000)
        assertTrue((LyricsService.parseLRC(longLine).first?.text.count ?? 0) <= 2_000)
    }

    private func isAllowed(_ rawURL: String, kind: RemoteResourceKind) -> Bool {
        guard let url = URL(string: rawURL) else { return false }
        return RemoteResourceSecurity.isAllowed(url, for: kind)
    }
}
