import Foundation

struct AppNotification: Codable, Identifiable, Hashable {
    let id: String
    let recipientId: String
    let actorId: String?
    let actor: User?
    let type: String
    let targetType: String?
    let targetId: String?
    let message: String?
    let isRead: Bool
    let createdAt: Date
}
