import SwiftUI
import MapKit
@preconcurrency import NukeUI

struct CheckInHistoryDestination: Hashable {
    let restaurantId: String
}

@MainActor
struct RestaurantDetailView: View {
    let restaurantSlug: String
    @State private var restaurant: Restaurant?
    @State private var posts: [Post] = []
    @State private var recentCheckIns: [CheckIn] = []
    @State private var isLoading = true
    @State private var restaurantMedia: [PostMedia] = []
    @State private var isFollowing = false
    @State private var showCheckIn = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Color.brandSecondary)
                    Text("Could not load place")
                        .font(InvlogTheme.heading(18, weight: .bold))
                        .foregroundColor(Color.brandText)
                    Text(error)
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        self.error = nil
                        isLoading = true
                        Task { await loadRestaurant() }
                    } label: {
                        Text("Try Again")
                            .font(InvlogTheme.body(14, weight: .bold))
                            .frame(width: 140, height: 44)
                            .background(Color.brandPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let restaurant {
                restaurantContent(restaurant)
            }
        }
        .invlogScreenBackground()
        .navigationTitle(restaurant?.name ?? "Place")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CheckInHistoryDestination.self) { dest in
            CheckInHistoryView(mode: .restaurant, id: dest.restaurantId)
        }
        .sheet(isPresented: $showCheckIn, onDismiss: {
            Task { await loadRestaurant() }
        }) {
            if let restaurant {
                NavigationStack {
                    CreatePostView(preselectedRestaurant: restaurant)
                }
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
            LazyVStack(alignment: .leading, spacing: 16) {
                LazyImage(url: restaurant.coverUrl ?? restaurantMedia.first.flatMap { URL(string: $0.mediumUrl ?? $0.url) }) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else if state.isLoading {
                        ShimmerView()
                    } else {
                        ZStack {
                            Rectangle().fill(Color.brandBorder)
                            VStack(spacing: 8) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.brandTextTertiary)
                                Text(restaurant.name)
                                    .font(InvlogTheme.body(14, weight: .semibold))
                                    .foregroundColor(Color.brandTextSecondary)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .clipped()
                .accessibilityLabel("\(restaurant.name) cover photo")

                VStack(alignment: .leading, spacing: 12) {
                    nameAndRatingSection(restaurant)
                    statsSection(restaurant)
                    followButton
                    checkInButton
                    addressSection(restaurant)
                    contactSection(restaurant)

                    Rectangle().fill(Color.brandBorder).frame(height: 0.5)

                    mapSection(restaurant)

                    Group {
                        menuSection(restaurant)
                        checkInsSection(restaurant)
                        photoGallerySection
                        postsSection
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Name & Rating

    @ViewBuilder
    private func nameAndRatingSection(_ restaurant: Restaurant) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(restaurant.name)
                        .font(InvlogTheme.heading(22, weight: .bold))
                        .foregroundColor(Color.brandText)
                    if restaurant.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                    }
                }

                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                    Text(cuisines.joined(separator: " · "))
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
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
                        .foregroundColor(Color.brandSecondary)
                    Text(String(format: "%.1f", restaurant.avgRating))
                        .font(InvlogTheme.heading(16, weight: .bold))
                        .foregroundColor(Color.brandText)
                }
                Text("\(restaurant.reviewCount) reviews")
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextSecondary)
            }
            .accessibilityLabel("\(String(format: "%.1f", restaurant.avgRating)) stars, \(restaurant.reviewCount) reviews")
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private func statsSection(_ restaurant: Restaurant) -> some View {
        HStack(spacing: 24) {
            Label("\(restaurant.followerCount)", systemImage: "person.2")
                .font(InvlogTheme.body(14))
                .accessibilityLabel("\(restaurant.followerCount) followers")
            Label("\(restaurant.checkinCount)", systemImage: "mappin")
                .font(InvlogTheme.body(14))
                .accessibilityLabel("\(restaurant.checkinCount) check-ins")
            if let priceRange = restaurant.priceRange {
                Text(String(repeating: "$", count: priceRange))
                    .font(InvlogTheme.body(14, weight: .bold))
                    .accessibilityLabel("Price range \(priceRange) out of 4")
            }
        }
        .foregroundColor(Color.brandTextSecondary)
    }

    // MARK: - Buttons

    @ViewBuilder
    private var checkInButton: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                Text("Check In & Review")
                    .font(InvlogTheme.body(14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.brandPrimary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
        }
        .accessibilityLabel("Check in and review this place")
    }

    @ViewBuilder
    private var followButton: some View {
        Button { toggleFollow() } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(InvlogTheme.body(14, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isFollowing ? Color.brandCard : Color.brandText)
                .foregroundColor(isFollowing ? Color.brandText : .white)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                        .stroke(isFollowing ? Color.brandBorder : Color.clear, lineWidth: 1)
                )
        }
        .accessibilityLabel(isFollowing ? "Unfollow place" : "Follow place")
    }

    // MARK: - Address

    @ViewBuilder
    private func addressSection(_ restaurant: Restaurant) -> some View {
        if let address = restaurant.addressLine1 {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(Color.brandPrimary)
                Text(address)
                    .font(InvlogTheme.body(14))
                    .foregroundColor(Color.brandText)
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
        .font(InvlogTheme.body(14))
        .foregroundColor(Color.brandPrimary)
    }

    // MARK: - Menu

    @ViewBuilder
    private func menuSection(_ restaurant: Restaurant) -> some View {
        if let menuItems = restaurant.menuItems, !menuItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu")
                    .font(InvlogTheme.heading(16, weight: .bold))
                    .foregroundColor(Color.brandText)

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
            Rectangle().fill(Color.brandBorder).frame(height: 0.5)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent Check-ins")
                        .font(InvlogTheme.heading(16, weight: .bold))
                        .foregroundColor(Color.brandText)
                    Spacer()
                    NavigationLink(value: CheckInHistoryDestination(restaurantId: restaurant.id)) {
                        Text("See All")
                            .font(InvlogTheme.caption(12, weight: .semibold))
                            .foregroundColor(Color.brandPrimary)
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

    // MARK: - Map

    @ViewBuilder
    private func mapSection(_ restaurant: Restaurant) -> some View {
        if let lat = restaurant.latitude, let lng = restaurant.longitude {
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(InvlogTheme.heading(16, weight: .bold))
                    .foregroundColor(Color.brandText)

                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )), annotationItems: [RestaurantMapPin(id: restaurant.id, lat: lat, lng: lng, name: restaurant.name)]) { pin in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lng)) {
                        VStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(Color.brandPrimary)
                            Text(pin.name)
                                .font(InvlogTheme.caption(10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandCard)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.1), radius: 2)
                        }
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Photo Gallery

    @ViewBuilder
    private var photoGallerySection: some View {
        if !restaurantMedia.isEmpty {
            Rectangle().fill(Color.brandBorder).frame(height: 0.5)

            VStack(alignment: .leading, spacing: 8) {
                Text("Photos")
                    .font(InvlogTheme.heading(16, weight: .bold))
                    .foregroundColor(Color.brandText)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 4) {
                        ForEach(restaurantMedia.prefix(12)) { media in
                            LazyImage(url: URL(string: media.thumbnailUrl ?? media.mediumUrl ?? media.url)) { state in
                                if let image = state.image {
                                    image.resizable().scaledToFill()
                                } else if state.isLoading {
                                    ShimmerView()
                                } else {
                                    Rectangle().fill(Color.brandBorder)
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Posts

    @ViewBuilder
    private var postsSection: some View {
        if !posts.isEmpty {
            Rectangle().fill(Color.brandBorder).frame(height: 0.5)

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Posts")
                    .font(InvlogTheme.heading(16, weight: .bold))
                    .foregroundColor(Color.brandText)

                ForEach(posts) { post in
                    PostCardView(post: post)
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

            let (checkInData, _) = try await APIClient.shared.requestWrapped(
                .restaurantCheckins(restaurantId: data.id, page: 1, perPage: 5),
                responseType: [CheckIn].self
            )
            recentCheckIns = checkInData

            // Fetch restaurant posts
            if let (postsResponse, _) = try? await APIClient.shared.requestWrapped(
                .restaurantPosts(restaurantId: data.id, page: 1, perPage: 10),
                responseType: RestaurantPostsResponse.self
            ) {
                posts = postsResponse.data
                restaurantMedia = postsResponse.data.flatMap { $0.media ?? [] }
            }
        } catch {
            self.error = error.localizedDescription
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

private struct RestaurantMapPin: Identifiable {
    let id: String
    let lat: Double
    let lng: Double
    let name: String
}

struct RestaurantPostsResponse: Codable {
    let data: [Post]
    let total: Int
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
                .font(InvlogTheme.body(14, weight: .bold))
                .foregroundColor(Color.brandText)
            if let description = item.description {
                Text(description)
                    .font(InvlogTheme.caption(12))
                    .foregroundColor(Color.brandTextSecondary)
                    .lineLimit(2)
            }
            if let tags = item.dietaryTags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(InvlogTheme.caption(10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandTealLight)
                            .foregroundColor(Color.brandAccent)
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
                .font(InvlogTheme.body(14, weight: .bold))
                .foregroundColor(Color.brandText)
        }
    }
}
