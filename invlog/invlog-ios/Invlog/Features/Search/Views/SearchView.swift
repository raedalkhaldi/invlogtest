import SwiftUI
@preconcurrency import NukeUI

struct NearbyRestaurantsDestination: Hashable {}
struct ExploreTripsDestination: Hashable {}

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var results: SearchResults = .empty
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @StateObject private var locationManager = LocationManager()
    @State private var nearbyRestaurants: [Restaurant] = []
    @State private var isLoadingNearby = false
    @State private var exploreTrips: [Trip] = []
    @State private var isLoadingTrips = false

    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case restaurants = "Restaurants"
        case users = "People"
        case posts = "Posts"

        var displayName: String {
            switch self {
            case .all: return "All"
            case .restaurants: return "Places"
            case .users: return "People"
            case .posts: return "Posts"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                            triggerSearch()
                        } label: {
                            Text(filter.displayName)
                                .font(InvlogTheme.caption(13, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedFilter == filter ? Color.brandText : Color.brandCard)
                                .foregroundColor(selectedFilter == filter ? .white : Color.brandText)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedFilter == filter ? Color.clear : Color.brandBorder, lineWidth: 1)
                                )
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("\(filter.displayName) filter")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if searchText.isEmpty && selectedFilter == .all {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Quick Actions
                        HStack(spacing: 12) {
                            NavigationLink(value: NearbyRestaurantsDestination()) {
                                HStack(spacing: 8) {
                                    Image(systemName: "map")
                                        .font(.title3)
                                        .foregroundColor(Color.brandPrimary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Nearby")
                                            .font(InvlogTheme.body(14, weight: .bold))
                                            .foregroundColor(Color.brandText)
                                        Text("Map & Places")
                                            .font(InvlogTheme.caption(11))
                                            .foregroundColor(Color.brandTextSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(InvlogTheme.Spacing.sm)
                                .background(Color.brandCard)
                                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius)
                                        .stroke(Color.brandBorder, lineWidth: 1)
                                )
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel("View nearby places on map")

                            NavigationLink(value: ExploreTripsDestination()) {
                                HStack(spacing: 8) {
                                    Image(systemName: "suitcase.fill")
                                        .font(.title3)
                                        .foregroundColor(Color.brandAccent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Trips")
                                            .font(InvlogTheme.body(14, weight: .bold))
                                            .foregroundColor(Color.brandText)
                                        Text("Food Itineraries")
                                            .font(InvlogTheme.caption(11))
                                            .foregroundColor(Color.brandTextSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(InvlogTheme.Spacing.sm)
                                .background(Color.brandCard)
                                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius)
                                        .stroke(Color.brandBorder, lineWidth: 1)
                                )
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel("Browse food trip itineraries")
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Nearby Places — categorized
                        if !nearbyRestaurants.isEmpty {
                            // All nearby
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Nearby Places")
                                        .font(InvlogTheme.heading(16, weight: .bold))
                                        .foregroundColor(Color.brandText)
                                        .padding(.horizontal)

                                    Spacer()

                                    NavigationLink(value: NearbyRestaurantsDestination()) {
                                        Text("See All")
                                            .font(InvlogTheme.caption(12, weight: .semibold))
                                            .foregroundColor(Color.brandPrimary)
                                            .padding(.horizontal)
                                    }
                                    .frame(minHeight: 44)
                                    .accessibilityLabel("See all nearby places")
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(nearbyRestaurants.prefix(8)) { restaurant in
                                            NavigationLink(value: restaurant) {
                                                NearbyRestaurantCard(restaurant: restaurant)
                                            }
                                            .frame(minWidth: 44, minHeight: 44)
                                            .accessibilityLabel("\(restaurant.name)")
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)

                            // Categorized sections
                            ForEach(categorizedPlaces, id: \.category) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: group.icon)
                                            .font(.caption)
                                            .foregroundColor(Color.brandPrimary)
                                        Text(group.category)
                                            .font(InvlogTheme.heading(14, weight: .bold))
                                            .foregroundColor(Color.brandText)
                                    }
                                    .padding(.horizontal)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(group.restaurants) { restaurant in
                                                NavigationLink(value: restaurant) {
                                                    NearbyRestaurantCard(restaurant: restaurant)
                                                }
                                                .frame(minWidth: 44, minHeight: 44)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } else if isLoadingNearby {
                            HStack {
                                Spacer()
                                ProgressView("Finding nearby places...")
                                    .font(InvlogTheme.caption(12))
                                Spacer()
                            }
                            .padding()
                        }

                        // Public Trips Section
                        if !exploreTrips.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Food Trips")
                                        .font(InvlogTheme.heading(16, weight: .bold))
                                        .foregroundColor(Color.brandText)
                                        .padding(.horizontal)

                                    Spacer()

                                    NavigationLink(value: ExploreTripsDestination()) {
                                        Text("See All")
                                            .font(InvlogTheme.caption(12, weight: .semibold))
                                            .foregroundColor(Color.brandPrimary)
                                            .padding(.horizontal)
                                    }
                                    .frame(minHeight: 44)
                                    .accessibilityLabel("See all food trips")
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(exploreTrips.prefix(6)) { trip in
                                            NavigationLink(value: trip) {
                                                ExploreTripCard(trip: trip)
                                            }
                                            .frame(minWidth: 44, minHeight: 44)
                                            .accessibilityLabel(trip.title)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                        } else if isLoadingTrips {
                            HStack {
                                Spacer()
                                ProgressView("Loading trips...")
                                    .font(InvlogTheme.caption(12))
                                Spacer()
                            }
                            .padding()
                        }

                        ExploreFeedView()
                    }
                }
            } else if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.restaurants.isEmpty && results.users.isEmpty && results.posts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(Color.brandTextTertiary)
                    Text(searchText.isEmpty ? "Tap a tab to browse" : "No results found")
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !results.restaurants.isEmpty {
                        Section {
                            ForEach(results.restaurants) { restaurant in
                                NavigationLink(value: restaurant) {
                                    RestaurantRowView(restaurant: restaurant)
                                }
                                .frame(minHeight: 44)
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("Places")
                                .font(InvlogTheme.caption(12, weight: .bold))
                                .foregroundColor(Color.brandTextSecondary)
                        }
                    }

                    if !results.users.isEmpty {
                        Section {
                            ForEach(results.users) { user in
                                FollowableUserRowView(user: user)
                                    .frame(minHeight: 44)
                                    .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("People")
                                .font(InvlogTheme.caption(12, weight: .bold))
                                .foregroundColor(Color.brandTextSecondary)
                        }
                    }

                    if !results.posts.isEmpty {
                        Section {
                            ForEach(results.posts) { post in
                                NavigationLink(value: post) {
                                    PostCardView(post: post)
                                }
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            Text("Posts")
                                .font(InvlogTheme.caption(12, weight: .bold))
                                .foregroundColor(Color.brandTextSecondary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Discover")
        .searchable(text: $searchText, prompt: "Search food, places, people...")
        .onChange(of: searchText) { _ in
            triggerSearch()
        }
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .navigationDestination(for: Post.self) { post in
            PostDetailView(postId: post.id)
        }
        .navigationDestination(for: NearbyRestaurantsDestination.self) { _ in
            NearbyRestaurantsView()
        }
        .navigationDestination(for: ExploreTripsDestination.self) { _ in
            ExploreTripsView()
        }
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(tripId: trip.id)
        }
        .onAppear {
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                locationManager.requestPermission()
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.startUpdating()
            }
        }
        .task {
            await loadExploreTrips()
        }
        .onChange(of: locationManager.location) { newLocation in
            guard let coord = newLocation else { return }
            Task { await loadNearbyRestaurants(lat: coord.latitude, lng: coord.longitude) }
        }
    }

    private struct PlaceCategory {
        let category: String
        let icon: String
        let restaurants: [Restaurant]
    }

    private var categorizedPlaces: [PlaceCategory] {
        let categoryMap: [(keywords: [String], label: String, icon: String)] = [
            (["restaurant", "dining", "food"], "Restaurants", "fork.knife"),
            (["cafe", "coffee", "bakery"], "Coffee & Cafes", "cup.and.saucer.fill"),
            (["bar", "lounge", "pub", "nightlife"], "Bars & Lounges", "wineglass.fill"),
            (["dessert", "ice cream", "sweet", "chocolate"], "Desserts", "birthday.cake.fill"),
        ]

        var result: [PlaceCategory] = []
        for cat in categoryMap {
            let matched = nearbyRestaurants.filter { restaurant in
                let cuisines = (restaurant.cuisineType ?? []).joined(separator: " ").lowercased()
                let name = restaurant.name.lowercased()
                return cat.keywords.contains(where: { cuisines.contains($0) || name.contains($0) })
            }
            if !matched.isEmpty {
                result.append(PlaceCategory(category: cat.label, icon: cat.icon, restaurants: matched))
            }
        }
        return result
    }

    private func loadNearbyRestaurants(lat: Double, lng: Double) async {
        guard nearbyRestaurants.isEmpty else { return }
        isLoadingNearby = true
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .nearbyRestaurants(lat: lat, lng: lng, radiusKm: 5, limit: 8),
                responseType: [Restaurant].self
            )
            nearbyRestaurants = data.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        } catch {
            // Handle error silently
        }
        isLoadingNearby = false
    }

    private func loadExploreTrips() async {
        guard exploreTrips.isEmpty else { return }
        isLoadingTrips = true
        do {
            let (response, _) = try await APIClient.shared.requestWrapped(
                .exploreTrips(cursor: nil, limit: 6),
                responseType: TripsResponse.self
            )
            exploreTrips = response.data
        } catch {
            // Handle error silently
        }
        isLoadingTrips = false
    }

    private func triggerSearch() {
        searchTask?.cancel()

        guard !searchText.isEmpty || selectedFilter != .all else {
            results = .empty
            return
        }

        results = .empty
        isSearching = true

        searchTask = Task {
            if !searchText.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
            }
            do {
                let query: String? = searchText.isEmpty ? nil : searchText
                let type = selectedFilter == .all ? nil : selectedFilter.rawValue.lowercased()
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .search(query: query, type: type, lat: nil, lng: nil),
                    responseType: SearchResults.self
                )
                if !Task.isCancelled {
                    results = data
                }
            } catch {
                // Handle error
            }
            isSearching = false
        }
    }
}

struct SearchResults: Decodable {
    let restaurants: [Restaurant]
    let users: [User]
    let posts: [Post]

    static let empty = SearchResults(restaurants: [], users: [], posts: [])
}

struct RestaurantRowView: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: 12) {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(restaurant.name)
                    .font(InvlogTheme.body(14, weight: .bold))
                    .foregroundColor(Color.brandText)

                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                    Text(cuisines.joined(separator: " · "))
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(Color.brandTextSecondary)
                }
            }

            Spacer()

            if restaurant.avgRating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(Color.brandSecondary)
                    Text(String(format: "%.1f", restaurant.avgRating))
                        .font(InvlogTheme.caption(12, weight: .bold))
                        .foregroundColor(Color.brandText)
                }
                .accessibilityLabel("Rating \(String(format: "%.1f", restaurant.avgRating)) stars")
            }
        }
    }
}

struct UserRowView: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(InvlogTheme.body(14, weight: .bold))
                        .foregroundColor(Color.brandText)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                Text("@\(user.username)")
                    .font(InvlogTheme.caption(12))
                    .foregroundColor(Color.brandTextSecondary)
            }
        }
    }
}

struct NearbyRestaurantCard: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(spacing: 8) {
            LazyImage(url: restaurant.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "building.2")
                        .font(.title2)
                        .foregroundColor(Color.brandTextTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.brandBorder)
                }
            }
            .frame(width: 100, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .accessibilityHidden(true)

            VStack(spacing: 2) {
                Text(restaurant.name)
                    .font(InvlogTheme.caption(11, weight: .bold))
                    .foregroundColor(Color.brandText)
                    .lineLimit(1)

                if restaurant.avgRating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color.brandSecondary)
                        Text(String(format: "%.1f", restaurant.avgRating))
                            .font(InvlogTheme.caption(10))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                }

                if let distance = restaurant.distance {
                    Text(formattedDistance(distance))
                        .font(InvlogTheme.caption(10))
                        .foregroundColor(Color.brandTextSecondary)
                }
            }
        }
        .frame(width: 100)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private func formattedDistance(_ km: Double) -> String {
        if km < 1 {
            return "\(Int(km * 1000))m"
        } else {
            return String(format: "%.1f km", km)
        }
    }

    private var accessibilityDescription: String {
        var parts = [restaurant.name]
        if restaurant.avgRating > 0 {
            parts.append("\(String(format: "%.1f", restaurant.avgRating)) stars")
        }
        if let distance = restaurant.distance {
            parts.append(formattedDistance(distance) + " away")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Explore Trip Card

struct ExploreTripCard: View {
    let trip: Trip

    private var statusColor: Color {
        switch trip.status {
        case "active": return Color.brandAccent
        case "completed": return Color.brandSecondary
        default: return Color.brandTextSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover image or placeholder
            ZStack(alignment: .bottomLeading) {
                if let coverUrl = trip.coverImageUrl, let url = URL(string: coverUrl) {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            tripPlaceholder
                        }
                    }
                } else {
                    tripPlaceholder
                }
            }
            .frame(width: 160, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title)
                    .font(InvlogTheme.caption(12, weight: .bold))
                    .foregroundColor(Color.brandText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 8))
                    Text("\(trip.stopCount) stop\(trip.stopCount == 1 ? "" : "s")")
                        .font(InvlogTheme.caption(10))
                }
                .foregroundColor(Color.brandTextSecondary)

                if let owner = trip.owner {
                    Text("by \(owner.displayName ?? owner.username ?? "")")
                        .font(InvlogTheme.caption(10))
                        .foregroundColor(Color.brandTextTertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 160)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.title), \(trip.stopCount) stops")
    }

    private var tripPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandOrangeLight, Color.brandAccent.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundColor(Color.brandPrimary.opacity(0.5))
        }
    }
}
