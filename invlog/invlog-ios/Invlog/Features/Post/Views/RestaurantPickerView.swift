import SwiftUI
import NukeUI

struct RestaurantPickerView: View {
    @Binding var selectedRestaurant: Restaurant?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var searchResults: [Restaurant] = []
    @State private var nearbyRestaurants: [Restaurant] = []
    @State private var isSearching = false
    @State private var isLoadingNearby = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            List {
                // Selected restaurant (if any)
                if let restaurant = selectedRestaurant {
                    Section {
                        HStack(spacing: 12) {
                            restaurantInfo(restaurant)
                            Spacer()
                            Button {
                                selectedRestaurant = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Remove selected place")
                        }
                        .frame(minHeight: 44)
                    } header: {
                        Text("Selected")
                    }
                }

                if searchText.isEmpty {
                    // Nearby section
                    if !nearbyRestaurants.isEmpty {
                        Section {
                            ForEach(nearbyRestaurants) { restaurant in
                                Button {
                                    selectRestaurant(restaurant)
                                } label: {
                                    HStack(spacing: 12) {
                                        restaurantInfo(restaurant)
                                        Spacer()
                                        if let distance = restaurant.distance {
                                            Text(formattedDistance(distance))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(minHeight: 44)
                                .accessibilityLabel("Select \(restaurant.name)")
                            }
                        } header: {
                            Text("Nearby")
                        }
                    } else if isLoadingNearby {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView("Finding nearby...")
                                Spacer()
                            }
                        } header: {
                            Text("Nearby")
                        }
                    }
                } else {
                    // Search results
                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if searchResults.isEmpty {
                        EmptyStateView(
                            systemImage: "magnifyingglass",
                            title: "No results",
                            description: "No places found for \"\(searchText)\""
                        )
                    } else {
                        Section {
                            ForEach(searchResults) { restaurant in
                                Button {
                                    selectRestaurant(restaurant)
                                } label: {
                                    HStack(spacing: 12) {
                                        restaurantInfo(restaurant)
                                        Spacer()
                                        if restaurant.avgRating > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                                Text(String(format: "%.1f", restaurant.avgRating))
                                                    .font(.caption.bold())
                                            }
                                        }
                                    }
                                }
                                .frame(minHeight: 44)
                                .accessibilityLabel("Select \(restaurant.name)")
                            }
                        } header: {
                            Text("Results")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search places...")
            .onChange(of: searchText) { _ in
                triggerSearch()
            }
            .navigationTitle("Tag a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Cancel place selection")
                }
            }
            .onAppear {
                let status = locationManager.authorizationStatus
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    locationManager.startUpdating()
                }
            }
            .onChange(of: locationManager.location) { newLocation in
                guard let coord = newLocation else { return }
                Task { await loadNearby(lat: coord.latitude, lng: coord.longitude) }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func restaurantInfo(_ restaurant: Restaurant) -> some View {
        HStack(spacing: 12) {
            LazyImage(url: restaurant.avatarUrl) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "building.2")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(restaurant.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                    Text(cuisines.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Actions

    private func selectRestaurant(_ restaurant: Restaurant) {
        selectedRestaurant = restaurant
        dismiss()
    }

    private func triggerSearch() {
        searchTask?.cancel()
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            // Debounce 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let lat = locationManager.location?.latitude
                let lng = locationManager.location?.longitude
                let (data, _) = try await APIClient.shared.requestWrapped(
                    .search(query: searchText, type: "restaurants", lat: lat, lng: lng),
                    responseType: SearchResults.self
                )
                if !Task.isCancelled {
                    searchResults = data.restaurants
                }
            } catch {
                // Handle error silently
            }
            isSearching = false
        }
    }

    private func loadNearby(lat: Double, lng: Double) async {
        isLoadingNearby = true
        do {
            let (data, _) = try await APIClient.shared.requestWrapped(
                .nearbyRestaurants(lat: lat, lng: lng, radiusKm: 5, limit: 10),
                responseType: [Restaurant].self
            )
            nearbyRestaurants = data.sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        } catch {
            // Handle error silently
        }
        isLoadingNearby = false
    }

    private func formattedDistance(_ km: Double) -> String {
        if km < 1 {
            return "\(Int(km * 1000))m"
        } else {
            return String(format: "%.1f km", km)
        }
    }
}
