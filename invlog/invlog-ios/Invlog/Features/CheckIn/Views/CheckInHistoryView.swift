import SwiftUI
import NukeUI

struct CheckInHistoryView: View {
    let mode: Mode
    let id: String

    @State private var checkIns: [CheckIn] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMorePages = true

    enum Mode: String {
        case restaurant = "Restaurant Check-ins"
        case user = "Check-ins"
    }

    var body: some View {
        Group {
            if isLoading && checkIns.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if checkIns.isEmpty {
                EmptyStateView(
                    systemImage: "mappin.slash",
                    title: "No check-ins yet",
                    description: mode == .restaurant
                        ? "No one has checked in here yet. Be the first!"
                        : "No check-ins recorded yet."
                )
            } else {
                List {
                    ForEach(checkIns) { checkIn in
                        if let restaurant = checkIn.restaurant {
                            NavigationLink(value: restaurant) {
                                CheckInRow(checkIn: checkIn)
                            }
                            .frame(minHeight: 44)
                        } else {
                            CheckInRow(checkIn: checkIn)
                                .frame(minHeight: 44)
                        }
                    }
                    .onAppear {
                        if let last = checkIns.last, last.id == checkIns.last?.id, hasMorePages {
                            Task { await loadMore() }
                        }
                    }

                    if hasMorePages && !checkIns.isEmpty {
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
                    currentPage = 1
                    hasMorePages = true
                    await loadCheckIns()
                }
            }
        }
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .task {
            await loadCheckIns()
        }
    }

    private func loadCheckIns() async {
        isLoading = true
        do {
            let endpoint: APIEndpoint = mode == .restaurant
                ? .restaurantCheckins(restaurantId: id, page: 1, perPage: 20)
                : .userCheckins(userId: id, page: 1, perPage: 20)
            let (data, _) = try await APIClient.shared.requestWrapped(
                endpoint,
                responseType: [CheckIn].self
            )
            checkIns = data
            hasMorePages = data.count >= 20
        } catch {
            // silent fail for now
        }
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        do {
            let endpoint: APIEndpoint = mode == .restaurant
                ? .restaurantCheckins(restaurantId: id, page: currentPage, perPage: 20)
                : .userCheckins(userId: id, page: currentPage, perPage: 20)
            let (data, _) = try await APIClient.shared.requestWrapped(
                endpoint,
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
            // Restaurant or User avatar
            if let restaurant = checkIn.restaurant {
                LazyImage(url: restaurant.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "building.2")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            } else if let user = checkIn.user {
                LazyImage(url: user.avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .accessibilityHidden(true)
            } else {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let restaurant = checkIn.restaurant {
                    Text(restaurant.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                if let user = checkIn.user {
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(checkIn.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "mappin")
                .font(.caption)
                .foregroundColor(.secondary)
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
