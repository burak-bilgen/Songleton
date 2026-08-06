import AppKit
import Foundation
import SwiftUI

final class ArtworkPipelineTests {
    private var tempDirectory: URL!

    func runAllTests() {
        runTest(name: "testRetryBackoffBlocksRecentFailure", test: testRetryBackoffBlocksRecentFailure)
        runTest(name: "testRetryBackoffAllowsRetryAfterInterval", test: testRetryBackoffAllowsRetryAfterInterval)
        runTest(name: "testRetryBackoffIgnoresOtherKeys", test: testRetryBackoffIgnoresOtherKeys)
        runTest(name: "testStaleResultGuard", test: testStaleResultGuard)
        runTest(name: "testArtworkKeyIsStableAndUnique", test: testArtworkKeyIsStableAndUnique)
        runTest(name: "testMemoryCacheHitReturnsCachedColor", test: testMemoryCacheHitReturnsCachedColor)
        runTest(name: "testDiskCacheHitSurvivesNewInstance", test: testDiskCacheHitSurvivesNewInstance)
        runTest(name: "testCacheBoundsStayWithinCaps", test: testCacheBoundsStayWithinCaps)
        runTest(name: "testDeterministicFileName", test: testDeterministicFileName)
    }

    private func runTest(name: String, test: () -> Void) {
        TestObserver.shared.totalCount += 1
        print("  • \(name)...")
        // Every test gets an isolated scratch directory; the shared cache is
        // left untouched.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArtworkPipelineTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectory = dir
        defer {
            try? FileManager.default.removeItem(at: dir)
            tempDirectory = nil
        }
        test()
    }

    // MARK: - Retry backoff

    func testRetryBackoffBlocksRecentFailure() {
        let now = Date()
        assertFalse(
            ArtworkPipeline.shouldAttemptDownload(
                key: "a", lastFailureKey: "a", lastFailureAt: now.addingTimeInterval(-1), now: now
            ),
            "A failure one second ago must block a retry"
        )
    }

    func testRetryBackoffAllowsRetryAfterInterval() {
        let now = Date()
        assertTrue(
            ArtworkPipeline.shouldAttemptDownload(
                key: "a",
                lastFailureKey: "a",
                lastFailureAt: now.addingTimeInterval(-ArtworkPipeline.retryInterval - 1),
                now: now
            ),
            "A failure older than the retry interval must allow a retry"
        )
    }

    func testRetryBackoffIgnoresOtherKeys() {
        let now = Date()
        assertTrue(
            ArtworkPipeline.shouldAttemptDownload(
                key: "b", lastFailureKey: "a", lastFailureAt: now.addingTimeInterval(-1), now: now
            ),
            "A failure for another track must not block this track"
        )
        assertTrue(
            ArtworkPipeline.shouldAttemptDownload(key: "a", lastFailureKey: nil, lastFailureAt: nil, now: now),
            "No recorded failure must always allow a download"
        )
    }

    // MARK: - Stale-result guard

    func testStaleResultGuard() {
        assertTrue(ArtworkPipeline.shouldPublish(resultKey: "b", currentKey: "b"))
        assertFalse(ArtworkPipeline.shouldPublish(resultKey: "a", currentKey: "b"))
        assertFalse(ArtworkPipeline.shouldPublish(resultKey: "a", currentKey: nil))
    }

    // MARK: - Cache keys

    func testArtworkKeyIsStableAndUnique() {
        let url = URL(string: "https://i.scdn.co/image/ab67616d0000b273abc123")!
        let k1 = ArtworkPipeline.key(source: "Spotify", artworkURL: url, track: "T", artist: "A", album: "Al")
        let k2 = ArtworkPipeline.key(source: "Spotify", artworkURL: url, track: "T", artist: "A", album: "Al")
        assertEqual(k1, k2, "Same artwork URL must map to the same cache key")

        let otherURL = URL(string: "https://i.scdn.co/image/ab67616d0000b273def456")!
        assertTrue(
            k1 != ArtworkPipeline.key(source: "Spotify", artworkURL: otherURL, track: "T", artist: "A", album: "Al"),
            "Different artwork URLs must map to different keys"
        )

        let noURL = ArtworkPipeline.key(source: "Apple Music", artworkURL: nil, track: "T", artist: "A", album: "Al")
        assertTrue(noURL.contains("Apple Music|T|A|Al"), "No-URL tracks must fall back to the metadata composite")
    }

    // MARK: - Cache behavior

    func testMemoryCacheHitReturnsCachedColor() {
        let cache = makeCache()
        let url = URL(string: "https://i.scdn.co/image/abc")!
        let (data, image, color) = makeArtwork()

        cache.store(image: image, color: color, data: data, for: url)
        let hit = cache.entry(for: url)
        assertTrue(hit != nil, "Memory entry must be retrievable")
        assertTrue(hit?.image === image, "Memory hit must return the exact cached image")
        assertTrue(hit?.color == color, "Cached color must be returned without re-extraction")
    }

    func testDiskCacheHitSurvivesNewInstance() {
        let url = URL(string: "https://i.scdn.co/image/abc")!
        let (data, image, color) = makeArtwork()

        let first = makeCache()
        first.store(image: image, color: color, data: data, for: url)

        // A brand-new cache instance over the same directory must recover the
        // cover from disk.
        let second = ArtworkCache(diskDirectory: tempDirectory)
        let hit = second.entry(for: url)
        assertTrue(hit != nil, "Disk mirror must survive a fresh cache instance")
        assertTrue(hit?.color == color, "Disk hit must still compute/publish a color")
    }

    func testCacheBoundsStayWithinCaps() {
        let cache = makeCache()
        let (data, image, color) = makeArtwork()

        for index in 0..<(ArtworkCache.maximumMemoryEntries + 25) {
            let url = URL(string: "https://i.scdn.co/image/\(index)")!
            cache.store(image: image, color: color, data: data, for: url)
        }
        assertTrue(
            cache.memoryCount <= ArtworkCache.maximumMemoryEntries,
            "Memory cache must stay within its cap"
        )
        assertTrue(
            cache.diskFileCount <= ArtworkCache.maximumDiskEntries,
            "Disk mirror must stay within its cap"
        )
    }

    func testDeterministicFileName() {
        let url = URL(string: "https://i.scdn.co/image/abc")!
        assertEqual(ArtworkCache.fileName(for: url), ArtworkCache.fileName(for: url))
        let other = URL(string: "https://i.scdn.co/image/def")!
        assertTrue(ArtworkCache.fileName(for: url) != ArtworkCache.fileName(for: other))
    }

    // MARK: - Helpers

    private func makeCache() -> ArtworkCache {
        ArtworkCache(diskDirectory: tempDirectory)
    }

    /// Builds a small valid PNG that passes the remote-resource security gate.
    private func makeArtwork() -> (data: Data, image: NSImage, color: Color) {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.systemOrange.setFill()
        NSRect(x: 0, y: 0, width: 16, height: 16).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not synthesize test artwork")
        }
        let decoded = RemoteResourceSecurity.safeImage(from: data)!
        let color = ArtworkCache.extractDominantColor(from: decoded)
        return (data, decoded, color)
    }
}
