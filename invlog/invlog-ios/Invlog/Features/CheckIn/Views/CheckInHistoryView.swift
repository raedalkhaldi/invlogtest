import SwiftUI
@preconcurrency import NukeUI

struct CheckInHistoryView: View {
    let mode: Mode
    let id: String

    @State private var checkIns: [CheckIn] = []
    @State private var posts: [Post] = []
    @State private var nextCursor: String?

    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMorePages = true

    enum Mode: String {
        case restaurant = "Place Check-ins"
        case user = "Check-ins"
    }

    var body: some View {
        Group {
            if isLoading && posts.isEmpty && checkIns.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mode == .user && posts.isEmpty {
                EmptyStateView(
                    systemImage: "mappin.slash",
                    title: "No check-ins yet",
                    description: "No check-ins recorded yet."
                )
            } else if mode == .restaurant && checkIns.isEmpty {
                EmptyStateView(
                    systemImage: "mappin.slash",
                    title: "No check-ins yet",
                    description: "No one has checked in here yet. Be the first!"
                )
            } else if mode == .user {
                userPostsList
            } else {
                restaurantCheckInsList
            }
        }
        .invlogScreenBackground()
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .navigationDestination(for: Post.self) { post in
            PostDetailView(postId: post.id)
        }
        .task {
            if mode == .user {
                await loadUserPosts()
            } else {
                await loadCheckIns()
            }
        }
    }

    // MARK: - User Mode (Full Post Cards)

    private var userPostsList: some View {
        List {
            ForEach(posts) { post in
                NavigationLink(value: post) {
                    PostCardView(post: post)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .onAppear {
                    if post.id == posts.last?.id && nextCursor != nil {
                        Task { await loadMorePosts() }
                    }
                }
            }

            if nextCursor != nil {
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
            nextCursor = nil
            await loadUserPosts()
        }
    }

    // MARK: - Restaurant Mode (Check-in Rows)

    private var restaurantCheckInsList: some View {
        List {
            ForEach(checkIns) { checkIn in
                if let restaurant = checkIn.restaurant {
                    NavigationLink(value: restaurant) {
                        CheckInRow(checkIn: checkIn)
                    }
                    .frame(minHeight: 44)
                    .listRowBackground(Color.clear)
                } else {
                    CheckInRow(checkIn: checkIn)
                        .frame(minHeight: 44)
                        .listRowBackground(Color.clear)
                }
            }
            .onAppear {
                if let last = checkIns.last, last.id == checkIns.last?.id, hasMorePages {
                    Task { await loadMoreCheckIns() }
                }
            }

            if hasMorePages && !checkIns.isEmpty {
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
            currentPage = 1
            hasMorePages = true
            await loadCheckIns()
        }
    }

    // MARK: - Data Loading (User Posts)

    private func loadUserPosts() async {
        isLoading = true
        do {
            let (feedResponse, _) = try await APIClient.shared.requestWrapped(
                .userPosts(userId: id, cursor: nil, limit: 20),
                responseType: FeedResponse.self
            )
            posts = feedResponse.data
            nextCursor = feedResponse.nextCursor
        } catch {
            // silent fail for now
        }
        isLoading = false
    }

    private func loadMorePosts() async {
        guard let cursor = nextCursor else { return }
        do {
            let (feedResponse, _) = try await APIClient.shared.requestWrapped(
                .userPosts(userId: id, cursor: cursor, limit: 20),
                responseType: FeedResponse.self
            )
            posts.append(contentsOf: feedResponse.data)
            nextCursor = feedResponse.nextCursor
        } catch {
            // silent fail
        }
    }

    // MARK: - Data Loading (Restaurant Check-ins)

    private func loadCheckIns() async {
        isLoading = true
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .restaurantCheckins(restaurantId: id, page: 1, perPage: 20),
                responseType: [CheckIn].self
            )
            checkIns = data
            hasMorePages = data.count >= 20
        } catch {
            // silent fail for now
        }
        isLoading = false
    }

    private func loadMoreCheckIns() async {
        currentPage += 1
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .restaurantCheckins(restaurantId: id, page: currentPage, perPage: 20),
                responseType: [CheckIn].self
            )
            checkIns.append(contentsOf: data)
            hasMorePages = data.count >= 20
        } catch {
            currentPage -= 1
        }
    }
}

// MARK: - Check-In Row

struct CheckInRow: View {
    let checkIn: CheckIn

    var body: some View {
        HStack(spacing: 12) {
            if let restaurant = checkIn.restaurant {
                LazyImage(url: restaurant.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "building.2")
                            .foregroundColor(Color.brandTextTertiary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                .accessibilityHidden(true)
            } else if let user = checkIn.user {
                LazyImage(url: user.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(Color.brandTextTertiary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .accessibilityHidden(true)
            } else {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.brandPrimary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let restaurant = checkIn.restaurant {
                    Text(restaurant.name)
                        .font(InvlogTheme.body(14, weight: .bold))
                        .foregroundColor(Color.brandText)
                        .lineLimit(1)
                }
                if let user = checkIn.user {
                    Text("@\(user.username)")
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(Color.brandTextSecondary)
                        .lineLimit(1)
                }
                Text(checkIn.createdAt, style: .relative)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextTertiary)
            }

            Spacer()

            Image(systemName: "mappin")
                .font(.caption)
                .foregroundColor(Color.brandPrimary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let restaurant = checkIn.restaurant {
            parts.append("Check-in at \(restaurant.name)")
        }
        if let user = checkIn.user {
            parts.append("by \(user.displayName ?? user.username)")
        }
        return parts.joined(separator: " ")
    }
}
