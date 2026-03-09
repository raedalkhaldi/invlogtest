import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIEndpoint {
    // Auth
    case register(email: String, password: String, username: String, displayName: String?)
    case login(email: String, password: String)
    case socialLogin(provider: String, idToken: String, displayName: String?)
    case refreshToken(token: String)
    case logout(refreshToken: String)
    case deleteAccount

    // Feed
    case feed(cursor: String?, limit: Int)
    case exploreFeed(cursor: String?, limit: Int)

    // Posts
    case createPost(content: String?, mediaIds: [String], restaurantId: String?, rating: Int?, latitude: Double?, longitude: Double?, locationName: String?)
    case postDetail(id: String)
    case updatePost(id: String, content: String?, rating: Int?)
    case deletePost(id: String)

    // Comments
    case comments(postId: String, cursor: String?, limit: Int)
    case createComment(postId: String, content: String, parentId: String?)
    case updateComment(id: String, content: String)
    case deleteComment(id: String)

    // Likes
    case likePost(id: String)
    case unlikePost(id: String)
    case likeComment(id: String)
    case unlikeComment(id: String)

    // Follows
    case followUser(id: String)
    case unfollowUser(id: String)
    case followRestaurant(id: String)
    case unfollowRestaurant(id: String)
    case followers(userId: String, page: Int, perPage: Int)
    case following(userId: String, page: Int, perPage: Int)

    // Users
    case currentUser
    case updateProfile(displayName: String?, bio: String?, isPrivate: Bool?)
    case userProfile(username: String)
    case userPosts(userId: String, cursor: String?, limit: Int)

    // Restaurants
    case createRestaurant(data: [String: Any])
    case restaurantDetail(slug: String)
    case updateRestaurant(id: String, data: [String: Any])
    case nearbyRestaurants(lat: Double, lng: Double, radiusKm: Double, limit: Int)
    case restaurantMenu(id: String)
    case addMenuItem(restaurantId: String, data: [String: Any])

    // Check-ins
    case createCheckIn(restaurantId: String, latitude: Double?, longitude: Double?, postId: String?)
    case recentCheckIns(cursor: String?, limit: Int)
    case restaurantCheckins(restaurantId: String, page: Int, perPage: Int)
    case userCheckins(userId: String, page: Int, perPage: Int)

    // Search
    case search(query: String, type: String?, lat: Double?, lng: Double?)

    // Notifications
    case notifications(cursor: String?, limit: Int)
    case markNotificationRead(id: String)
    case markAllNotificationsRead
    case registerDeviceToken(token: String)
    case unreadNotificationCount

    // Media
    case presignUpload(fileName: String, contentType: String, fileSize: Int)
    case completeUpload(mediaId: String)
    case mediaStatus(id: String)

    var method: HTTPMethod {
        switch self {
        case .register, .login, .socialLogin, .refreshToken, .logout,
             .createPost, .createComment, .likePost, .likeComment,
             .followUser, .followRestaurant, .createRestaurant,
             .createCheckIn, .addMenuItem, .registerDeviceToken,
             .presignUpload, .completeUpload:
            return .post
        case .updateProfile, .updatePost, .updateComment, .updateRestaurant,
             .markNotificationRead, .markAllNotificationsRead:
            return .patch
        case .deleteAccount, .deletePost, .deleteComment,
             .unlikePost, .unlikeComment, .unfollowUser, .unfollowRestaurant:
            return .delete
        default:
            return .get
        }
    }

    var path: String {
        switch self {
        // Auth
        case .register: return "/auth/register"
        case .login: return "/auth/login"
        case .socialLogin: return "/auth/social"
        case .refreshToken: return "/auth/refresh"
        case .logout: return "/auth/logout"
        case .deleteAccount: return "/auth/account"

        // Feed
        case .feed: return "/feed"
        case .exploreFeed: return "/feed/explore"

        // Posts
        case .createPost: return "/posts"
        case .postDetail(let id): return "/posts/\(id)"
        case .updatePost(let id, _, _): return "/posts/\(id)"
        case .deletePost(let id): return "/posts/\(id)"

        // Comments
        case .comments(let postId, _, _): return "/posts/\(postId)/comments"
        case .createComment(let postId, _, _): return "/posts/\(postId)/comments"
        case .updateComment(let id, _): return "/comments/\(id)"
        case .deleteComment(let id): return "/comments/\(id)"

        // Likes
        case .likePost(let id): return "/posts/\(id)/like"
        case .unlikePost(let id): return "/posts/\(id)/like"
        case .likeComment(let id): return "/comments/\(id)/like"
        case .unlikeComment(let id): return "/comments/\(id)/like"

        // Follows
        case .followUser(let id): return "/users/\(id)/follow"
        case .unfollowUser(let id): return "/users/\(id)/follow"
        case .followRestaurant(let id): return "/restaurants/\(id)/follow"
        case .unfollowRestaurant(let id): return "/restaurants/\(id)/follow"
        case .followers(let userId, _, _): return "/users/\(userId)/followers"
        case .following(let userId, _, _): return "/users/\(userId)/following"

        // Users
        case .currentUser: return "/users/me"
        case .updateProfile: return "/users/me"
        case .userProfile(let username): return "/users/\(username)"
        case .userPosts(let userId, _, _): return "/users/\(userId)/posts"

        // Restaurants
        case .createRestaurant: return "/restaurants"
        case .restaurantDetail(let slug): return "/restaurants/\(slug)"
        case .updateRestaurant(let id, _): return "/restaurants/\(id)"
        case .nearbyRestaurants: return "/restaurants/nearby"
        case .restaurantMenu(let id): return "/restaurants/\(id)/menu"
        case .addMenuItem(let restaurantId, _): return "/restaurants/\(restaurantId)/menu"

        // Check-ins
        case .createCheckIn: return "/checkins"
        case .recentCheckIns: return "/checkins/recent"
        case .restaurantCheckins(let restaurantId, _, _): return "/restaurants/\(restaurantId)/checkins"
        case .userCheckins(let userId, _, _): return "/checkins/user/\(userId)"

        // Search
        case .search: return "/search"

        // Notifications
        case .notifications: return "/notifications"
        case .markNotificationRead(let id): return "/notifications/\(id)/read"
        case .markAllNotificationsRead: return "/notifications/read-all"
        case .registerDeviceToken: return "/notifications/device-token"
        case .unreadNotificationCount: return "/notifications/unread-count"

        // Media
        case .presignUpload: return "/media/presign"
        case .completeUpload(let mediaId): return "/media/\(mediaId)/complete"
        case .mediaStatus(let id): return "/media/\(id)"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .feed(let cursor, let limit), .exploreFeed(let cursor, let limit),
             .recentCheckIns(let cursor, let limit), .notifications(let cursor, let limit):
            var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
            if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
            return items
        case .comments(_, let cursor, let limit), .userPosts(_, let cursor, let limit):
            var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
            if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
            return items
        case .followers(_, let page, let perPage), .following(_, let page, let perPage),
             .restaurantCheckins(_, let page, let perPage), .userCheckins(_, let page, let perPage):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "perPage", value: "\(perPage)"),
            ]
        case .nearbyRestaurants(let lat, let lng, let radiusKm, let limit):
            return [
                URLQueryItem(name: "lat", value: "\(lat)"),
                URLQueryItem(name: "lng", value: "\(lng)"),
                URLQueryItem(name: "radiusKm", value: "\(radiusKm)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        case .search(let query, let type, let lat, let lng):
            var items: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
            if let type { items.append(URLQueryItem(name: "type", value: type)) }
            if let lat { items.append(URLQueryItem(name: "lat", value: "\(lat)")) }
            if let lng { items.append(URLQueryItem(name: "lng", value: "\(lng)")) }
            return items
        default:
            return nil
        }
    }

    var body: [String: Any]? {
        switch self {
        case .register(let email, let password, let username, let displayName):
            var body: [String: Any] = ["email": email, "password": password, "username": username]
            if let displayName { body["displayName"] = displayName }
            return body
        case .login(let email, let password):
            return ["email": email, "password": password]
        case .socialLogin(let provider, let idToken, let displayName):
            var body: [String: Any] = ["provider": provider, "idToken": idToken]
            if let displayName { body["displayName"] = displayName }
            return body
        case .refreshToken(let token):
            return ["refreshToken": token]
        case .logout(let refreshToken):
            return ["refreshToken": refreshToken]
        case .createPost(let content, let mediaIds, let restaurantId, let rating, let lat, let lng, let locationName):
            var body: [String: Any] = ["mediaIds": mediaIds]
            if let content { body["content"] = content }
            if let restaurantId { body["restaurantId"] = restaurantId }
            if let rating { body["rating"] = rating }
            if let lat { body["latitude"] = lat }
            if let lng { body["longitude"] = lng }
            if let locationName { body["locationName"] = locationName }
            return body
        case .createComment(_, let content, let parentId):
            var body: [String: Any] = ["content": content]
            if let parentId { body["parentId"] = parentId }
            return body
        case .updateComment(_, let content):
            return ["content": content]
        case .updatePost(_, let content, let rating):
            var body: [String: Any] = [:]
            if let content { body["content"] = content }
            if let rating { body["rating"] = rating }
            return body
        case .updateProfile(let displayName, let bio, let isPrivate):
            var body: [String: Any] = [:]
            if let displayName { body["displayName"] = displayName }
            if let bio { body["bio"] = bio }
            if let isPrivate { body["isPrivate"] = isPrivate }
            return body
        case .createCheckIn(let restaurantId, let lat, let lng, let postId):
            var body: [String: Any] = ["restaurantId": restaurantId]
            if let lat { body["latitude"] = lat }
            if let lng { body["longitude"] = lng }
            if let postId { body["postId"] = postId }
            return body
        case .registerDeviceToken(let token):
            return ["token": token]
        case .presignUpload(let fileName, let contentType, let fileSize):
            return ["fileName": fileName, "contentType": contentType, "fileSize": fileSize]
        case .completeUpload:
            return [:]
        case .createRestaurant(let data), .updateRestaurant(_, let data), .addMenuItem(_, let data):
            return data
        default:
            return nil
        }
    }

    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }
}
