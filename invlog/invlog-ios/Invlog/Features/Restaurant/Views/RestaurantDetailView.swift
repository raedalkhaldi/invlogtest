import SwiftUI
import MapKit
import NukeUI

struct CheckInHistoryDestination: Hashable {
    let restaurantId: String
}

struct RestaurantDetailView: View {
    let restaurantSlug: String
    @State private var restaurant: Restaurant?
    @State private var posts: [Post] = []
    @State private var recentCheckIns: [CheckIn] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var showCheckIn = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let restaurant {
                restaurantContent(restaurant)
            }
        }
        .navigationTitle(restaurant?.name ?? "Restaurant")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CheckInHistoryDestination.self) { dest in
            CheckInHistoryView(mode: .restaurant, id: dest.restaurantId)
        }
        .sheet(isPresented: $showCheckIn) {
            if let restaurant {
                CheckInView(restaurant: restaurant)
            }
        }
        .task {
            await loadRestaurant()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func restaurantContent(_ restaurant: Restaurant) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                coverImageSection(restaurant)

                VStack(alignment: .leading, spacing: 12) {
                    nameAndRatingSection(restaurant)
                    statsSection(restaurant)
                    followButton
                    checkInButton
                    addressSection(restaurant)
                    contactSection(restaurant)

                    Divider()

                    Group {
                        menuSection(restaurant)
                        checkInsSection(restaurant)
                        Divider()
                        postsSection
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Cover Image

    @ViewBuilder
    private func coverImageSection(_ restaurant: Restaurant) -> some View {
        LazyImage(url: restaurant.coverUrl) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
        }
        .frame(height: 200)
        .clipped()
        .accessibilityLabel("\(restaurant.name) cover photo")
    }

    // MARK: - Name & Rating

    @ViewBuilder
    private func nameAndRatingSection(_ restaurant: Restaurant) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(restaurant.name)
                        .font(.title2.bold())
                    if restaurant.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                    }
                }

                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                    Text(cuisines.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            ratingView(restaurant)
        }
    }

    @ViewBuilder
    private func ratingView(_ restaurant: Restaurant) -> some View {
        if restaurant.avgRating > 0 {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", restaurant.avgRating))
                        .font(.headline)
                }
                Text("\(restaurant.reviewCount) reviews")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("\(String(format: "%.1f", restaurant.avgRating)) stars, \(restaurant.reviewCount) reviews")
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private func statsSection(_ restaurant: Restaurant) -> some View {
        HStack(spacing: 24) {
            Label("\(restaurant.followerCount)", systemImage: "person.2")
                .font(.subheadline)
                .accessibilityLabel("\(restaurant.followerCount) followers")
            Label("\(restaurant.checkinCount)", systemImage: "mappin")
                .font(.subheadline)
                .accessibilityLabel("\(restaurant.checkinCount) check-ins")
            if let priceRange = restaurant.priceRange {
                Text(String(repeating: "$", count: priceRange))
                    .font(.subheadline.bold())
                    .accessibilityLabel("Price range \(priceRange) out of 4")
            }
        }
        .foregroundColor(.secondary)
    }

    // MARK: - Buttons

    @ViewBuilder
    private var checkInButton: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                Text("Check In")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Check in at this restaurant")
    }

    @ViewBuilder
    private var followButton: some View {
        let label = Text(isFollowing ? "Following" : "Follow")
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        let accessLabel = isFollowing ? "Unfollow restaurant" : "Follow restaurant"

        if isFollowing {
            Button { toggleFollow() } label: { label }
                .buttonStyle(.bordered)
                .accessibilityLabel(accessLabel)
        } else {
            Button { toggleFollow() } label: { label }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(accessLabel)
        }
    }

    // MARK: - Address

    @ViewBuilder
    private func addressSection(_ restaurant: Restaurant) -> some View {
        if let address = restaurant.addressLine1 {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.secondary)
                Text(address)
                    .font(.subheadline)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - Contact

    @ViewBuilder
    private func contactSection(_ restaurant: Restaurant) -> some View {
        HStack(spacing: 16) {
            if let phone = restaurant.phone {
                Link(destination: URL(string: "tel:\(phone)")!) {
                    Label("Call", systemImage: "phone")
                }
                .frame(minHeight: 44)
            }
            if let website = restaurant.website {
                Link(destination: URL(string: website)!) {
                    Label("Website", systemImage: "globe")
                }
                .frame(minHeight: 44)
            }
        }
        .font(.subheadline)
    }

    // MARK: - Menu

    @ViewBuilder
    private func menuSection(_ restaurant: Restaurant) -> some View {
        if let menuItems = restaurant.menuItems, !menuItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu")
                    .font(.headline)

                ForEach(menuItems) { item in
                    MenuItemRow(item: item)
                }
            }
        }
    }

    // MARK: - Check-Ins

    @ViewBuilder
    private func checkInsSection(_ restaurant: Restaurant) -> some View {
        if !recentCheckIns.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent Check-ins")
                        .font(.headline)
                    Spacer()
                    NavigationLink(value: CheckInHistoryDestination(restaurantId: restaurant.id)) {
                        Text("See All")
                            .font(.caption)
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("See all check-ins")
                }

                ForEach(recentCheckIns.prefix(5)) { checkIn in
                    CheckInRow(checkIn: checkIn)
                }
            }
        }
    }

    // MARK: - Posts

    @ViewBuilder
    private var postsSection: some View {
        if !posts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Posts")
                    .font(.headline)

                ForEach(posts) { post in
                    PostCardView(post: post)
                    Divider()
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadRestaurant() async {
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .restaurantDetail(slug: restaurantSlug),
                responseType: Restaurant.self
            )
            restaurant = data
            isFollowing = data.isFollowedByMe ?? false

            // Load recent check-ins
            let (checkInData, _) = try await APIClient.shared.requestWrapped(
                .restaurantCheckins(restaurantId: data.id, page: 1, perPage: 5),
                responseType: [CheckIn].self
            )
            recentCheckIns = checkInData
        } catch {
            // Handle error
        }
        isLoading = false
    }

    private func toggleFollow() {
        guard let restaurant else { return }
        isFollowing.toggle()
        Task {
            do {
                if isFollowing {
                    try await APIClient.shared.requestVoid(.followRestaurant(id: restaurant.id))
                } else {
                    try await APIClient.shared.requestVoid(.unfollowRestaurant(id: restaurant.id))
                }
            } catch {
                isFollowing.toggle()
            }
        }
    }
}

struct MenuItemRow: View {
    let item: MenuItemModel

    var body: some View {
        HStack {
            menuItemContent
            Spacer()
            menuItemPrice
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var menuItemContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.subheadline.bold())
            if let description = item.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if let tags = item.dietaryTags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var menuItemPrice: some View {
        if let price = item.price {
            Text(String(format: "%@ %.2f", item.currency, price))
                .font(.subheadline.bold())
        }
    }
}
