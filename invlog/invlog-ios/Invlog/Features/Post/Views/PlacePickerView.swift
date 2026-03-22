import SwiftUI
import MapKit

struct SelectedPlace: Equatable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    /// If this place matches a restaurant in our DB
    let restaurantId: String?
    /// Rich data from MapKit
    let phoneNumber: String?
    let websiteURL: URL?
    let category: String?

    init(name: String, address: String, latitude: Double, longitude: Double, restaurantId: String? = nil, phoneNumber: String? = nil, websiteURL: URL? = nil, category: String? = nil) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.restaurantId = restaurantId
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
        self.category = category
    }

    /// Create from MKMapItem with rich data extraction
    init(from mapItem: MKMapItem) {
        self.name = mapItem.name ?? "Unknown Place"
        self.latitude = mapItem.placemark.coordinate.latitude
        self.longitude = mapItem.placemark.coordinate.longitude
        self.restaurantId = nil
        self.phoneNumber = mapItem.phoneNumber
        self.websiteURL = mapItem.url

        // Build address from components
        let placemark = mapItem.placemark
        var parts: [String] = []
        if let street = placemark.thoroughfare { parts.append(street) }
        if let city = placemark.locality { parts.append(city) }
        if let state = placemark.administrativeArea { parts.append(state) }
        self.address = parts.isEmpty
            ? (placemark.title ?? "")
            : parts.joined(separator: ", ")

        // Extract category from MKMapItem
        if let cat = mapItem.pointOfInterestCategory {
            self.category = Self.categoryName(for: cat)
        } else {
            self.category = nil
        }
    }

    static func categoryName(for category: MKPointOfInterestCategory) -> String {
        switch category {
        case .restaurant: return "Restaurant"
        case .cafe: return "Cafe"
        case .bakery: return "Bakery"
        case .brewery: return "Brewery"
        case .nightlife: return "Nightlife"
        case .foodMarket: return "Food Market"
        case .winery: return "Winery"
        default: return "Place"
        }
    }
}

// MARK: - Place Category

enum PlaceCategory: String, CaseIterable, Identifiable {
    case restaurant = "Restaurant"
    case cafeCoffee = "Cafe/Coffee"
    case barLounge = "Bar/Lounge"
    case desserts = "Desserts"
    case bakery = "Bakery"
    case fastFood = "Fast Food"
    case streetFood = "Street Food"
    case fineDining = "Fine Dining"
    case grocery = "Grocery"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - New Place Form Sheet

struct NewPlaceFormView: View {
    let initialName: String
    let latitude: Double
    let longitude: Double
    let address: String
    let onSave: (String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var placeName: String = ""
    @State private var selectedCategory: PlaceCategory = .restaurant
    @State private var customCategoryText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Place name", text: $placeName)
                        .font(InvlogTheme.body(14))
                        .frame(minHeight: 44)
                } header: {
                    Text("Name")
                        .font(InvlogTheme.caption(12, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                }

                Section {
                    ForEach(PlaceCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                Text(category.rawValue)
                                    .font(InvlogTheme.body(14))
                                    .foregroundColor(Color.brandText)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.brandPrimary)
                                        .font(.caption)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }

                    if selectedCategory == .other {
                        TextField("Custom category", text: $customCategoryText)
                            .font(InvlogTheme.body(14))
                            .frame(minHeight: 44)
                    }
                } header: {
                    Text("Category")
                        .font(InvlogTheme.caption(12, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .invlogScreenBackground()
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }

                        let cuisineType: [String]
                        if selectedCategory == .other {
                            let custom = customCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
                            cuisineType = custom.isEmpty ? [] : [custom]
                        } else {
                            cuisineType = [selectedCategory.rawValue]
                        }

                        dismiss()
                        onSave(name, cuisineType)
                    }
                    .disabled(placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onAppear {
                placeName = initialName
            }
        }
    }
}

// MARK: - Place Picker View

struct PlacePickerView: View {
    @Binding var selectedPlace: SelectedPlace?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var dbRestaurants: [Restaurant] = []
    @State private var foursquareResults: [FoursquarePlace] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isCreatingPlace = false
    @State private var showNewPlaceForm = false
    @State private var pendingPlaceName = ""
    @State private var pendingPlaceAddress = ""
    @State private var pendingPlaceLat: Double = 0
    @State private var pendingPlaceLng: Double = 0

    /// Merged results: DB restaurants first, then Foursquare, then Apple Maps (deduped)
    private var mergedResults: [PlaceResult] {
        var results: [PlaceResult] = []
        var usedNames = Set<String>()

        // 1. DB restaurants first (verified, in our system)
        for restaurant in dbRestaurants {
            results.append(.dbRestaurant(restaurant))
            usedNames.insert(restaurant.name.lowercased())
        }

        // 2. Foursquare results (richer data: categories, chains)
        for place in foursquareResults {
            let name = place.name.lowercased()
            if !usedNames.contains(name) {
                results.append(.foursquare(place))
                usedNames.insert(name)
            }
        }

        // 3. Apple Maps results (fallback for places not in Foursquare)
        for item in searchResults {
            let name = (item.name ?? "").lowercased()
            if !usedNames.contains(name) {
                results.append(.mapItem(item))
                usedNames.insert(name)
            }
        }

        return results
    }

    private enum PlaceResult: Identifiable {
        case dbRestaurant(Restaurant)
        case foursquare(FoursquarePlace)
        case mapItem(MKMapItem)

        var id: String {
            switch self {
            case .dbRestaurant(let r): return "db-\(r.id)"
            case .foursquare(let p): return "fsq-\(p.id)"
            case .mapItem(let item): return "map-\(item.name ?? "")-\(item.placemark.coordinate.latitude)"
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if searchText.isEmpty && mergedResults.isEmpty && !isSearching {
                    Section {
                        if locationManager.location != nil {
                            Button {
                                searchNearby()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(Color.brandPrimary)
                                    Text("Search nearby places")
                                        .font(InvlogTheme.body(14))
                                        .foregroundColor(Color.brandText)
                                }
                            }
                            .frame(minHeight: 44)
                        } else {
                            Button {
                                locationManager.requestPermission()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "location")
                                        .foregroundColor(Color.brandTextSecondary)
                                    Text("Enable location for nearby places")
                                        .font(InvlogTheme.body(14))
                                        .foregroundColor(Color.brandText)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                } else if isSearching && mergedResults.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if mergedResults.isEmpty && !searchText.isEmpty && !isSearching {
                    Section {
                        Button {
                            presentNewPlaceForm(
                                name: searchText,
                                address: "",
                                lat: locationManager.location?.latitude ?? 0,
                                lng: locationManager.location?.longitude ?? 0
                            )
                        } label: {
                            HStack(spacing: 12) {
                                if isCreatingPlace {
                                    ProgressView()
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Color.brandPrimary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add \"\(searchText)\"")
                                        .font(InvlogTheme.body(14, weight: .bold))
                                        .foregroundColor(Color.brandText)
                                    Text("Save as a new place for everyone")
                                        .font(InvlogTheme.caption(12))
                                        .foregroundColor(Color.brandTextSecondary)
                                }
                            }
                        }
                        .disabled(isCreatingPlace)
                        .frame(minHeight: 44)
                    }
                }

                // "Use Current Location" option
                if searchText.isEmpty, let coord = locationManager.location {
                    Section {
                        Button {
                            presentNewPlaceForm(
                                name: "My Location",
                                address: "",
                                lat: coord.latitude,
                                lng: coord.longitude
                            )
                        } label: {
                            HStack(spacing: 12) {
                                if isCreatingPlace {
                                    ProgressView()
                                } else {
                                    Image(systemName: "location.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(Color.brandAccent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use Current Location")
                                        .font(InvlogTheme.body(14, weight: .bold))
                                        .foregroundColor(Color.brandText)
                                    Text("Save as a new place for everyone")
                                        .font(InvlogTheme.caption(12))
                                        .foregroundColor(Color.brandTextSecondary)
                                }
                            }
                        }
                        .disabled(isCreatingPlace)
                        .frame(minHeight: 44)
                    }
                }

                if !mergedResults.isEmpty {
                    Section {
                        ForEach(mergedResults) { result in
                            switch result {
                            case .dbRestaurant(let restaurant):
                                Button {
                                    selectDBRestaurant(restaurant)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color.brandAccent)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(restaurant.name)
                                                    .font(InvlogTheme.body(14, weight: .bold))
                                                    .foregroundColor(Color.brandText)

                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(Color.brandPrimary)
                                            }

                                            if let address = restaurant.addressLine1, !address.isEmpty {
                                                Text(address)
                                                    .font(InvlogTheme.caption(12))
                                                    .foregroundColor(Color.brandTextSecondary)
                                                    .lineLimit(2)
                                            }

                                            if let cuisines = restaurant.cuisineType, !cuisines.isEmpty {
                                                Text(cuisines.joined(separator: " · "))
                                                    .font(InvlogTheme.caption(10))
                                                    .foregroundColor(Color.brandPrimary)
                                            }
                                        }

                                        Spacer()
                                    }
                                }
                                .frame(minHeight: 44)

                            case .foursquare(let place):
                                Button {
                                    selectFoursquarePlace(place)
                                } label: {
                                    HStack(spacing: 12) {
                                        // Category icon from Foursquare
                                        if let iconURL = place.categoryIcon {
                                            AsyncImage(url: iconURL) { phase in
                                                if case .success(let img) = phase {
                                                    img.resizable().scaledToFit()
                                                } else {
                                                    Image(systemName: "fork.knife.circle.fill")
                                                        .font(.title2)
                                                        .foregroundColor(Color.brandSecondary)
                                                }
                                            }
                                            .frame(width: 32, height: 32)
                                        } else {
                                            Image(systemName: "fork.knife.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(Color.brandSecondary)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(place.name)
                                                    .font(InvlogTheme.body(14, weight: .bold))
                                                    .foregroundColor(Color.brandText)

                                                if place.chainName != nil {
                                                    Image(systemName: "link.circle.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(Color.brandAccent)
                                                }
                                            }

                                            if !place.address.isEmpty {
                                                Text(place.address)
                                                    .font(InvlogTheme.caption(12))
                                                    .foregroundColor(Color.brandTextSecondary)
                                                    .lineLimit(2)
                                            }

                                            HStack(spacing: 6) {
                                                if let cat = place.primaryCategory {
                                                    Text(cat)
                                                        .font(InvlogTheme.caption(10, weight: .semibold))
                                                        .foregroundColor(Color.brandPrimary)
                                                }
                                                Text("·")
                                                    .foregroundColor(Color.brandTextTertiary)
                                                Text(place.formattedDistance)
                                                    .font(InvlogTheme.caption(10))
                                                    .foregroundColor(Color.brandTextTertiary)
                                            }
                                        }

                                        Spacer()
                                    }
                                }
                                .frame(minHeight: 44)

                            case .mapItem(let item):
                                Button {
                                    selectMapItem(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(Color.brandPrimary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name ?? "Unknown Place")
                                                .font(InvlogTheme.body(14, weight: .bold))
                                                .foregroundColor(Color.brandText)

                                            if let address = formatAddress(item.placemark) {
                                                Text(address)
                                                    .font(InvlogTheme.caption(12))
                                                    .foregroundColor(Color.brandTextSecondary)
                                                    .lineLimit(2)
                                            }

                                            if let category = item.pointOfInterestCategory?.rawValue {
                                                Text(formatCategory(category))
                                                    .font(InvlogTheme.caption(10))
                                                    .foregroundColor(Color.brandPrimary)
                                            }
                                        }

                                        Spacer()
                                    }
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    } header: {
                        Text("Results")
                            .font(InvlogTheme.caption(12, weight: .bold))
                            .foregroundColor(Color.brandTextSecondary)
                    }

                    // "Add new" option at the bottom of results when searching
                    if !searchText.isEmpty {
                        Section {
                            Button {
                                presentNewPlaceForm(
                                    name: searchText,
                                    address: "",
                                    lat: locationManager.location?.latitude ?? 0,
                                    lng: locationManager.location?.longitude ?? 0
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Color.brandPrimary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add \"\(searchText)\"")
                                            .font(InvlogTheme.body(14, weight: .bold))
                                            .foregroundColor(Color.brandText)
                                        Text("Not listed? Save as a new place")
                                            .font(InvlogTheme.caption(12))
                                            .foregroundColor(Color.brandTextSecondary)
                                    }
                                }
                            }
                            .disabled(isCreatingPlace)
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .invlogScreenBackground()
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
            .sheet(isPresented: $showNewPlaceForm) {
                NewPlaceFormView(
                    initialName: pendingPlaceName,
                    latitude: pendingPlaceLat,
                    longitude: pendingPlaceLng,
                    address: pendingPlaceAddress
                ) { name, cuisineType in
                    Task {
                        await createAndSelectPlace(
                            name: name,
                            address: pendingPlaceAddress,
                            lat: pendingPlaceLat,
                            lng: pendingPlaceLng,
                            cuisineType: cuisineType
                        )
                    }
                }
            }
            .onAppear {
                let status = locationManager.authorizationStatus
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    locationManager.startUpdating()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        searchNearby()
                    }
                }
            }
        }
    }

    // MARK: - New Place Form

    private func presentNewPlaceForm(name: String, address: String, lat: Double, lng: Double) {
        pendingPlaceName = name
        pendingPlaceAddress = address
        pendingPlaceLat = lat
        pendingPlaceLng = lng
        showNewPlaceForm = true
    }

    // MARK: - Search

    private func triggerSearch() {
        searchTask?.cancel()
        guard !searchText.isEmpty else {
            searchResults = []
            dbRestaurants = []
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
            await performNearbySearch()
        }
    }

    @MainActor
    private func performNearbySearch() async {
        isSearching = true
        guard let coord = locationManager.location else {
            isSearching = false
            return
        }

        let region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        // MKLocalSearch requires a query string — search multiple categories in parallel
        let queries = ["restaurant", "cafe coffee", "bar lounge", "bakery", "grocery", "food"]

        await withTaskGroup(of: [MKMapItem].self) { group in
            for query in queries {
                group.addTask {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = query
                    request.resultTypes = .pointOfInterest
                    request.region = region
                    do {
                        let search = MKLocalSearch(request: request)
                        let response = try await search.start()
                        return response.mapItems
                    } catch {
                        return []
                    }
                }
            }

            // Also fetch from our DB
            group.addTask {
                do {
                    let (data, _) = try await APIClient.shared.requestWrapped(
                        .nearbyRestaurants(lat: coord.latitude, lng: coord.longitude, radiusKm: 5, limit: 30),
                        responseType: [Restaurant].self
                    )
                    await MainActor.run {
                        self.dbRestaurants = data.sorted {
                            ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude)
                        }
                    }
                } catch {
                    await MainActor.run { self.dbRestaurants = [] }
                }
                return [] // DB results go to dbRestaurants, not mapItems
            }

            // Collect and deduplicate Apple Maps results
            var allItems: [MKMapItem] = []
            var seenNames = Set<String>()
            for await items in group {
                for item in items {
                    let name = (item.name ?? "").lowercased()
                    if !seenNames.contains(name) {
                        seenNames.insert(name)
                        allItems.append(item)
                    }
                }
            }
            searchResults = allItems
        }

        isSearching = false
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true

        // Search Foursquare, Apple Maps, and our DB in parallel
        await withTaskGroup(of: Void.self) { group in
            // Foursquare (richest data: categories, chains, distance)
            group.addTask { @MainActor in
                if let coord = locationManager.location {
                    do {
                        let results = try await FoursquareService.shared.search(
                            query: query,
                            latitude: coord.latitude,
                            longitude: coord.longitude,
                            radius: 5000,
                            limit: 20
                        )
                        foursquareResults = results
                    } catch {
                        foursquareResults = []
                    }
                }
            }

            // Apple Maps (fallback, free, no limits)
            group.addTask { @MainActor in
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = [.pointOfInterest, .address]

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
            }

            // Our DB
            group.addTask { @MainActor in
                if let coord = locationManager.location {
                    do {
                        let (data, _) = try await APIClient.shared.requestWrapped(
                            .nearbyRestaurants(lat: coord.latitude, lng: coord.longitude, radiusKm: 5, limit: 30),
                            responseType: [Restaurant].self
                        )
                        let q = query.lowercased()
                        dbRestaurants = data.filter { restaurant in
                            restaurant.name.lowercased().contains(q) ||
                            (restaurant.cuisineType ?? []).contains(where: { $0.lowercased().contains(q) }) ||
                            (restaurant.addressLine1 ?? "").lowercased().contains(q)
                        }
                    } catch {
                        dbRestaurants = []
                    }
                }
            }
        }

        isSearching = false
    }

    // MARK: - Selection

    private func selectDBRestaurant(_ restaurant: Restaurant) {
        selectedPlace = SelectedPlace(
            name: restaurant.name,
            address: restaurant.addressLine1 ?? "",
            latitude: restaurant.latitude ?? 0,
            longitude: restaurant.longitude ?? 0,
            restaurantId: restaurant.id
        )
        dismiss()
    }

    private func selectFoursquarePlace(_ place: FoursquarePlace) {
        let cuisine = place.categories.map { $0.name }
        Task {
            await createAndSelectPlace(
                name: place.name,
                address: place.address,
                lat: place.latitude,
                lng: place.longitude,
                cuisineType: cuisine.isEmpty ? nil : cuisine
            )
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        // Extract category from MapKit POI
        var cuisine: [String]? = nil
        if let cat = item.pointOfInterestCategory {
            let catName = SelectedPlace.categoryName(for: cat)
            if catName != "Place" { cuisine = [catName] }
        }

        Task {
            await createAndSelectPlace(
                name: item.name ?? "Unknown Place",
                address: formatAddress(item.placemark) ?? "",
                lat: item.placemark.coordinate.latitude,
                lng: item.placemark.coordinate.longitude,
                cuisineType: cuisine,
                phoneNumber: item.phoneNumber,
                websiteURL: item.url
            )
        }
    }

    @MainActor
    private func createAndSelectPlace(name: String, address: String, lat: Double, lng: Double, cuisineType: [String]?, phoneNumber: String? = nil, websiteURL: URL? = nil) async {
        isCreatingPlace = true
        do {
            var data: [String: Any] = [
                "name": name,
                "latitude": lat,
                "longitude": lng,
                "addressLine1": address,
            ]
            if let cuisineType, !cuisineType.isEmpty {
                data["cuisineType"] = cuisineType
            }
            if let phoneNumber { data["phone"] = phoneNumber }
            if let websiteURL { data["website"] = websiteURL.absoluteString }

            let (restaurant, _) = try await APIClient.shared.requestWrapped(
                .createRestaurant(data: data),
                responseType: Restaurant.self
            )
            selectedPlace = SelectedPlace(
                name: name,
                address: address,
                latitude: lat,
                longitude: lng,
                restaurantId: restaurant.id,
                phoneNumber: phoneNumber,
                websiteURL: websiteURL,
                category: cuisineType?.first
            )
        } catch {
            // Fallback: select without DB entry
            selectedPlace = SelectedPlace(
                name: name,
                address: address,
                latitude: lat,
                longitude: lng,
                restaurantId: nil,
                phoneNumber: phoneNumber,
                websiteURL: websiteURL,
                category: cuisineType?.first
            )
        }
        isCreatingPlace = false
        dismiss()
    }

    // MARK: - Formatting

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
        let cleaned = raw
            .replacingOccurrences(of: "MKPOICategory", with: "")
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
