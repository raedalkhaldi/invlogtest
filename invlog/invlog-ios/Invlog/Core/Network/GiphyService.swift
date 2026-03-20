import Foundation

// MARK: - Giphy Sticker Model

struct GiphySticker: Identifiable, Equatable, Hashable {
    let id: String
    let url: URL           // Original full-size sticker
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

// MARK: - Giphy API Service

actor GiphyService {
    static let shared = GiphyService()

    // Free-tier beta key (rate-limited, for development)
    // Replace with production key from https://developers.giphy.com
    private let apiKey = "dc6zaTOxFJmzC"
    private let baseURL = "https://api.giphy.com/v1/stickers"
    private let session = URLSession.shared

    // MARK: - Trending Stickers

    func trending(offset: Int = 0, limit: Int = 25) async throws -> [GiphySticker] {
        var components = URLComponents(string: "\(baseURL)/trending")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "rating", value: "pg"),
            URLQueryItem(name: "bundle", value: "sticker_layer_sdk")
        ]
        return try await fetch(url: components.url!)
    }

    // MARK: - Search Stickers

    func search(query: String, offset: Int = 0, limit: Int = 25) async throws -> [GiphySticker] {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "rating", value: "pg"),
            URLQueryItem(name: "bundle", value: "sticker_layer_sdk")
        ]
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
        guard let dataArray = json?["data"] as? [[String: Any]] else {
            throw GiphyError.invalidResponse
        }

        return dataArray.compactMap { item -> GiphySticker? in
            guard let id = item["id"] as? String,
                  let images = item["images"] as? [String: Any] else { return nil }

            // Use fixed_width for preview (smaller, faster)
            guard let fixedWidth = images["fixed_width"] as? [String: Any],
                  let previewUrlStr = fixedWidth["url"] as? String,
                  let previewUrl = URL(string: previewUrlStr) else { return nil }

            // Use original for full-size overlay
            guard let original = images["original"] as? [String: Any],
                  let originalUrlStr = original["url"] as? String,
                  let originalUrl = URL(string: originalUrlStr) else { return nil }

            let width = CGFloat(Double(original["width"] as? String ?? "200") ?? 200)
            let height = CGFloat(Double(original["height"] as? String ?? "200") ?? 200)

            return GiphySticker(
                id: id,
                url: originalUrl,
                previewUrl: previewUrl,
                width: width,
                height: height
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
