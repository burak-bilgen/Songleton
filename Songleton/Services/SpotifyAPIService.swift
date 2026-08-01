import Foundation

// MARK: - SpotifyUserPlaylist

struct SpotifyUserPlaylist: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let uri: String
    let imageUrl: String?
    let tracksCount: Int
}

// MARK: - SpotifyAPIService

final class SpotifyAPIService {
    static let shared = SpotifyAPIService()

    private init() {}

    func fetchUserPlaylists(accessToken: String) async throws -> [SpotifyUserPlaylist] {
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=50") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let items = json?["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String,
                  let uri = item["uri"] as? String else { return nil }

            let desc = item["description"] as? String ?? ""
            var imgUrl: String? = nil
            if let images = item["images"] as? [[String: Any]], let firstImg = images.first, let urlStr = firstImg["url"] as? String {
                imgUrl = urlStr
            }

            let tracksDict = item["tracks"] as? [String: Any]
            let count = tracksDict?["total"] as? Int ?? 0

            return SpotifyUserPlaylist(
                id: id,
                name: name,
                description: desc,
                uri: uri,
                imageUrl: imgUrl,
                tracksCount: count
            )
        }
    }
}
