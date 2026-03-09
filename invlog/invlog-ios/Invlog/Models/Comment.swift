import Foundation

struct Comment: Codable, Identifiable, Hashable {
    let id: String
    let postId: String
    let authorId: String
    let author: User?
    let parentId: String?
    let content: String
    let likeCount: Int
    let createdAt: Date
    var isLikedByMe: Bool?
}
