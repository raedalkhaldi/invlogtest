import SwiftUI
import MapKit
@preconcurrency import NukeUI

struct TripDetailView: View {
    let tripId: String

    @StateObject private var viewModel: TripDetailViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddStop = false
    @State private var showEditTrip = false
    @State private var showDeleteAlert = false
    @State private var showCloneAlert = false
    @State private var stopToDelete: TripStop?
    @State private var showInviteCollaborator = false
    @State private var viewMode: TripViewMode = .plan

    init(tripId: String) {
        self.tripId = tripId
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(tripId: tripId))
    }

    private var currentUserId: String? {
        appState.currentUser?.id
    }

    private var isOwner: Bool {
        viewModel.isOwner(currentUserId: currentUserId)
    }

    private var canEdit: Bool {
        viewModel.canEdit(currentUserId: currentUserId)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.trip == nil {
                ProgressView("Loading trip...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.trip == nil {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Could not load trip",
                    description: error,
                    buttonTitle: "Retry",
                    buttonAction: {
                        Task { await viewModel.loadTrip() }
                    }
                )
            } else if let trip = viewModel.trip {
                tripContent(trip)
            }
        }
        .invlogScreenBackground()
        .navigationTitle(viewModel.trip?.title ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let trip = viewModel.trip {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if canEdit {
                            Button {
                                showAddStop = true
                            } label: {
                                Label("Add Stop", systemImage: "plus")
                            }

                            Button {
                                showEditTrip = true
                            } label: {
                                Label("Edit Trip", systemImage: "pencil")
                            }
                        }

                        if isOwner {
                            Button {
                                showInviteCollaborator = true
                            } label: {
                                Label("Invite Collaborator", systemImage: "person.badge.plus")
                            }
                        }

                        if !isOwner && trip.visibility == "public" {
                            Button {
                                showCloneAlert = true
                            } label: {
                                Label("Clone Trip", systemImage: "doc.on.doc")
                            }
                        }

                        if isOwner {
                            Divider()
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Trip", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(InvlogTheme.body(16))
                            .foregroundColor(Color.brandText)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Trip options")
                }
            }
        }
        .sheet(isPresented: $showAddStop) {
            NavigationStack {
                AddTripStopView(
                    tripId: tripId,
                    defaultDayNumber: viewModel.maxDayNumber > 0 ? viewModel.maxDayNumber : 1,
                    defaultSortOrder: viewModel.nextSortOrder(forDay: viewModel.maxDayNumber > 0 ? viewModel.maxDayNumber : 1)
                ) {
                    Task { await viewModel.loadTrip() }
                }
            }
        }
        .sheet(isPresented: $showEditTrip) {
            if let trip = viewModel.trip {
                NavigationStack {
                    EditTripView(trip: trip) {
                        Task { await viewModel.loadTrip() }
                    }
                }
            }
        }
        .sheet(isPresented: $showInviteCollaborator) {
            NavigationStack {
                InviteCollaboratorView(tripId: tripId) {
                    Task { await viewModel.loadTrip() }
                }
            }
        }
        .alert("Delete Trip?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await APIClient.shared.requestVoid(.deleteTrip(id: tripId))
                    NotificationCenter.default.post(name: .didDeleteTrip, object: nil)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This trip and all its stops will be permanently deleted.")
        }
        .alert("Delete Stop?", isPresented: .init(
            get: { stopToDelete != nil },
            set: { if !$0 { stopToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let stop = stopToDelete {
                    Task { await viewModel.removeStop(stop.id) }
                }
            }
            Button("Cancel", role: .cancel) {
                stopToDelete = nil
            }
        } message: {
            Text("This stop will be removed from the trip.")
        }
        .alert("Clone Trip?", isPresented: $showCloneAlert) {
            Button("Clone") {
                Task {
                    if let _ = await viewModel.cloneTrip() {
                        // Trip cloned successfully -- list will refresh via notification
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A copy of this trip will be added to your trips.")
        }
        .navigationDestination(for: StopRestaurantDestination.self) { dest in
            RestaurantDetailView(restaurantSlug: dest.restaurantId)
        }
        .task {
            await viewModel.loadTrip()
        }
    }

    // MARK: - Trip Content

    @ViewBuilder
    private func tripContent(_ trip: Trip) -> some View {
        VStack(spacing: 0) {
            // Segmented Picker
            Picker("View Mode", selection: $viewMode) {
                ForEach(TripViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.vertical, InvlogTheme.Spacing.xs)

            switch viewMode {
            case .plan:
                ScrollView {
                    VStack(alignment: .leading, spacing: InvlogTheme.Spacing.md) {
                        // Hero Section
                        heroSection(trip)

                        // Error banner
                        if let error = viewModel.actionError {
                            Text(error)
                                .font(InvlogTheme.caption(12))
                                .foregroundColor(.red)
                                .padding(.horizontal, InvlogTheme.Spacing.md)
                        }

                        // Map Section
                        if let stops = trip.stops, !stops.isEmpty {
                            mapSection(stops)
                        }

                        // Stops by Day
                        if let stops = trip.stops, !stops.isEmpty {
                            stopsSection(stops)
                        } else {
                            VStack(spacing: InvlogTheme.Spacing.sm) {
                                Image(systemName: "mappin.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.brandTextTertiary)
                                Text("No stops added yet")
                                    .font(InvlogTheme.body(14))
                                    .foregroundColor(Color.brandTextSecondary)
                                if canEdit {
                                    Button("Add First Stop") {
                                        showAddStop = true
                                    }
                                    .font(InvlogTheme.body(14, weight: .bold))
                                    .foregroundColor(Color.brandPrimary)
                                    .frame(minWidth: 44, minHeight: 44)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, InvlogTheme.Spacing.xxl)
                        }

                        // Collaborators
                        if let collaborators = trip.collaborators, !collaborators.isEmpty {
                            collaboratorsSection(collaborators)
                        }

                        // Bottom spacing
                        Spacer(minLength: InvlogTheme.Spacing.xxl)
                    }
                }

            case .map:
                if let stops = trip.stops, !stops.isEmpty {
                    TripRoadmapView(stops: stops)
                } else {
                    Spacer()
                    VStack(spacing: InvlogTheme.Spacing.sm) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 32))
                            .foregroundColor(Color.brandTextTertiary)
                        Text("No stops yet")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                        Text("Add stops to see the roadmap.")
                            .font(InvlogTheme.caption(12))
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Hero Section

    private func heroSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: InvlogTheme.Spacing.sm) {
            // Cover image
            if let coverUrl = trip.coverImageUrl, let url = URL(string: coverUrl) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.brandOrangeLight)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                .padding(.horizontal, InvlogTheme.Spacing.md)
            }

            VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
                // Title
                Text(trip.title)
                    .font(InvlogTheme.heading(22))
                    .foregroundColor(Color.brandText)

                // Description
                if let desc = trip.description, !desc.isEmpty {
                    Text(desc)
                        .font(InvlogTheme.body(14))
                        .foregroundColor(Color.brandTextSecondary)
                        .lineLimit(3)
                }

                // Meta row
                HStack(spacing: InvlogTheme.Spacing.md) {
                    // Status
                    statusBadge(trip.status)

                    // Visibility
                    HStack(spacing: 4) {
                        Image(systemName: trip.visibility == "public" ? "globe" : "lock.fill")
                            .font(.caption2)
                        Text(trip.visibility.capitalized)
                            .font(InvlogTheme.caption(12))
                    }
                    .foregroundColor(Color.brandTextSecondary)

                    Spacer()
                }

                // Date range
                if let dateText = formatDateRange(start: trip.startDate, end: trip.endDate) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(Color.brandPrimary)
                        Text(dateText)
                            .font(InvlogTheme.caption(13))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                }

                // Stats
                HStack(spacing: InvlogTheme.Spacing.md) {
                    statItem(icon: "mappin", count: trip.stopCount, label: "stops")
                    statItem(icon: "heart", count: trip.likeCount, label: "likes")
                    statItem(icon: "bookmark", count: trip.saveCount, label: "saves")
                }

                // Owner
                if let owner = trip.owner {
                    HStack(spacing: InvlogTheme.Spacing.xs) {
                        if let avatarUrl = owner.avatarUrl {
                            LazyImage(url: avatarUrl) { state in
                                if let image = state.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(Color.brandTextTertiary)
                                }
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.body)
                                .foregroundColor(Color.brandTextTertiary)
                        }
                        Text(owner.displayName ?? owner.username ?? "Unknown")
                            .font(InvlogTheme.caption(13, weight: .semibold))
                            .foregroundColor(Color.brandText)
                    }
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
        }
        .padding(.top, InvlogTheme.Spacing.xs)
    }

    // MARK: - Map Section

    private func mapSection(_ stops: [TripStop]) -> some View {
        let annotations = stops.compactMap { stop -> StopAnnotation? in
            guard let lat = stop.latitude, let lng = stop.longitude else { return nil }
            return StopAnnotation(
                id: stop.id,
                name: stop.name,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                category: stop.category
            )
        }

        return VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
            HStack {
                Text("Map")
                    .font(InvlogTheme.heading(16, weight: .bold))
                    .foregroundColor(Color.brandText)
                Spacer()
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)

            if !annotations.isEmpty {
                Map(coordinateRegion: .constant(regionForAnnotations(annotations)),
                    annotationItems: annotations
                ) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: categoryIcon(annotation.category))
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.brandPrimary)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                            Text(annotation.name)
                                .font(InvlogTheme.caption(9, weight: .bold))
                                .foregroundColor(Color.brandText)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .allowsHitTesting(true)
                .accessibilityLabel("Map showing \(annotations.count) stops")
            }
        }
    }

    // MARK: - Stops Section

    private func stopsSection(_ stops: [TripStop]) -> some View {
        let grouped = Dictionary(grouping: stops) { $0.dayNumber }
        let sortedDays = grouped.keys.sorted()

        return VStack(alignment: .leading, spacing: InvlogTheme.Spacing.md) {
            ForEach(sortedDays, id: \.self) { day in
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
                    // Day header
                    HStack {
                        Text("Day \(day)")
                            .font(InvlogTheme.heading(16, weight: .bold))
                            .foregroundColor(Color.brandText)
                        Spacer()
                    }
                    .padding(.horizontal, InvlogTheme.Spacing.md)

                    // Stops for this day
                    let dayStops = (grouped[day] ?? []).sorted { $0.sortOrder < $1.sortOrder }
                    ForEach(dayStops) { stop in
                        if let restaurantId = stop.restaurantId {
                            NavigationLink(value: StopRestaurantDestination(restaurantId: restaurantId)) {
                                stopCard(stop)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, InvlogTheme.Spacing.md)
                        } else {
                            stopCard(stop)
                                .padding(.horizontal, InvlogTheme.Spacing.md)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stop Card

    private func stopCard(_ stop: TripStop) -> some View {
        HStack(alignment: .top, spacing: InvlogTheme.Spacing.sm) {
            // Category icon
            Image(systemName: categoryIcon(stop.category))
                .font(.body)
                .foregroundColor(Color.brandPrimary)
                .frame(width: 36, height: 36)
                .background(Color.brandOrangeLight)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                Text(stop.name)
                    .font(InvlogTheme.body(14, weight: .bold))
                    .foregroundColor(Color.brandText)
                    .lineLimit(1)

                if let address = stop.address, !address.isEmpty {
                    Text(address)
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(Color.brandTextSecondary)
                        .lineLimit(2)
                }

                if let notes = stop.notes, !notes.isEmpty {
                    Text(notes)
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(Color.brandTextTertiary)
                        .lineLimit(2)
                }

                // Time & duration row
                HStack(spacing: InvlogTheme.Spacing.sm) {
                    if let start = stop.startTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            if let end = stop.endTime {
                                Text("\(start) → \(end)")
                                    .font(InvlogTheme.caption(11, weight: .semibold))
                            } else {
                                Text(start)
                                    .font(InvlogTheme.caption(11, weight: .semibold))
                            }
                        }
                        .foregroundColor(Color.brandPrimary)
                    }

                    if let duration = stop.estimatedDuration, duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass")
                                .font(.caption2)
                            Text(formatDuration(duration))
                                .font(InvlogTheme.caption(11))
                        }
                        .foregroundColor(Color.brandTextSecondary)
                    }
                }

                // View place hint
                if stop.restaurantId != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2)
                        Text("View Place & Check In")
                            .font(InvlogTheme.caption(11, weight: .semibold))
                    }
                    .foregroundColor(Color.brandAccent)
                }
            }

            Spacer()

            VStack(spacing: InvlogTheme.Spacing.xs) {
                if canEdit {
                    Button(role: .destructive) {
                        stopToDelete = stop
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundColor(Color.brandTextTertiary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Remove \(stop.name)")
                }

                if stop.restaurantId != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.brandTextTertiary)
                }
            }
        }
        .padding(InvlogTheme.Card.padding)
        .invlogCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stop.name), \(stop.category)\(stop.restaurantId != nil ? ". Tap to view place." : "")")
    }

    // MARK: - Collaborators Section

    private func collaboratorsSection(_ collaborators: [TripCollaborator]) -> some View {
        VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
            HStack {
                Text("Collaborators")
                    .font(InvlogTheme.heading(16, weight: .bold))
                    .foregroundColor(Color.brandText)
                Spacer()
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)

            ForEach(collaborators) { collab in
                HStack(spacing: InvlogTheme.Spacing.sm) {
                    if let avatarUrl = collab.user?.avatarUrl {
                        LazyImage(url: avatarUrl) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(Color.brandTextTertiary)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.brandTextTertiary)
                            .frame(width: 36, height: 36)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(collab.user?.displayName ?? collab.user?.username ?? "User")
                            .font(InvlogTheme.body(14, weight: .semibold))
                            .foregroundColor(Color.brandText)
                        Text(collab.role.capitalized)
                            .font(InvlogTheme.caption(11))
                            .foregroundColor(Color.brandTextSecondary)
                    }

                    Spacer()

                    if isOwner {
                        Button(role: .destructive) {
                            Task { await viewModel.removeCollaborator(userId: collab.userId) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.brandTextTertiary)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Remove \(collab.user?.displayName ?? "collaborator")")
                    }
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.vertical, InvlogTheme.Spacing.xxs)
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(_ status: String) -> some View {
        let color: Color
        let label: String
        switch status {
        case "active":
            color = Color.brandAccent
            label = "Active"
        case "completed":
            color = Color.brandSecondary
            label = "Completed"
        default:
            color = Color.brandTextSecondary
            label = "Planning"
        }

        return Text(label)
            .font(InvlogTheme.caption(11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private func statItem(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(InvlogTheme.caption(12, weight: .bold))
            Text(label)
                .font(InvlogTheme.caption(12))
        }
        .foregroundColor(Color.brandTextSecondary)
    }

    private func formatDateRange(start: Date?, end: Date?) -> String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        if let start, let end {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start {
            return "From \(formatter.string(from: start))"
        }
        return nil
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(mins) min"
    }

    private func regionForAnnotations(_ annotations: [StopAnnotation]) -> MKCoordinateRegion {
        guard !annotations.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }

        let lats = annotations.map(\.coordinate.latitude)
        let lngs = annotations.map(\.coordinate.longitude)

        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLng = (lngs.min()! + lngs.max()!) / 2
        let spanLat = max((lats.max()! - lats.min()!) * 1.4, 0.01)
        let spanLng = max((lngs.max()! - lngs.min()!) * 1.4, 0.01)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
        )
    }
}

// MARK: - Trip View Mode

enum TripViewMode: String, CaseIterable {
    case plan = "Plan"
    case map = "Roadmap"
}

// MARK: - Stop Restaurant Destination

struct StopRestaurantDestination: Hashable {
    let restaurantId: String
}

// MARK: - Stop Annotation

private struct StopAnnotation: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: String
}

// MARK: - Category Icon Helper

func categoryIcon(_ category: String) -> String {
    switch category.lowercased() {
    case "restaurant", "dining":
        return "fork.knife"
    case "cafe", "coffee":
        return "cup.and.saucer.fill"
    case "bar", "drinks":
        return "wineglass.fill"
    case "hotel", "accommodation", "stay":
        return "bed.double.fill"
    case "attraction", "sightseeing":
        return "binoculars.fill"
    case "shopping":
        return "bag.fill"
    case "transport", "transportation":
        return "car.fill"
    case "activity", "experience":
        return "figure.walk"
    case "market", "food market":
        return "basket.fill"
    case "bakery":
        return "birthday.cake.fill"
    default:
        return "mappin"
    }
}

// MARK: - Edit Trip View (inline)

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    let onSave: () -> Void

    @State private var title: String
    @State private var description: String
    @State private var visibility: String
    @State private var status: String
    @State private var hasDateRange: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(trip: Trip, onSave: @escaping () -> Void) {
        self.trip = trip
        self.onSave = onSave
        _title = State(initialValue: trip.title)
        _description = State(initialValue: trip.description ?? "")
        _visibility = State(initialValue: trip.visibility)
        _status = State(initialValue: trip.status)
        _hasDateRange = State(initialValue: trip.startDate != nil)
        _startDate = State(initialValue: trip.startDate ?? Date())
        _endDate = State(initialValue: trip.endDate ?? Date().addingTimeInterval(86400 * 3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InvlogTheme.Spacing.lg) {
                // Title
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Title")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                    TextField("Trip name", text: $title)
                        .font(InvlogTheme.body(15))
                        .padding(InvlogTheme.Spacing.sm)
                        .background(Color.brandCard)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                        .accessibilityLabel("Trip title")
                }

                // Description
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Description")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                    TextField("Description", text: $description, axis: .vertical)
                        .font(InvlogTheme.body(15))
                        .lineLimit(3...6)
                        .padding(InvlogTheme.Spacing.sm)
                        .background(Color.brandCard)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                        .accessibilityLabel("Trip description")
                }

                // Visibility picker
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Visibility")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                    Picker("Visibility", selection: $visibility) {
                        Text("Private").tag("private")
                        Text("Public").tag("public")
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Trip visibility")
                }

                // Status picker
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Status")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)
                    Picker("Status", selection: $status) {
                        Text("Planning").tag("planning")
                        Text("Active").tag("active")
                        Text("Completed").tag("completed")
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Trip status")
                }

                // Travel Dates
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
                    Toggle(isOn: $hasDateRange) {
                        HStack(spacing: InvlogTheme.Spacing.xs) {
                            Image(systemName: "calendar")
                                .foregroundColor(Color.brandPrimary)
                            Text("Travel dates")
                                .font(InvlogTheme.body(14, weight: .semibold))
                                .foregroundColor(Color.brandText)
                        }
                    }
                    .tint(Color.brandPrimary)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Set travel dates")

                    if hasDateRange {
                        VStack(spacing: InvlogTheme.Spacing.xs) {
                            DatePicker(
                                "Start Date",
                                selection: $startDate,
                                displayedComponents: .date
                            )
                            .font(InvlogTheme.body(14))
                            .tint(Color.brandPrimary)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Start date")

                            DatePicker(
                                "End Date",
                                selection: $endDate,
                                in: startDate...,
                                displayedComponents: .date
                            )
                            .font(InvlogTheme.body(14))
                            .tint(Color.brandPrimary)
                            .frame(minHeight: 44)
                            .accessibilityLabel("End date")
                        }
                        .padding(InvlogTheme.Spacing.sm)
                        .background(Color.brandCard)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(.red)
                }
            }
            .padding(InvlogTheme.Spacing.md)
        }
        .invlogScreenBackground()
        .navigationTitle("Edit Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .frame(minWidth: 44, minHeight: 44)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .font(InvlogTheme.body(15, weight: .bold))
                .foregroundColor(Color.brandPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
    }

    private func save() async {
        isSubmitting = true
        errorMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let startDateStr = hasDateRange ? Self.dateFormatter.string(from: startDate) : nil
        let endDateStr = hasDateRange ? Self.dateFormatter.string(from: endDate) : nil

        do {
            try await APIClient.shared.requestVoid(
                .updateTrip(
                    id: trip.id,
                    title: trimmedTitle,
                    description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                    visibility: visibility,
                    status: status,
                    startDate: startDateStr,
                    endDate: endDateStr
                )
            )
            NotificationCenter.default.post(name: .didUpdateTrip, object: nil)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
