import Foundation

struct Post: Codable, Identifiable, Hashable {
    let id: String
    let authorId: String
    let author: User?
    let restaurantId: String?
    let restaurant: Restaurant?
    let content: String?
    let rating: Int?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let locationAddress: String?
    let likeCount: Int
    var commentCount: Int
    let isPublic: Bool
    let media: [PostMedia]?
    let recentComments: [Comment]?
    let createdAt: Date
    var isLikedByMe: Bool?
    var isBookmarkedByMe: Bool?
}

struct PostMedia: Codable, Identifiable, Hashable {
    let id: String
    let mediaType: String
    let url: String
    let mediumUrl: String?
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
    let durationSecs: Double?
    let sortOrder: Int?
    let blurhash: String?
    let processingStatus: String?
}

/// Wrapper for cursor-paginated feed responses from backend
struct FeedResponse: Codable {
    let data: [Post]
    let nextCursor: String?
}
