import SwiftUI
import MapKit
import NukeUI

struct NearbyRestaurantsView: View {
    @StateObject private var viewModel = NearbyRestaurantsViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var viewMode: ViewMode = .list
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case map = "Map"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("View Mode", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityLabel("Toggle between list and map view")

            // Content
            Group {
                if !isLocationAuthorized {
                    locationPermissionView
                } else if viewModel.isLoading && viewModel.restaurants.isEmpty {
                    ProgressView("Finding nearby restaurants...")
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
                        title: "No restaurants nearby",
                        description: "We couldn't find any restaurants in your area. Try expanding your search."
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
        .navigationTitle("Nearby")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Restaurant.self) { restaurant in
            RestaurantDetailView(restaurantSlug: restaurant.slug)
        }
        .onAppear {
            requestLocationIfNeeded()
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
        List {
            ForEach(viewModel.restaurants) { restaurant in
                NavigationLink(value: restaurant) {
                    NearbyRestaurantRow(restaurant: restaurant)
                }
                .frame(minHeight: 44)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshData()
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: mappableRestaurants) { restaurant in
            MapAnnotation(coordinate: restaurant.coordinate) {
                NavigationLink(value: restaurant.restaurant) {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        Text(restaurant.restaurant.name)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemBackground))
                            .clipShape(Capsule())
                            .shadow(radius: 2)
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
            description: "Enable location access to discover restaurants near you.",
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
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(restaurant.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if restaurant.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                    Text(cuisines.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if restaurant.avgRating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", restaurant.avgRating))
                            .font(.caption.bold())
                    }
                }

                if let distance = restaurant.distance {
                    Text(formattedDistance(distance))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
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
