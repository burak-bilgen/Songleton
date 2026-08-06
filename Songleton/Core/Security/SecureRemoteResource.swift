import AppKit
import Foundation
import ImageIO

nonisolated enum RemoteResourceKind: Sendable {
    case lyrics
    case artwork

    var maximumBytes: Int {
        switch self {
        case .lyrics: 2 * 1024 * 1024
        case .artwork: 8 * 1024 * 1024
        }
    }

    func accepts(mimeType: String?) -> Bool {
        guard let mimeType = mimeType?.lowercased() else { return false }
        switch self {
        case .lyrics:
            return mimeType == "application/json" || mimeType == "text/json"
        case .artwork:
            return ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"].contains(mimeType)
        }
    }
}

nonisolated enum SecureNetworkError: Error, Sendable {
    case disallowedURL
    case invalidResponse
    case responseTooLarge
}

nonisolated enum RemoteResourceSecurity {
    private static let spotifyArtworkDomains = ["scdn.co", "spotifycdn.com"]
    private static let maximumImageDimension = 8_192
    private static let maximumImagePixels = 40_000_000

    static func isAllowed(_ url: URL, for kind: RemoteResourceKind) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.port == nil || components.port == 443 else {
            return false
        }

        switch kind {
        case .lyrics:
            return host == "lrclib.net"
        case .artwork:
            return spotifyArtworkDomains.contains { domain in
                host == domain || host.hasSuffix(".\(domain)")
            }
        }
    }

    static func accepts(_ response: HTTPURLResponse, for kind: RemoteResourceKind) -> Bool {
        guard response.statusCode == 200,
              let url = response.url,
              isAllowed(url, for: kind),
              kind.accepts(mimeType: response.mimeType) else {
            return false
        }
        let expectedLength = response.expectedContentLength
        return expectedLength < 0 || expectedLength <= Int64(kind.maximumBytes)
    }

    static func sanitizedMetadata(_ value: String, maximumLength: Int = 256) -> String {
        guard maximumLength > 0 else { return "" }
        let space = UnicodeScalar(0x20)!
        let filteredScalars = value.precomposedStringWithCanonicalMapping.unicodeScalars.map { scalar in
            CharacterSet.controlCharacters.contains(scalar) || isInvisibleFormattingScalar(scalar.value)
                ? space
                : scalar
        }
        let bounded = String(String.UnicodeScalarView(filteredScalars.prefix(maximumLength)))
        return bounded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func safeImage(from data: Data) -> NSImage? {
        guard !data.isEmpty, data.count <= RemoteResourceKind.artwork.maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0,
              width <= maximumImageDimension, height <= maximumImageDimension,
              width.multipliedReportingOverflow(by: height).overflow == false,
              width * height <= maximumImagePixels else {
            return nil
        }
        if max(width, height) > 512 {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
            }
        }
        return NSImage(data: data)
    }

    private static func isInvisibleFormattingScalar(_ value: UInt32) -> Bool {
        value == 0x061C || value == 0x200B || value == 0x200E || value == 0x200F
            || (0x202A...0x202E).contains(value)
            || (0x2066...0x2069).contains(value)
            || value == 0xFEFF
    }
}

nonisolated private final class SecureRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let kind: RemoteResourceKind

    init(kind: RemoteResourceKind) {
        self.kind = kind
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, RemoteResourceSecurity.isAllowed(url, for: kind) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

nonisolated enum SecureRemoteResource {
    /// Persistent per-kind sessions: a fresh URLSession per request meant every
    /// artwork download re-did DNS + TCP + TLS handshakes from scratch and never
    /// reused responses — the main reason covers arrived seconds late. A shared
    /// session keeps connections alive and honors an in-memory/disk URL cache,
    /// while cookies and credential storage stay disabled for security.
    private static func makeSession(kind: RemoteResourceKind) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 32 * 1024 * 1024
        )
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        // Artwork is announced in the track-change toast as soon as it lands, so
        // keep its download budget tight; lyrics keep the longer one.
        let isArtwork = kind == .artwork
        configuration.timeoutIntervalForRequest = isArtwork ? 4 : 8
        configuration.timeoutIntervalForResource = isArtwork ? 6 : 12
        configuration.waitsForConnectivity = false
        return URLSession(
            configuration: configuration,
            delegate: SecureRedirectDelegate(kind: kind),
            delegateQueue: nil
        )
    }

    nonisolated private static let artworkSession = makeSession(kind: .artwork)
    nonisolated private static let lyricsSession = makeSession(kind: .lyrics)

    static func data(for request: URLRequest, kind: RemoteResourceKind) async throws -> Data {
        guard let url = request.url,
              request.httpMethod == nil || request.httpMethod == "GET",
              request.httpBody == nil,
              request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              RemoteResourceSecurity.isAllowed(url, for: kind) else {
            throw SecureNetworkError.disallowedURL
        }

        var safeRequest = URLRequest(url: url)
        safeRequest.httpMethod = "GET"
        safeRequest.setValue(kind == .lyrics ? "application/json" : "image/jpeg, image/png, image/webp, image/heic, image/heif", forHTTPHeaderField: "Accept")

        let session = kind == .lyrics ? lyricsSession : artworkSession
        let (data, response) = try await session.data(for: safeRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              RemoteResourceSecurity.accepts(httpResponse, for: kind) else {
            throw SecureNetworkError.invalidResponse
        }
        guard data.count <= kind.maximumBytes else {
            throw SecureNetworkError.responseTooLarge
        }
        return data
    }
}
