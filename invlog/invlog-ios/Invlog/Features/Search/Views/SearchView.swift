import SwiftUI
import MapKit
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
    @State private var selectedPlaceCategory: PlaceCategoryFilter = .all
    @State private var foursquareNearbyItems: [FoursquarePlace] = []

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

    enum PlaceCategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case restaurants = "Restaurants"
        case coffee = "Coffee"
        case bars = "Bars"
        case desserts = "Desserts"
        case bakery = "Bakery"
        case fastFood = "Fast Food"
        case fineDining = "Fine Dining"

        var id: String { rawValue }

        /// Foursquare category IDs for this filter
        var foursquareCategoryIds: String? {
            switch self {
            case .all: return nil // no filter = all food
            case .restaurants: return "13065"        // Restaurant
            case .coffee: return "13032,13035"        // Coffee Shop, Cafe
            case .bars: return "13003"                // Bar
            case .desserts: return "13040"            // Dessert Shop
            case .bakery: return "13002"              // Bakery
            case .fastFood: return "13145"            // Fast Food
            case .fineDining: return "13065"           // Restaurant (filtered by query)
            }
        }

        /// Foursquare search query for this category
        var foursquareQuery: String? {
            switch self {
            case .all: return "food"
            case .restaurants: return "restaurant"
            case .coffee: return "coffee cafe"
            case .bars: return "bar pub"
            case .desserts: return "dessert ice cream"
            case .bakery: return "bakery"
            case .fastFood: return "fast food"
            case .fineDining: return "fine dining"
            }
        }

        var keywords: [String] {
            switch self {
            case .all: return []
            case .restaurants: return ["restaurant", "dining", "food"]
            case .coffee: return ["cafe", "coffee"]
            case .bars: return ["bar", "lounge", "pub", "nightlife"]
            case .desserts: return ["dessert", "ice cream", "sweet", "chocolate"]
            case .bakery: return ["bakery"]
            case .fastFood: return ["fast food", "street food"]
            case .fineDining: return ["fine dining"]
            }
        }

        var emoji: String {
            switch self {
            case .all: return "🌍"
            case .restaurants: return "🍕"
            case .coffee: return "☕"
            case .bars: return "🍸"
            case .desserts: return "🧁"
            case .bakery: return "🥐"
            case .fastFood: return "🍔"
            case .fineDining: return "🍷"
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

                        // Nearby Places with category filter tabs
                        if !nearbyRestaurants.isEmpty {
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

                                // Category filter chips
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(PlaceCategoryFilter.allCases) { category in
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedPlaceCategory = category
                                                }
                                            } label: {
                                                Text("\(category.emoji) \(category.rawValue)")
                                                    .font(InvlogTheme.caption(12, weight: .bold))
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 6)
                                                    .background(selectedPlaceCategory == category ? Color.brandPrimary : Color.brandCard)
                                                    .foregroundColor(selectedPlaceCategory == category ? .white : Color.brandText)
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(selectedPlaceCategory == category ? Color.clear : Color.brandBorder, lineWidth: 1)
                                                    )
                                            }
                                            .frame(minHeight: 36)
                                            .accessibilityLabel("\(category.rawValue) filter")
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                                // Filtered results — DB restaurants
                                if selectedPlaceCategory == .all {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(nearbyRestaurants.prefix(12)) { restaurant in
                                                NavigationLink(value: restaurant) {
                                                    NearbyRestaurantCard(restaurant: restaurant)
                                                }
                                                .frame(minWidth: 44, minHeight: 44)
                                                .accessibilityLabel("\(restaurant.name)")
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                } else if isLoadingNearby {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                } else if foursquareNearbyItems.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text("No \(selectedPlaceCategory.rawValue.lowercased()) nearby")
                                            .font(InvlogTheme.caption(12))
                                            .foregroundColor(Color.brandTextSecondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                } else {
                                    // Foursquare results with rich category data
                                    VStack(spacing: 0) {
                                        ForEach(foursquareNearbyItems.prefix(15)) { place in
                                            Button {
                                                // TODO: navigate to place detail
                                            } label: {
                                                HStack(spacing: 12) {
                                                    if let iconURL = place.categoryIcon {
                                                        AsyncImage(url: iconURL) { phase in
                                                            if case .success(let img) = phase {
                                                                img.resizable().scaledToFit()
                                                            } else {
                                                                Image(systemName: "fork.knife.circle.fill")
                                                                    .font(.title3)
                                                                    .foregroundColor(Color.brandPrimary)
                                                            }
                                                        }
                                                        .frame(width: 28, height: 28)
                                                    } else {
                                                        Image(systemName: "fork.knife.circle.fill")
                                                            .font(.title3)
                                                            .foregroundColor(Color.brandPrimary)
                                                    }
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(place.name)
                                                            .font(InvlogTheme.body(14, weight: .semibold))
                                                            .foregroundColor(Color.brandText)
                                                            .lineLimit(1)
                                                        if !place.address.isEmpty {
                                                            Text(place.address)
                                                                .font(InvlogTheme.caption(11))
                                                                .foregroundColor(Color.brandTextSecondary)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    Spacer()
                                                    VStack(alignment: .trailing, spacing: 2) {
                                                        if let cat = place.primaryCategory {
                                                            Text(cat)
                                                                .font(InvlogTheme.caption(10))
                                                                .foregroundColor(Color.brandPrimary)
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 3)
                                                                .background(Color.brandOrangeLight)
                                                                .clipShape(Capsule())
                                                        }
                                                        Text(place.formattedDistance)
                                                            .font(InvlogTheme.caption(10))
                                                            .foregroundColor(Color.brandTextTertiary)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal)
                                            }
                                            .buttonStyle(.plain)
                                            if place.id != foursquareNearbyItems.prefix(15).last?.id {
                                                Rectangle().fill(Color.brandBorder).frame(height: 0.5)
                                                    .padding(.horizontal)
                                            }
                                        }
                                    }
                                    .background(Color.brandCard)
                                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius))
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
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
        .navigationTitle("Explore")
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
        .onChange(of: selectedPlaceCategory) { newCategory in
            guard newCategory != .all else {
                foursquareNearbyItems = []
                return
            }
            Task { await searchFoursquareCategory(category: newCategory) }
        }
        .onChange(of: locationManager.location) { newLocation in
            guard let coord = newLocation else { return }
            Task { await loadNearbyRestaurants(lat: coord.latitude, lng: coord.longitude) }
        }
    }

    private func searchFoursquareCategory(category: PlaceCategoryFilter) async {
        guard let coord = locationManager.location else { return }
        isLoadingNearby = true
        foursquareNearbyItems = []

        do {
            let results = try await FoursquareService.shared.search(
                query: category.foursquareQuery ?? "food",
                latitude: coord.latitude,
                longitude: coord.longitude,
                radius: 5000,
                limit: 30
            )
            foursquareNearbyItems = results
        } catch {
            foursquareNearbyItems = []
        }
        isLoadingNearby = false
    }

    private func formatPOICategory(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "MKPOICategory", with: "")
        var result = ""
        for char in cleaned {
            if char.isUppercase && !result.isEmpty { result += " " }
            result.append(char)
        }
        return result
    }

    private func loadNearbyRestaurants(lat: Double, lng: Double) async {
        guard nearbyRestaurants.isEmpty else { return }
        isLoadingNearby = true
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .nearbyRestaurants(lat: lat, lng: lng, radiusKm: 5, limit: 30),
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
