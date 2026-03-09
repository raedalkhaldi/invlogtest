import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let username: String
    let displayName: String?
    let bio: String?
    let avatarUrl: URL?
    let coverUrl: URL?
    let isVerified: Bool
    let isPrivate: Bool
    let followerCount: Int
    let followingCount: Int
    let postCount: Int
    var isFollowedByMe: Bool?
}
