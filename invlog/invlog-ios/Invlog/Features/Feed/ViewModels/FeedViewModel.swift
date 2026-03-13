import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var hasMore = true
    private var cursor: String?
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let (feedResponse, _) = try await apiClient.requestWrapped(
                .feed(cursor: nil, limit: 20),
                responseType: FeedResponse.self
            )
            posts = feedResponse.data
            cursor = feedResponse.nextCursor
            hasMore = feedResponse.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true

        do {
            let (feedResponse, _) = try await apiClient.requestWrapped(
                .feed(cursor: cursor, limit: 20),
                responseType: FeedResponse.self
            )
            posts.append(contentsOf: feedResponse.data)
            self.cursor = feedResponse.nextCursor
            hasMore = feedResponse.nextCursor != nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }

    func refresh() async {
        cursor = nil
        hasMore = true
        await loadFeed()
    }
}
