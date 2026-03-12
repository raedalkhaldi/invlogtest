import SwiftUI
@preconcurrency import NukeUI

struct MyTripsView: View {
    @StateObject private var viewModel = TripsViewModel()
    @State private var showCreateTrip = false
    @State private var tripToDelete: Trip?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.trips.isEmpty {
                ProgressView("Loading trips...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.trips.isEmpty {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Something went wrong",
                    description: error,
                    buttonTitle: "Try Again",
                    buttonAction: {
                        Task { await viewModel.refresh() }
                    }
                )
            } else if viewModel.trips.isEmpty {
                EmptyStateView(
                    systemImage: "map",
                    title: "No trips yet",
                    description: "Plan your first food trip and keep track of all the places you want to visit.",
                    buttonTitle: "Create Trip",
                    buttonAction: { showCreateTrip = true }
                )
            } else {
                tripsList
            }
        }
        .invlogScreenBackground()
        .navigationTitle("My Trips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                        .font(InvlogTheme.body(16, weight: .bold))
                        .foregroundColor(Color.brandPrimary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Create new trip")
            }
        }
        .sheet(isPresented: $showCreateTrip) {
            NavigationStack {
                CreateTripView()
            }
        }
        .alert("Delete Trip?", isPresented: .init(
            get: { tripToDelete != nil },
            set: { if !$0 { tripToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let trip = tripToDelete {
                    Task { await viewModel.deleteTrip(trip) }
                }
            }
            Button("Cancel", role: .cancel) {
                tripToDelete = nil
            }
        } message: {
            Text("This trip and all its stops will be permanently deleted.")
        }
        .task {
            await viewModel.loadMyTrips()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didCreateTrip)) { _ in
            Task { await viewModel.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateTrip)) { _ in
            Task { await viewModel.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didDeleteTrip)) { _ in
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Trips List

    private var tripsList: some View {
        List {
            ForEach(viewModel.trips) { trip in
                NavigationLink(value: trip) {
                    TripCardView(trip: trip)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        tripToDelete = trip
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onAppear {
                    if trip.id == viewModel.trips.last?.id && viewModel.hasMore {
                        Task { await viewModel.loadMoreMyTrips() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(tripId: trip.id)
        }
    }
}

// MARK: - Trip Card View

struct TripCardView: View {
    let trip: Trip

    private var dateRangeText: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        if let start = trip.startDate, let end = trip.endDate {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = trip.startDate {
            return "From \(formatter.string(from: start))"
        }
        return nil
    }

    private var statusColor: Color {
        switch trip.status {
        case "active": return Color.brandAccent
        case "completed": return Color.brandSecondary
        default: return Color.brandTextSecondary
        }
    }

    private var statusLabel: String {
        switch trip.status {
        case "planning": return "Planning"
        case "active": return "Active"
        case "completed": return "Completed"
        default: return trip.status.capitalized
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
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
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            }

            // Title row
            HStack(alignment: .center, spacing: InvlogTheme.Spacing.xs) {
                Text(trip.title)
                    .font(InvlogTheme.heading(16, weight: .bold))
                    .foregroundColor(Color.brandText)
                    .lineLimit(1)

                Spacer()

                // Visibility icon
                Image(systemName: trip.visibility == "public" ? "globe" : "lock.fill")
                    .font(.caption)
                    .foregroundColor(Color.brandTextTertiary)
                    .accessibilityLabel(trip.visibility == "public" ? "Public trip" : "Private trip")
            }

            // Date range
            if let dateRange = dateRangeText {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(Color.brandTextSecondary)
                    Text(dateRange)
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(Color.brandTextSecondary)
                        .lineLimit(1)
                }
            }

            // Bottom row: status badge + stop count
            HStack(spacing: InvlogTheme.Spacing.sm) {
                // Status badge
                Text(statusLabel)
                    .font(InvlogTheme.caption(11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor)
                    .clipShape(Capsule())

                // Stop count
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text("\(trip.stopCount) stop\(trip.stopCount == 1 ? "" : "s")")
                        .font(InvlogTheme.caption(12))
                }
                .foregroundColor(Color.brandTextSecondary)

                Spacer()
            }
        }
        .padding(InvlogTheme.Card.padding)
        .invlogCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.title), \(statusLabel), \(trip.stopCount) stops")
    }
}
