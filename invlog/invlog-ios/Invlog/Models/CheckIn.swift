import Foundation

struct CheckIn: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let restaurantId: String
    let restaurant: Restaurant?
    let user: User?
    let postId: String?
    let createdAt: Date
}
