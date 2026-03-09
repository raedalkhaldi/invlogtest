import SwiftUI
import MapKit

struct SelectedPlace: Equatable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    /// If this place matches a restaurant in our DB
    let restaurantId: String?
}

struct PlacePickerView: View {
    @Binding var selectedPlace: SelectedPlace?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            List {
                if searchText.isEmpty && searchResults.isEmpty {
                    // Show nearby places when no search
                    Section {
                        if locationManager.location != nil {
                            Button {
                                searchNearby()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    Text("Search nearby restaurants")
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(minHeight: 44)
                        } else {
                            Button {
                                locationManager.requestPermission()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "location")
                                        .foregroundColor(.secondary)
                                    Text("Enable location for nearby places")
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                } else if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    // Custom place option
                    Section {
                        Button {
                            let place = SelectedPlace(
                                name: searchText,
                                address: "",
                                latitude: locationManager.location?.latitude ?? 0,
                                longitude: locationManager.location?.longitude ?? 0,
                                restaurantId: nil
                            )
                            selectedPlace = place
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add \"\(searchText)\"")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    Text("as a new place")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }

                if !searchResults.isEmpty {
                    Section("Results") {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectMapItem(item)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown Place")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)

                                        if let address = formatAddress(item.placemark) {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }

                                        if let category = item.pointOfInterestCategory?.rawValue {
                                            Text(formatCategory(category))
                                                .font(.caption2)
                                                .foregroundColor(.accentColor)
                                        }
                                    }

                                    Spacer()
                                }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search restaurants, cafes, places...")
            .onChange(of: searchText) { _ in
                triggerSearch()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }

                if selectedPlace != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            selectedPlace = nil
                            dismiss()
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            .onAppear {
                let status = locationManager.authorizationStatus
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    locationManager.startUpdating()
                    // Auto-search nearby on appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        searchNearby()
                    }
                }
            }
        }
    }

    private func triggerSearch() {
        searchTask?.cancel()
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            await performSearch(query: searchText)
        }
    }

    private func searchNearby() {
        Task {
            await performSearch(query: "restaurant")
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        if let coord = locationManager.location {
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }

        isSearching = false
    }

    private func selectMapItem(_ item: MKMapItem) {
        let place = SelectedPlace(
            name: item.name ?? "Unknown Place",
            address: formatAddress(item.placemark) ?? "",
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude,
            restaurantId: nil
        )
        selectedPlace = place
        dismiss()
    }

    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var parts: [String] = []
        if let street = placemark.thoroughfare { parts.append(street) }
        if let subLocality = placemark.subLocality { parts.append(subLocality) }
        if let city = placemark.locality { parts.append(city) }
        if let area = placemark.administrativeArea, area != placemark.locality {
            parts.append(area)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func formatCategory(_ raw: String) -> String {
        // Convert "MKPOICategoryRestaurant" → "Restaurant"
        let cleaned = raw
            .replacingOccurrences(of: "MKPOICategory", with: "")
        // Insert spaces before capitals
        var result = ""
        for char in cleaned {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result.append(char)
        }
        return result
    }
}
