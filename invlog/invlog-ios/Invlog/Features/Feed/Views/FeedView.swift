import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView("Loading feed...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.posts.isEmpty {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Something went wrong",
                    description: error,
                    buttonTitle: "Try Again",
                    buttonAction: {
                        Task { await viewModel.refresh() }
                    }
                )
            } else if viewModel.posts.isEmpty {
                EmptyStateView(
                    systemImage: "fork.knife",
                    title: "No posts yet",
                    description: "Follow people and restaurants to see their posts here"
                )
            } else {
                List {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(value: post) {
                            PostCardView(post: post)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .onAppear {
                            if post.id == viewModel.posts.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .navigationTitle("Feed")
        .navigationDestination(for: Post.self) { post in
            PostDetailView(postId: post.id)
        }
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.loadFeed()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCreatePost)) { _ in
            Task { await viewModel.refresh() }
        }
    }
}
