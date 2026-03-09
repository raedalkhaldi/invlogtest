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
            let (data, meta) = try await APIClient.shared.requestWrapped(
                .exploreFeed(cursor: nil, limit: 20),
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

    @MainActor
    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true
        do {
            let (data, meta) = try await APIClient.shared.requestWrapped(
                .exploreFeed(cursor: cursor, limit: 20),
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

    @MainActor
    func refresh() async {
        cursor = nil
        hasMore = true
        await loadFeed()
    }
}
