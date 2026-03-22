import Foundation
import CoreLocation

// MARK: - Foursquare Place Model

struct FoursquarePlace: Identifiable, Equatable {
    let id: String          // fsq_place_id
    let name: String
    let address: String
    let city: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let distance: Int       // meters
    let categories: [FoursquareCategory]
    let chainName: String?

    var primaryCategory: String? {
        categories.first?.name
    }

    var categoryIcon: URL? {
        guard let cat = categories.first else { return nil }
        return URL(string: "\(cat.iconPrefix)64\(cat.iconSuffix)")
    }

    var formattedDistance: String {
        if distance < 1000 {
            return "\(distance)m"
        } else {
            return String(format: "%.1fkm", Double(distance) / 1000.0)
        }
    }
}

struct FoursquareCategory: Equatable {
    let id: String
    let name: String
    let shortName: String
    let iconPrefix: String
    let iconSuffix: String
}

// MARK: - Foursquare Service

final class FoursquareService {
    static let shared = FoursquareService()

    private let apiKey = "UVJ1F2XSWNL1YC3Q0VCKJWEX42C0AW2J0IK023O3YNW4VJ4T"
    private let baseURL = "https://places-api.foursquare.com"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    /// Search for places near a location
    func search(query: String, latitude: Double, longitude: Double, radius: Int = 5000, limit: Int = 20) async throws -> [FoursquarePlace] {
        var components = URLComponents(string: "\(baseURL)/places/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "limit", value: "\(min(limit, 50))"),
            URLQueryItem(name: "sort", value: "DISTANCE"),
        ]

        return try await fetchPlaces(url: components.url!)
    }

    /// Get nearby places (no query, just location-based)
    func nearby(latitude: Double, longitude: Double, radius: Int = 3000, limit: Int = 20, categories: String? = nil) async throws -> [FoursquarePlace] {
        var components = URLComponents(string: "\(baseURL)/places/search")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)"),
            URLQueryItem(name: "limit", value: "\(min(limit, 50))"),
            URLQueryItem(name: "sort", value: "DISTANCE"),
        ]
        if let categories {
            items.append(URLQueryItem(name: "categories", value: categories))
        }
        components.queryItems = items

        return try await fetchPlaces(url: components.url!)
    }

    // MARK: - Foursquare Food Category IDs

    /// Common food/drink category IDs for filtering
    static let foodCategories: [String: String] = [
        "restaurant": "13065",          // Restaurant
        "cafe": "13032",                // Cafe, Coffee, Tea
        "bar": "13003",                 // Bar
        "bakery": "13002",              // Bakery
        "dessert": "13040",             // Dessert Shop
        "fastFood": "13145",            // Fast Food
        "pizza": "13064",               // Pizzeria
        "burger": "13031",              // Burger Joint
        "sushi": "13276",               // Sushi
        "steakhouse": "13236",          // Steakhouse
    ]

    // MARK: - Private

    private func fetchPlaces(url: URL) async throws -> [FoursquarePlace] {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("2025-06-17", forHTTPHeaderField: "X-Places-Api-Version")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoursquareError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                throw FoursquareError.apiError(message)
            }
            throw FoursquareError.httpError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        return results.compactMap { parsePlaceJSON($0) }
    }

    private func parsePlaceJSON(_ json: [String: Any]) -> FoursquarePlace? {
        guard let id = json["fsq_place_id"] as? String,
              let name = json["name"] as? String,
              let lat = json["latitude"] as? Double,
              let lng = json["longitude"] as? Double else {
            return nil
        }

        // Parse location
        let location = json["location"] as? [String: Any]
        let address = location?["formatted_address"] as? String
            ?? location?["address"] as? String
            ?? ""
        let city = location?["locality"] as? String
        let country = location?["country"] as? String

        // Parse categories
        let categoriesJSON = json["categories"] as? [[String: Any]] ?? []
        let categories = categoriesJSON.compactMap { catJSON -> FoursquareCategory? in
            guard let catId = catJSON["fsq_category_id"] as? String,
                  let catName = catJSON["name"] as? String else { return nil }
            let shortName = catJSON["short_name"] as? String ?? catName
            let icon = catJSON["icon"] as? [String: String]
            return FoursquareCategory(
                id: catId,
                name: catName,
                shortName: shortName,
                iconPrefix: icon?["prefix"] ?? "",
                iconSuffix: icon?["suffix"] ?? ""
            )
        }

        // Parse chain
        let chains = json["chains"] as? [[String: Any]]
        let chainName = chains?.first?["name"] as? String

        let distance = json["distance"] as? Int ?? 0

        return FoursquarePlace(
            id: id,
            name: name,
            address: address,
            city: city,
            country: country,
            latitude: lat,
            longitude: lng,
            distance: distance,
            categories: categories,
            chainName: chainName
        )
    }
}

// MARK: - Errors

enum FoursquareError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Foursquare"
        case .httpError(let code): return "Foursquare API error (HTTP \(code))"
        case .apiError(let msg): return msg
        }
    }
}
