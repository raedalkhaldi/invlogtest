import SwiftUI
import MapKit
@preconcurrency import NukeUI

struct NearbyRestaurantsView: View {
    @StateObject private var viewModel = NearbyRestaurantsViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var viewMode: ViewMode = .list
    @State private var selectedCategory: NearbyCategoryFilter = .all
    @State private var foursquareResults: [FoursquarePlace] = []
    @State private var isLoadingCategory = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case map = "Map"
    }

    enum NearbyCategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case restaurants = "Restaurants"
        case coffee = "Coffee"
        case bars = "Bars"
        case desserts = "Desserts"
        case bakery = "Bakery"
        case fastFood = "Fast Food"

        var id: String { rawValue }

        var foursquareQuery: String? {
            switch self {
            case .all: return nil
            case .restaurants: return "restaurant"
            case .coffee: return "coffee cafe"
            case .bars: return "bar pub"
            case .desserts: return "dessert ice cream"
            case .bakery: return "bakery"
            case .fastFood: return "fast food"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View Mode", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityLabel("Toggle between list and map view")

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NearbyCategoryFilter.allCases) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        } label: {
                            Text(category.rawValue)
                                .font(InvlogTheme.caption(12, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? Color.brandPrimary : Color.brandCard)
                                .foregroundColor(selectedCategory == category ? .white : Color.brandText)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedCategory == category ? Color.clear : Color.brandBorder, lineWidth: 1)
                                )
                        }
                        .frame(minHeight: 36)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Group {
                if !isLocationAuthorized {
                    locationPermissionView
                } else if viewModel.isLoading && viewModel.restaurants.isEmpty {
                    ProgressView("Finding nearby places...")
                        .font(InvlogTheme.caption(12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error, viewModel.restaurants.isEmpty {
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: "Something went wrong",
                        description: error,
                        buttonTitle: "Try Again",
                        buttonAction: {
                            Task { await refreshData() }
                        }
                    )
                } else if viewModel.restaurants.isEmpty {
                    EmptyStateView(
                        systemImage: "mappin.slash",
                        title: "No places nearby",
                        description: "We couldn't find any places in your area. Try expanding your search."
                    )
                } else {
                    switch viewMode {
                    case .list:
                        listView
                    case .map:
                        mapView
                    }
                }
            }
        }
        .invlogScreenBackground()
        .navigationTitle("Nearby")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .onAppear {
            requestLocationIfNeeded()
        }
        .onChange(of: selectedCategory) { newCategory in
            guard newCategory != .all, let query = newCategory.foursquareQuery else {
                foursquareResults = []
                return
            }
            guard let coord = locationManager.location else { return }
            Task { await searchFoursquareCategory(query: query, coord: coord) }
        }
        .onChange(of: locationManager.location) { newLocation in
            guard let coord = newLocation else { return }
            region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            Task { await viewModel.loadNearby(lat: coord.latitude, lng: coord.longitude) }
        }
    }

    // MARK: - List View

    private var listView: some View {
        Group {
            if selectedCategory == .all {
                List {
                    ForEach(viewModel.restaurants) { restaurant in
                        NavigationLink(value: restaurant) {
                            NearbyRestaurantRow(restaurant: restaurant)
                        }
                        .frame(minHeight: 44)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await refreshData()
                }
            } else if isLoadingCategory {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if foursquareResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "mappin.slash")
                        .font(.largeTitle)
                        .foregroundColor(Color.brandTextTertiary)
                    Text("No \(selectedCategory.rawValue.lowercased()) found nearby")
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(foursquareResults) { place in
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
                                    .font(InvlogTheme.body(14, weight: .bold))
                                    .foregroundColor(Color.brandText)
                                if !place.address.isEmpty {
                                    Text(place.address)
                                        .font(InvlogTheme.caption(12))
                                        .foregroundColor(Color.brandTextSecondary)
                                        .lineLimit(1)
                                }
                                HStack(spacing: 4) {
                                    if let cat = place.primaryCategory {
                                        Text(cat)
                                            .font(InvlogTheme.caption(10))
                                            .foregroundColor(Color.brandPrimary)
                                    }
                                    Text("·").foregroundColor(Color.brandTextTertiary)
                                    Text(place.formattedDistance)
                                        .font(InvlogTheme.caption(10))
                                        .foregroundColor(Color.brandTextTertiary)
                                }
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func formatPOI(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "MKPOICategory", with: "")
        var result = ""
        for char in cleaned {
            if char.isUppercase && !result.isEmpty { result += " " }
            result.append(char)
        }
        return result
    }

    // MARK: - Map View

    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: mappableRestaurants) { restaurant in
            MapAnnotation(coordinate: restaurant.coordinate) {
                NavigationLink(value: restaurant.restaurant) {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(Color.brandPrimary)
                        Text(restaurant.restaurant.name)
                            .font(InvlogTheme.caption(10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandCard)
                            .clipShape(Capsule())
                            .shadow(color: InvlogTheme.cardShadowColor, radius: 2)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("\(restaurant.restaurant.name) on map")
                }
            }
        }
    }

    // MARK: - Location Permission

    private var locationPermissionView: some View {
        EmptyStateView(
            systemImage: "location.slash",
            title: "Location Access Needed",
            description: "Enable location access to discover places near you.",
            buttonTitle: "Enable Location",
            buttonAction: {
                locationManager.requestPermission()
            }
        )
    }

    // MARK: - Helpers

    private var isLocationAuthorized: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private func requestLocationIfNeeded() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestPermission()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdating()
        }
    }

    private func searchFoursquareCategory(query: String, coord: CLLocationCoordinate2D) async {
        isLoadingCategory = true
        do {
            let results = try await FoursquareService.shared.search(
                query: query,
                latitude: coord.latitude,
                longitude: coord.longitude,
                radius: 5000,
                limit: 30
            )
            foursquareResults = results
        } catch {
            foursquareResults = []
        }
        isLoadingCategory = false
    }

    private func refreshData() async {
        guard let coord = locationManager.location else { return }
        await viewModel.refresh(lat: coord.latitude, lng: coord.longitude)
    }

    private var mappableRestaurants: [MappableRestaurant] {
        viewModel.restaurants.compactMap { restaurant in
            guard let lat = restaurant.latitude, let lng = restaurant.longitude else { return nil }
            return MappableRestaurant(
                restaurant: restaurant,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
            )
        }
    }
}

// MARK: - Mappable Restaurant (for MapAnnotation)

struct MappableRestaurant: Identifiable {
    let restaurant: Restaurant
    let coordinate: CLLocationCoordinate2D
    var id: String { restaurant.id }
}

// MARK: - Nearby Restaurant Row

struct NearbyRestaurantRow: View {
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
                HStack(spacing: 4) {
                    Text(restaurant.name)
                        .font(InvlogTheme.body(14, weight: .bold))
                        .foregroundColor(Color.brandText)
                        .lineLimit(1)
                    if restaurant.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                    Text(cuisines.joined(separator: " · "))
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(Color.brandTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if restaurant.avgRating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(Color.brandSecondary)
                        Text(String(format: "%.1f", restaurant.avgRating))
                            .font(InvlogTheme.caption(12, weight: .bold))
                            .foregroundColor(Color.brandText)
                    }
                }

                if let distance = restaurant.distance {
                    Text(formattedDistance(distance))
                        .font(InvlogTheme.caption(11))
                        .foregroundColor(Color.brandTextSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandBorder.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
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
        if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
            parts.append(cuisines.joined(separator: ", "))
        }
        if restaurant.avgRating > 0 {
            parts.append("\(String(format: "%.1f", restaurant.avgRating)) stars")
        }
        if let distance = restaurant.distance {
            parts.append(formattedDistance(distance) + " away")
        }
        return parts.joined(separator: ", ")
    }
}
