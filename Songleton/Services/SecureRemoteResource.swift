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
    case unexpectedContentType
    case responseTooLarge
    case invalidImage
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
        safeRequest.cachePolicy = .reloadIgnoringLocalCacheData
        safeRequest.setValue(kind == .lyrics ? "application/json" : "image/jpeg, image/png, image/webp, image/heic, image/heif", forHTTPHeaderField: "Accept")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.waitsForConnectivity = false

        let delegate = SecureRedirectDelegate(kind: kind)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (bytes, response) = try await session.bytes(for: safeRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              RemoteResourceSecurity.accepts(httpResponse, for: kind) else {
            throw SecureNetworkError.invalidResponse
        }

        var data = Data()
        let expectedLength = max(0, min(Int(response.expectedContentLength), kind.maximumBytes))
        data.reserveCapacity(expectedLength)
        for try await byte in bytes {
            guard data.count < kind.maximumBytes else {
                throw SecureNetworkError.responseTooLarge
            }
            data.append(byte)
        }
        return data
    }
}
