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

    enum CodingKeys: String, CodingKey {
        case id, recipientId, actorId, actor, type
        case targetType, targetId, message, isRead, createdAt
    }

    init(id: String, recipientId: String, actorId: String?, actor: User?,
         type: String, targetType: String?, targetId: String?,
         message: String?, isRead: Bool, createdAt: Date) {
        self.id = id
        self.recipientId = recipientId
        self.actorId = actorId
        self.actor = actor
        self.type = type
        self.targetType = targetType
        self.targetId = targetId
        self.message = message
        self.isRead = isRead
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        recipientId = try container.decode(String.self, forKey: .recipientId)
        actorId = try container.decodeIfPresent(String.self, forKey: .actorId)
        // Gracefully handle actor decode failure (partial User data from query)
        actor = try? container.decodeIfPresent(User.self, forKey: .actor)
        type = try container.decode(String.self, forKey: .type)
        targetType = try container.decodeIfPresent(String.self, forKey: .targetType)
        targetId = try container.decodeIfPresent(String.self, forKey: .targetId)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        isRead = (try? container.decode(Bool.self, forKey: .isRead)) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
