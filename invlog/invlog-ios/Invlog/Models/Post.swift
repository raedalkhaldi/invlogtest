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
    let likeCount: Int
    let commentCount: Int
    let isPublic: Bool
    let media: [PostMedia]
    let createdAt: Date
    var isLikedByMe: Bool?
}

struct PostMedia: Codable, Identifiable, Hashable {
    let id: String
    let mediaType: String
    let url: URL
    let thumbnailUrl: URL?
    let width: Int?
    let height: Int?
    let durationSecs: Double?
    let sortOrder: Int
    let blurhash: String?
    let processingStatus: String
}
