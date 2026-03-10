import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let participantOneId: String
    let participantTwoId: String
    let lastMessageText: String?
    let lastMessageAt: Date?
    let createdAt: Date
    let otherUser: ConversationUser?
    let unreadCount: Int?
}

struct ConversationUser: Codable, Hashable {
    let id: String?
    let username: String?
    let displayName: String?
    let avatarUrl: URL?
    let isVerified: Bool?
}

struct ConversationsResponse: Codable {
    let data: [Conversation]
    let nextCursor: String?
}
