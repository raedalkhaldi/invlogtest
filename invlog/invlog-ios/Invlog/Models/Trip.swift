import Foundation

struct Trip: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let coverImageUrl: String?
    let startDate: Date?
    let endDate: Date?
    let visibility: String
    let status: String
    let ownerId: String
    let owner: TripUser?
    let likeCount: Int
    let saveCount: Int
    let stopCount: Int
    let stops: [TripStop]?
    let collaborators: [TripCollaborator]?
    let createdAt: Date
    let updatedAt: Date
}

struct TripStop: Codable, Identifiable, Hashable {
    let id: String
    let tripId: String
    let restaurantId: String?
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let dayNumber: Int
    let sortOrder: Int
    let startTime: String?
    let endTime: String?
    let notes: String?
    let category: String
    let estimatedDuration: Int?
    let createdAt: Date
}

struct TripCollaborator: Codable, Identifiable, Hashable {
    let id: String
    let tripId: String
    let userId: String
    let user: TripUser?
    let role: String
    let createdAt: Date
}

struct TripUser: Codable, Hashable {
    let id: String?
    let username: String?
    let displayName: String?
    let avatarUrl: URL?
}

struct TripsResponse: Codable {
    let data: [Trip]
    let nextCursor: String?
}
