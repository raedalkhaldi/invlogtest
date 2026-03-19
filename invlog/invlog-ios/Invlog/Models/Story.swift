import Foundation

struct Story: Codable, Identifiable, Hashable {
    let id: String
    let authorId: String
    let mediaType: String
    let url: String
    let thumbnailUrl: String?
    let blurhash: String?
    let durationSecs: Double?
    let viewCount: Int
    let likeCount: Int?
    let commentCount: Int?
    let createdAt: Date
    let expiresAt: Date
    var isViewedByMe: Bool?
    var isLikedByMe: Bool?
    var caption: String?
    var locationName: String?
    let restaurantId: String?
}

struct StoryGroup: Codable, Identifiable, Hashable {
    var id: String { user.id ?? UUID().uuidString }
    let user: StoryUser
    var stories: [Story]
    let hasUnviewed: Bool
    let latestAt: Date
}

struct StoryUser: Codable, Hashable {
    let id: String?
    let username: String?
    let displayName: String?
    let avatarUrl: URL?
    let isVerified: Bool?
}
