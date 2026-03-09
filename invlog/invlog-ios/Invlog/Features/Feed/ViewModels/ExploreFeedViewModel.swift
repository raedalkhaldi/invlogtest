import Foundation
import Combine

final class ExploreFeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var hasMore = true

    private var cursor: String?

    @MainActor
    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        do {
            let (feedResponse, _) = try await APIClient.shared.requestWrapped(
                .exploreFeed(cursor: nil, limit: 20),
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

    @MainActor
    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true
        do {
            let (feedResponse, _) = try await APIClient.shared.requestWrapped(
                .exploreFeed(cursor: cursor, limit: 20),
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

    @MainActor
    func refresh() async {
        cursor = nil
        hasMore = true
        await loadFeed()
    }
}
