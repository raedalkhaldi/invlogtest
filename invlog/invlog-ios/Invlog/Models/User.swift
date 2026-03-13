import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String?
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

    // Resilient decoding — missing or null fields get sensible defaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "user"
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        avatarUrl = try container.decodeIfPresent(URL.self, forKey: .avatarUrl)
        coverUrl = try container.decodeIfPresent(URL.self, forKey: .coverUrl)
        isVerified = (try? container.decodeIfPresent(Bool.self, forKey: .isVerified)) ?? false
        isPrivate = (try? container.decodeIfPresent(Bool.self, forKey: .isPrivate)) ?? false
        followerCount = (try? container.decodeIfPresent(Int.self, forKey: .followerCount)) ?? 0
        followingCount = (try? container.decodeIfPresent(Int.self, forKey: .followingCount)) ?? 0
        postCount = (try? container.decodeIfPresent(Int.self, forKey: .postCount)) ?? 0
        isFollowedByMe = try container.decodeIfPresent(Bool.self, forKey: .isFollowedByMe)
    }

    enum CodingKeys: String, CodingKey {
        case id, email, username, displayName, bio
        case avatarUrl, coverUrl, isVerified, isPrivate
        case followerCount, followingCount, postCount, isFollowedByMe
    }
}
