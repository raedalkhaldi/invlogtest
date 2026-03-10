import Foundation

struct Message: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let isRead: Bool
    let createdAt: Date
}

struct MessagesResponse: Codable {
    let data: [Message]
    let nextCursor: String?
}
