import SwiftUI

struct ExploreFeedView: View {
    @StateObject private var viewModel = ExploreFeedViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.posts.isEmpty {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "Nothing to explore yet",
                    description: "Check back later for new posts from the community."
                )
            } else {
                List {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(value: post) {
                            PostCardView(post: post)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
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
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.loadFeed()
            }
        }
    }
}
