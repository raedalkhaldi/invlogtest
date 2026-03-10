import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.posts.isEmpty {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Something went wrong",
                    description: error,
                    buttonTitle: "Retry",
                    buttonAction: { Task { await viewModel.loadBookmarks() } }
                )
            } else if viewModel.posts.isEmpty {
                EmptyStateView(
                    systemImage: "bookmark",
                    title: "No Saved Posts",
                    description: "Posts you bookmark will appear here."
                )
            } else {
                List {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(value: post) {
                            PostCardView(post: post)
                        }
                        .onAppear {
                            if post.id == viewModel.posts.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Post.self) { post in
            PostDetailView(postId: post.id)
        }
        .task {
            await viewModel.loadBookmarks()
        }
        .refreshable {
            await viewModel.loadBookmarks()
        }
    }
}
