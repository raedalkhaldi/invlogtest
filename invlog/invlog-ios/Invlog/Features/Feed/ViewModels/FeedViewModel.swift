import Foundation
import Combine

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
            let (data, meta) = try await apiClient.requestWrapped(
                .feed(cursor: nil, limit: 20),
                responseType: [Post].self
            )
            posts = data
            cursor = meta?.cursor
            hasMore = meta?.hasMore ?? false
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true

        do {
            let (data, meta) = try await apiClient.requestWrapped(
                .feed(cursor: cursor, limit: 20),
                responseType: [Post].self
            )
            posts.append(contentsOf: data)
            self.cursor = meta?.cursor
            hasMore = meta?.hasMore ?? false
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
