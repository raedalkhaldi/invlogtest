import SwiftUI

struct NearbyRestaurantsDestination: Hashable {}

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var results: SearchResults = .empty
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @StateObject private var locationManager = LocationManager()
    @State private var nearbyRestaurants: [Restaurant] = []
    @State private var isLoadingNearby = false

    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case restaurants = "Restaurants"
        case users = "People"
        case posts = "Posts"
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
                            Text(filter.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedFilter == filter ? Color.accentColor : Color(.systemGray5))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("\(filter.rawValue) filter")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if searchText.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Quick Actions
                        HStack(spacing: 12) {
                            NavigationLink(value: NearbyRestaurantsDestination()) {
                                HStack(spacing: 8) {
                                    Image(systemName: "map")
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Nearby")
                                            .font(.subheadline.bold())
                                        Text("Map & Restaurants")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel("View nearby restaurants on map")
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Nearby Restaurants Section
                        if !nearbyRestaurants.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Nearby Restaurants")
                                        .font(.headline)
                                        .padding(.horizontal)

                                    Spacer()

                                    NavigationLink(value: NearbyRestaurantsDestination()) {
                                        Text("See All")
                                            .font(.caption)
                                            .padding(.horizontal)
                                    }
                                    .frame(minHeight: 44)
                                    .accessibilityLabel("See all nearby restaurants")
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
                        } else if isLoadingNearby {
                            HStack {
                                Spacer()
                                ProgressView("Finding nearby restaurants...")
                                    .font(.caption)
                                Spacer()
                            }
                            .padding()
                        }

                        // Explore feed
                        ExploreFeedView()
                    }
                }
            } else if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !results.restaurants.isEmpty {
                        Section("Restaurants") {
                            ForEach(results.restaurants) { restaurant in
                                NavigationLink(value: restaurant) {
                                    RestaurantRowView(restaurant: restaurant)
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }

                    if !results.users.isEmpty {
                        Section("People") {
                            ForEach(results.users) { user in
                                UserRowView(user: user)
                                    .frame(minHeight: 44)
                            }
                        }
                    }

                    if !results.posts.isEmpty {
                        Section("Posts") {
                            ForEach(results.posts) { post in
                                NavigationLink(value: post) {
                                    PostCardView(post: post)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Discover")
        .searchable(text: $searchText, prompt: "Search food, restaurants, people...")
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
        .onAppear {
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                locationManager.requestPermission()
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.startUpdating()
            }
        }
        .onChange(of: locationManager.location) { newLocation in
            guard let coord = newLocation else { return }
            Task { await loadNearbyRestaurants(lat: coord.latitude, lng: coord.longitude) }
        }
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

    private func triggerSearch() {
        searchTask?.cancel()
        guard !searchText.isEmpty else { return }

        searchTask = Task {
            // Debounce 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let type = selectedFilter == .all ? nil : selectedFilter.rawValue.lowercased()
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .search(query: searchText, type: type, lat: nil, lng: nil),
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
            AsyncImage(url: restaurant.avatarUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "building.2")
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(restaurant.name)
                    .font(.subheadline.bold())

                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                    Text(cuisines.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if restaurant.avgRating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", restaurant.avgRating))
                        .font(.caption.bold())
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
            AsyncImage(url: user.avatarUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(.subheadline.bold())
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct NearbyRestaurantCard: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: restaurant.avatarUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray5))
            }
            .frame(width: 100, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(spacing: 2) {
                Text(restaurant.name)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if restaurant.avgRating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", restaurant.avgRating))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if let distance = restaurant.distance {
                    Text(formattedDistance(distance))
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
