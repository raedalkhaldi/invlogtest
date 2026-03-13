import SwiftUI
import Nuke
@preconcurrency import NukeUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var storiesViewModel = StoriesViewModel()
    @EnvironmentObject private var appState: AppState
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
                    description: "Follow people and places to see their posts here"
                )
            } else {
                List {
                    // Stories bar
                    Section {
                        StoriesBarView(
                            storyGroups: storiesViewModel.storyGroups,
                            currentUser: appState.currentUser,
                            storiesViewModel: storiesViewModel
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(viewModel.posts) { post in
                        PostCardView(post: post)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .onAppear {
                            if post.id == viewModel.posts.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                            if let currentIndex = viewModel.posts.firstIndex(where: { $0.id == post.id }) {
                                let nextPosts = viewModel.posts.suffix(from: min(currentIndex + 1, viewModel.posts.endIndex)).prefix(5)
                                let urls = nextPosts.compactMap { p -> URL? in
                                    guard let media = p.media?.first else { return nil }
                                    return URL(string: media.thumbnailUrl ?? media.mediumUrl ?? media.url)
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
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .invlogScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("invlog")
                    .font(InvlogTheme.heading(22, weight: .bold))
                    .foregroundColor(Color.brandText)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ConversationsListView()) {
                    Image(systemName: "paperplane")
                        .foregroundColor(Color.brandText)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Messages")
            }
        }
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .task(id: appState.currentUser?.id) {
            guard appState.currentUser != nil else { return }
            if viewModel.posts.isEmpty {
                await viewModel.loadFeed()
            }
            await storiesViewModel.loadStories()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCreatePost)) { _ in
            Task { await viewModel.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCreateStory)) { _ in
            Task { await storiesViewModel.loadStories() }
        }
    }
}
