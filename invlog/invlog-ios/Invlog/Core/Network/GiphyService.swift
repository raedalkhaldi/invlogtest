import Foundation

// MARK: - Sticker Model (works with Tenor API)

struct GiphySticker: Identifiable, Equatable, Hashable {
    let id: String
    let url: URL           // Full-size GIF
    let previewUrl: URL    // Small preview for picker grid
    let width: CGFloat
    let height: CGFloat

    static func == (lhs: GiphySticker, rhs: GiphySticker) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tenor API Service (Google's GIF/Sticker platform)

actor GiphyService {
    static let shared = GiphyService()

    // Tenor API (free, no rate limits for reasonable usage)
    private let apiKey = "AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ"
    private let clientKey = "invlog"
    private let baseURL = "https://tenor.googleapis.com/v2"
    private let session = URLSession.shared

    // MARK: - Trending / Featured

    func trending(offset: Int = 0, limit: Int = 25) async throws -> [GiphySticker] {
        var components = URLComponents(string: "\(baseURL)/featured")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "contentfilter", value: "medium"),
            URLQueryItem(name: "media_filter", value: "tinygif,gif")
        ]
        if offset > 0 {
            components.queryItems?.append(URLQueryItem(name: "pos", value: "\(offset)"))
        }
        return try await fetch(url: components.url!)
    }

    // MARK: - Search

    func search(query: String, offset: Int = 0, limit: Int = 25) async throws -> [GiphySticker] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "contentfilter", value: "medium"),
            URLQueryItem(name: "media_filter", value: "tinygif,gif")
        ]
        if offset > 0 {
            components.queryItems?.append(URLQueryItem(name: "pos", value: "\(offset)"))
        }
        return try await fetch(url: components.url!)
    }

    // MARK: - Private

    private func fetch(url: URL) async throws -> [GiphySticker] {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GiphyError.requestFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["results"] as? [[String: Any]] else {
            throw GiphyError.invalidResponse
        }

        return results.compactMap { item -> GiphySticker? in
            guard let id = item["id"] as? String,
                  let mediaFormats = item["media_formats"] as? [String: Any] else { return nil }

            // Preview: tinygif (small, fast loading)
            guard let tinygif = mediaFormats["tinygif"] as? [String: Any],
                  let tinyUrlStr = tinygif["url"] as? String,
                  let tinyUrl = URL(string: tinyUrlStr),
                  let tinyDims = tinygif["dims"] as? [Int], tinyDims.count >= 2 else { return nil }

            // Full: gif (high quality)
            guard let gif = mediaFormats["gif"] as? [String: Any],
                  let gifUrlStr = gif["url"] as? String,
                  let gifUrl = URL(string: gifUrlStr),
                  let gifDims = gif["dims"] as? [Int], gifDims.count >= 2 else { return nil }

            return GiphySticker(
                id: "\(id)",
                url: gifUrl,
                previewUrl: tinyUrl,
                width: CGFloat(gifDims[0]),
                height: CGFloat(gifDims[1])
            )
        }
    }
}

// MARK: - Errors

enum GiphyError: LocalizedError {
    case requestFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed: return "Failed to load stickers"
        case .invalidResponse: return "Invalid sticker data"
        }
    }
}
