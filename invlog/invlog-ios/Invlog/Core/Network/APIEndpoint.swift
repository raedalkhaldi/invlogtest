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
    case createPost(content: String?, mediaIds: [String], restaurantId: String?, rating: Int?, latitude: Double?, longitude: Double?, locationName: String?, locationAddress: String?, visibility: String?, tripId: String?)
    case postDetail(id: String)
    case updatePost(id: String, content: String?, rating: Int?, visibility: String?, removeMediaIds: [String]?, addMediaIds: [String]?)
    case deletePost(id: String)

    // Comments
    case comments(postId: String, page: Int, perPage: Int)
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

    // Blocks
    case blockUser(id: String)
    case unblockUser(id: String)

    // Users
    case currentUser
    case updateProfile(displayName: String?, bio: String?, isPrivate: Bool?, avatarUrl: String?)
    case avatarPresign(contentType: String, fileSize: Int)
    case userProfile(username: String)
    case userPosts(userId: String, cursor: String?, limit: Int)

    // Restaurants
    case createRestaurant(data: [String: Any])
    case restaurantDetail(slug: String)
    case updateRestaurant(id: String, data: [String: Any])
    case nearbyRestaurants(lat: Double, lng: Double, radiusKm: Double, limit: Int)
    case restaurantMenu(id: String)
    case restaurantPosts(restaurantId: String, page: Int, perPage: Int)
    case addMenuItem(restaurantId: String, data: [String: Any])

    // Check-ins
    case createCheckIn(restaurantId: String, latitude: Double?, longitude: Double?, postId: String?)
    case recentCheckIns(cursor: String?, limit: Int)
    case restaurantCheckins(restaurantId: String, page: Int, perPage: Int)
    case userCheckins(userId: String, page: Int, perPage: Int)

    // Search
    case search(query: String?, type: String?, lat: Double?, lng: Double?)

    // Notifications
    case notifications(cursor: String?, limit: Int)
    case markNotificationRead(id: String)
    case markAllNotificationsRead
    case registerDeviceToken(token: String)
    case unreadNotificationCount

    // Media
    case presignUpload(fileName: String, contentType: String, fileSize: Int)
    case completeUpload(mediaId: String, width: Int? = nil, height: Int? = nil)
    case mediaStatus(id: String)

    // Bookmarks
    case bookmarkPost(id: String)
    case removeBookmark(id: String)
    case bookmarks(cursor: String?, limit: Int)

    // Stories (backend only supports mediaId — no caption/content/edit)
    case createStory(mediaId: String)
    case storyFeed
    case viewStory(id: String)
    case storyViewers(id: String)
    case deleteStory(id: String)

    // Conversations / DMs
    case conversations(cursor: String?, limit: Int)
    case startConversation(userId: String)
    case messages(conversationId: String, cursor: String?, limit: Int)
    case sendMessage(conversationId: String, content: String)
    case markConversationRead(conversationId: String)

    // Trips
    case createTrip(title: String, description: String?, startDate: String?, endDate: String?, visibility: String)
    case myTrips(cursor: String?, limit: Int)
    case exploreTrips(cursor: String?, limit: Int)
    case tripDetail(id: String)
    case updateTrip(id: String, title: String?, description: String?, visibility: String?, status: String?, startDate: String?, endDate: String?)
    case deleteTrip(id: String)
    case addTripStop(tripId: String, name: String, restaurantId: String?, address: String?, latitude: Double?, longitude: Double?, dayNumber: Int, sortOrder: Int, notes: String?, category: String, estimatedDuration: Int?, startTime: String?, endTime: String?)
    case updateTripStop(stopId: String, name: String?, notes: String?, dayNumber: Int?, sortOrder: Int?, startTime: String?, endTime: String?)
    case removeTripStop(stopId: String)
    case reorderTripStops(tripId: String, stopIds: [String])
    case inviteCollaborator(tripId: String, userId: String, role: String)
    case removeCollaborator(tripId: String, userId: String)
    case cloneTrip(id: String)
    case userTrips(username: String, cursor: String?, limit: Int)

    var method: HTTPMethod {
        switch self {
        case .register, .login, .socialLogin, .refreshToken, .logout,
             .createPost, .createComment, .likePost, .likeComment,
             .followUser, .followRestaurant, .blockUser, .createRestaurant,
             .createCheckIn, .addMenuItem, .registerDeviceToken,
             .presignUpload, .completeUpload,
             .bookmarkPost, .createStory, .viewStory,
             .startConversation, .sendMessage,
             .createTrip, .addTripStop, .reorderTripStops,
             .inviteCollaborator, .cloneTrip,
             .avatarPresign:
            return .post
        case .updateProfile, .updatePost, .updateComment, .updateRestaurant,
             .markNotificationRead, .markAllNotificationsRead,
             .markConversationRead,
             .updateTrip, .updateTripStop:
            return .patch
        case .deleteAccount, .deletePost, .deleteComment,
             .unlikePost, .unlikeComment, .unfollowUser, .unfollowRestaurant, .unblockUser,
             .removeBookmark, .deleteStory,
             .deleteTrip, .removeTripStop, .removeCollaborator:
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
        case .updatePost(let id, _, _, _, _, _): return "/posts/\(id)"
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
        case .blockUser(let id): return "/users/\(id)/block"
        case .unblockUser(let id): return "/users/\(id)/block"

        // Users
        case .currentUser: return "/users/me"
        case .updateProfile: return "/users/me"
        case .avatarPresign: return "/users/me/avatar/presign"
        case .userProfile(let username): return "/users/\(username)"
        case .userPosts(let userId, _, _): return "/users/\(userId)/posts"

        // Restaurants
        case .createRestaurant: return "/restaurants"
        case .restaurantDetail(let slug): return "/restaurants/\(slug)"
        case .updateRestaurant(let id, _): return "/restaurants/\(id)"
        case .nearbyRestaurants: return "/restaurants/nearby"
        case .restaurantMenu(let id): return "/restaurants/\(id)/menu"
        case .restaurantPosts(let restaurantId, _, _): return "/restaurants/\(restaurantId)/posts"
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
        case .completeUpload(let mediaId, _, _): return "/media/\(mediaId)/complete"
        case .mediaStatus(let id): return "/media/\(id)"

        // Bookmarks
        case .bookmarkPost(let id): return "/posts/\(id)/bookmark"
        case .removeBookmark(let id): return "/posts/\(id)/bookmark"
        case .bookmarks: return "/bookmarks"

        // Stories
        case .createStory: return "/stories"
        case .storyFeed: return "/stories/feed"
        case .viewStory(let id): return "/stories/\(id)/view"
        case .storyViewers(let id): return "/stories/\(id)/viewers"
        case .deleteStory(let id): return "/stories/\(id)"

        // Conversations / DMs
        case .conversations: return "/conversations"
        case .startConversation: return "/conversations"
        case .messages(let conversationId, _, _): return "/conversations/\(conversationId)/messages"
        case .sendMessage(let conversationId, _): return "/conversations/\(conversationId)/messages"
        case .markConversationRead(let conversationId): return "/conversations/\(conversationId)/read"

        // Trips
        case .createTrip: return "/trips"
        case .myTrips: return "/trips/mine"
        case .exploreTrips: return "/trips/explore"
        case .tripDetail(let id): return "/trips/\(id)"
        case .updateTrip(let id, _, _, _, _, _, _): return "/trips/\(id)"
        case .deleteTrip(let id): return "/trips/\(id)"
        case .addTripStop(let tripId, _, _, _, _, _, _, _, _, _, _, _, _): return "/trips/\(tripId)/stops"
        case .updateTripStop(let stopId, _, _, _, _, _, _): return "/trips/stops/\(stopId)"
        case .removeTripStop(let stopId): return "/trips/stops/\(stopId)"
        case .reorderTripStops(let tripId, _): return "/trips/\(tripId)/stops/reorder"
        case .inviteCollaborator(let tripId, _, _): return "/trips/\(tripId)/collaborators"
        case .removeCollaborator(let tripId, let userId): return "/trips/\(tripId)/collaborators/\(userId)"
        case .cloneTrip(let id): return "/trips/\(id)/clone"
        case .userTrips(let username, _, _): return "/users/\(username)/trips"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .feed(let cursor, let limit), .exploreFeed(let cursor, let limit),
             .recentCheckIns(let cursor, let limit), .notifications(let cursor, let limit),
             .bookmarks(let cursor, let limit), .conversations(let cursor, let limit),
             .myTrips(let cursor, let limit), .exploreTrips(let cursor, let limit):
            var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
            if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
            return items
        case .userPosts(_, let cursor, let limit),
             .messages(_, let cursor, let limit),
             .userTrips(_, let cursor, let limit):
            var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
            if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
            return items
        case .comments(_, let page, let perPage),
             .followers(_, let page, let perPage), .following(_, let page, let perPage),
             .restaurantCheckins(_, let page, let perPage), .restaurantPosts(_, let page, let perPage), .userCheckins(_, let page, let perPage):
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
            var items: [URLQueryItem] = []
            if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
            if let type { items.append(URLQueryItem(name: "type", value: type)) }
            if let lat { items.append(URLQueryItem(name: "lat", value: "\(lat)")) }
            if let lng { items.append(URLQueryItem(name: "lng", value: "\(lng)")) }
            return items.isEmpty ? nil : items
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
        case .createPost(let content, let mediaIds, let restaurantId, let rating, let lat, let lng, let locationName, let locationAddress, let visibility, let tripId):
            var body: [String: Any] = ["mediaIds": mediaIds]
            if let content { body["content"] = content }
            if let restaurantId { body["restaurantId"] = restaurantId }
            if let rating { body["rating"] = rating }
            if let lat { body["latitude"] = lat }
            if let lng { body["longitude"] = lng }
            if let locationName { body["locationName"] = locationName }
            if let locationAddress { body["locationAddress"] = locationAddress }
            if let visibility { body["visibility"] = visibility }
            if let tripId { body["tripId"] = tripId }
            return body
        case .createComment(_, let content, let parentId):
            var body: [String: Any] = ["content": content]
            if let parentId { body["parentId"] = parentId }
            return body
        case .updateComment(_, let content):
            return ["content": content]
        case .updatePost(_, let content, let rating, let visibility, let removeMediaIds, let addMediaIds):
            var body: [String: Any] = [:]
            if let content { body["content"] = content }
            if let rating { body["rating"] = rating }
            if let visibility { body["visibility"] = visibility }
            if let removeMediaIds, !removeMediaIds.isEmpty { body["removeMediaIds"] = removeMediaIds }
            if let addMediaIds, !addMediaIds.isEmpty { body["addMediaIds"] = addMediaIds }
            return body
        case .updateProfile(let displayName, let bio, let isPrivate, let avatarUrl):
            var body: [String: Any] = [:]
            if let displayName { body["displayName"] = displayName }
            if let bio { body["bio"] = bio }
            if let isPrivate { body["isPrivate"] = isPrivate }
            if let avatarUrl { body["avatarUrl"] = avatarUrl }
            return body
        case .avatarPresign(let contentType, let fileSize):
            return ["contentType": contentType, "fileSize": fileSize]
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
        case .completeUpload(_, let width, let height):
            var body: [String: Any] = [:]
            if let width { body["width"] = width }
            if let height { body["height"] = height }
            return body
        case .createRestaurant(let data), .updateRestaurant(_, let data), .addMenuItem(_, let data):
            return data
        case .createStory(let mediaId):
            // Backend only accepts mediaId — caption/content/locationName cause 400
            return ["mediaId": mediaId]
        case .startConversation(let userId):
            return ["userId": userId]
        case .sendMessage(_, let content):
            return ["content": content]
        case .createTrip(let title, let description, let startDate, let endDate, let visibility):
            var body: [String: Any] = ["title": title, "visibility": visibility]
            if let description { body["description"] = description }
            if let startDate { body["startDate"] = startDate }
            if let endDate { body["endDate"] = endDate }
            return body
        case .updateTrip(_, let title, let description, let visibility, let status, let startDate, let endDate):
            var body: [String: Any] = [:]
            if let title { body["title"] = title }
            if let description { body["description"] = description }
            if let visibility { body["visibility"] = visibility }
            if let status { body["status"] = status }
            if let startDate { body["startDate"] = startDate }
            if let endDate { body["endDate"] = endDate }
            return body
        case .addTripStop(_, let name, let restaurantId, let address, let lat, let lng, let dayNumber, let sortOrder, let notes, let category, let estimatedDuration, let startTime, let endTime):
            var body: [String: Any] = [
                "name": name,
                "dayNumber": dayNumber,
                "sortOrder": sortOrder,
                "category": category
            ]
            if let restaurantId { body["restaurantId"] = restaurantId }
            if let address { body["address"] = address }
            if let lat { body["latitude"] = lat }
            if let lng { body["longitude"] = lng }
            if let notes { body["notes"] = notes }
            if let estimatedDuration { body["estimatedDuration"] = estimatedDuration }
            if let startTime { body["startTime"] = startTime }
            if let endTime { body["endTime"] = endTime }
            return body
        case .updateTripStop(_, let name, let notes, let dayNumber, let sortOrder, let startTime, let endTime):
            var body: [String: Any] = [:]
            if let name { body["name"] = name }
            if let notes { body["notes"] = notes }
            if let dayNumber { body["dayNumber"] = dayNumber }
            if let sortOrder { body["sortOrder"] = sortOrder }
            if let startTime { body["startTime"] = startTime }
            if let endTime { body["endTime"] = endTime }
            return body
        case .reorderTripStops(_, let stopIds):
            return ["stopIds": stopIds]
        case .inviteCollaborator(_, let userId, let role):
            return ["userId": userId, "role": role]
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
