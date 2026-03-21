import SwiftUI
import Nuke
@preconcurrency import NukeUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var storiesViewModel = StoriesViewModel()
    @ObservedObject private var storyUploader = StoryUploadManager.shared
    @EnvironmentObject private var appState: AppState
    private let prefetcher = ImagePrefetcher()
    @State private var showFilterSheet = false
    @State private var activeFilters = FeedFilters()

    private var filteredPosts: [Post] {
        activeFilters.apply(to: viewModel.posts)
    }

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

                    // Vlog upload progress bar
                    if storyUploader.isActive || storyUploader.status == .completed {
                        Section {
                            StoryUploadProgressBar(status: storyUploader.status)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    ForEach(filteredPosts) { post in
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showFilterSheet = true } label: {
                    Image(systemName: activeFilters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundColor(activeFilters.isActive ? Color.brandPrimary : Color.brandText)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Filter feed")
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
        .sheet(isPresented: $showFilterSheet) {
            FeedFilterSheet(filters: $activeFilters)
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

// MARK: - Story Upload Progress Bar

private struct StoryUploadProgressBar: View {
    let status: StoryUploadManager.UploadStatus

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)

            Text(statusText)
                .font(InvlogTheme.caption(13, weight: .medium))
                .foregroundColor(Color.brandText)

            Spacer()

            if case .uploading = status {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.brandCard)
        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 1)
                    .fill(progressColor)
                    .frame(width: geo.size.width * progressValue, height: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .animation(.easeInOut(duration: 0.3), value: progressValue)
            }
            .frame(height: 2)
            .clipShape(RoundedRectangle(cornerRadius: 1))
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
        default:
            Image(systemName: "arrow.up.circle.fill")
        }
    }

    private var statusText: String {
        switch status {
        case .uploading: return "Uploading vlog..."
        case .processing: return "Processing..."
        case .completed: return "Vlog shared!"
        case .failed(let msg): return "Failed: \(msg)"
        default: return ""
        }
    }

    private var iconColor: Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        default: return Color.brandPrimary
        }
    }

    private var progressColor: Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        default: return Color.brandPrimary
        }
    }

    private var progressValue: Double {
        switch status {
        case .uploading(let p): return max(0.05, p)
        case .processing: return 0.9
        case .completed: return 1.0
        default: return 0
        }
    }
}
