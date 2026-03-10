import SwiftUI
import Nuke
import NukeUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var storiesViewModel = StoriesViewModel()
    private let prefetcher = ImagePrefetcher()

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
                    // Stories bar
                    if !storiesViewModel.storyGroups.isEmpty {
                        Section {
                            StoriesBarView(storyGroups: storiesViewModel.storyGroups)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }

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
                            // Prefetch next 5 posts' media images
                            if let currentIndex = viewModel.posts.firstIndex(where: { $0.id == post.id }) {
                                let nextPosts = viewModel.posts.suffix(from: min(currentIndex + 1, viewModel.posts.endIndex)).prefix(5)
                                let urls = nextPosts.compactMap { p -> URL? in
                                    guard let media = p.media?.first else { return nil }
                                    return URL(string: media.mediumUrl ?? media.url)
                                }
                                prefetcher.startPrefetching(with: urls)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ConversationsListView()) {
                    Image(systemName: "paperplane")
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Messages")
            }
        }
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
            await storiesViewModel.loadStories()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCreatePost)) { _ in
            Task { await viewModel.refresh() }
        }
    }
}
