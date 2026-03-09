import Foundation

struct Restaurant: Codable, Identifiable, Hashable {
    let id: String
    let ownerId: String
    let name: String
    let slug: String
    let description: String?
    let cuisineType: [String]?
    let phone: String?
    let email: String?
    let website: String?
    let avatarUrl: URL?
    let coverUrl: URL?
    let latitude: Double?
    let longitude: Double?
    let addressLine1: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let priceRange: Int?
    let avgRating: Double
    let reviewCount: Int
    let followerCount: Int
    let checkinCount: Int
    let isVerified: Bool
    let operatingHours: [OperatingHoursModel]?
    let menuItems: [MenuItemModel]?
    var isFollowedByMe: Bool?
    var distance: Double?
}

struct OperatingHoursModel: Codable, Identifiable, Hashable {
    let id: String
    let dayOfWeek: Int
    let openTime: String
    let closeTime: String
    let isClosed: Bool
}

struct MenuItemModel: Codable, Identifiable, Hashable {
    let id: String
    let category: String?
    let name: String
    let description: String?
    let price: Double?
    let currency: String
    let imageUrl: URL?
    let isAvailable: Bool
    let dietaryTags: [String]?
    let sortOrder: Int
}
