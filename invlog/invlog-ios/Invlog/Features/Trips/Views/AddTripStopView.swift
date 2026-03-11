import SwiftUI
import MapKit

struct AddTripStopView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()

    let tripId: String
    let defaultDayNumber: Int
    let defaultSortOrder: Int
    let onStopAdded: () -> Void

    @State private var selectedPlace: SelectedPlace?
    @State private var dayNumber: Int
    @State private var notes = ""
    @State private var category = "restaurant"
    @State private var estimatedDuration: Int = 60
    @State private var hasStartTime = false
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 10, minute: 0))!
    @State private var showPlacePicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let categories = [
        ("restaurant", "Restaurant", "fork.knife"),
        ("cafe", "Cafe", "cup.and.saucer.fill"),
        ("bar", "Bar", "wineglass.fill"),
        ("bakery", "Bakery", "birthday.cake.fill"),
        ("market", "Market", "basket.fill"),
        ("attraction", "Attraction", "binoculars.fill"),
        ("hotel", "Hotel", "bed.double.fill"),
        ("shopping", "Shopping", "bag.fill"),
        ("activity", "Activity", "figure.walk"),
        ("transport", "Transport", "car.fill"),
    ]

    private let durations = [15, 30, 45, 60, 90, 120, 180, 240]

    init(tripId: String, defaultDayNumber: Int, defaultSortOrder: Int, onStopAdded: @escaping () -> Void) {
        self.tripId = tripId
        self.defaultDayNumber = defaultDayNumber
        self.defaultSortOrder = defaultSortOrder
        self.onStopAdded = onStopAdded
        _dayNumber = State(initialValue: defaultDayNumber)
    }

    private var canSubmit: Bool {
        selectedPlace != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InvlogTheme.Spacing.lg) {
                // Place Selection
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Place *")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    Button {
                        showPlacePicker = true
                    } label: {
                        HStack(spacing: InvlogTheme.Spacing.sm) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color.brandPrimary)

                            if let place = selectedPlace {
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
                                }
                            } else {
                                Text("Search for a place")
                                    .font(InvlogTheme.body(14))
                                    .foregroundColor(Color.brandTextSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color.brandTextTertiary)
                        }
                        .padding(InvlogTheme.Spacing.sm)
                        .background(Color.brandCard)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel(selectedPlace != nil ? "Place: \(selectedPlace!.name). Tap to change." : "Select a place")
                }

                // Day Number
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Day")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    Stepper(value: $dayNumber, in: 1...99) {
                        HStack(spacing: InvlogTheme.Spacing.xs) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(Color.brandPrimary)
                            Text("Day \(dayNumber)")
                                .font(InvlogTheme.body(14, weight: .semibold))
                                .foregroundColor(Color.brandText)
                        }
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Day number \(dayNumber)")
                }

                // Category
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
                    Text("Category")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 90), spacing: InvlogTheme.Spacing.xs)
                    ], spacing: InvlogTheme.Spacing.xs) {
                        ForEach(categories, id: \.0) { cat in
                            Button {
                                category = cat.0
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: cat.2)
                                        .font(.body)
                                    Text(cat.1)
                                        .font(InvlogTheme.caption(11, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, InvlogTheme.Spacing.xs)
                                .background(category == cat.0 ? Color.brandOrangeLight : Color.brandCard)
                                .foregroundColor(category == cat.0 ? Color.brandPrimary : Color.brandTextSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                        .stroke(category == cat.0 ? Color.brandPrimary : Color.brandBorder, lineWidth: category == cat.0 ? 2 : 1)
                                )
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel(cat.1)
                            .accessibilityAddTraits(category == cat.0 ? .isSelected : [])
                        }
                    }
                }

                // Estimated Duration
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Estimated Duration")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: InvlogTheme.Spacing.xs) {
                            ForEach(durations, id: \.self) { dur in
                                Button {
                                    estimatedDuration = dur
                                } label: {
                                    Text(formatDuration(dur))
                                        .font(InvlogTheme.caption(13, weight: .semibold))
                                        .padding(.horizontal, InvlogTheme.Spacing.sm)
                                        .padding(.vertical, InvlogTheme.Spacing.xs)
                                        .background(estimatedDuration == dur ? Color.brandOrangeLight : Color.brandCard)
                                        .foregroundColor(estimatedDuration == dur ? Color.brandPrimary : Color.brandTextSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(estimatedDuration == dur ? Color.brandPrimary : Color.brandBorder, lineWidth: estimatedDuration == dur ? 2 : 1)
                                        )
                                }
                                .frame(minHeight: 44)
                                .accessibilityLabel("\(formatDuration(dur)) duration")
                                .accessibilityAddTraits(estimatedDuration == dur ? .isSelected : [])
                            }
                        }
                    }
                }

                // Start Time
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
                    Toggle(isOn: $hasStartTime) {
                        HStack(spacing: InvlogTheme.Spacing.xs) {
                            Image(systemName: "clock")
                                .foregroundColor(Color.brandPrimary)
                            Text("Set start time")
                                .font(InvlogTheme.body(14, weight: .semibold))
                                .foregroundColor(Color.brandText)
                        }
                    }
                    .tint(Color.brandPrimary)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Set start time for this stop")

                    if hasStartTime {
                        VStack(spacing: InvlogTheme.Spacing.xs) {
                            DatePicker(
                                "Start Time",
                                selection: $startTime,
                                displayedComponents: .hourAndMinute
                            )
                            .font(InvlogTheme.body(14))
                            .tint(Color.brandPrimary)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Start time")

                            // Show computed end time
                            HStack {
                                Text("End Time")
                                    .font(InvlogTheme.body(14))
                                    .foregroundColor(Color.brandTextSecondary)
                                Spacer()
                                Text(computedEndTimeString)
                                    .font(InvlogTheme.body(14, weight: .semibold))
                                    .foregroundColor(Color.brandPrimary)
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel("Computed end time: \(computedEndTimeString)")
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

                // Notes
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Notes")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    TextField("Any notes for this stop?", text: $notes, axis: .vertical)
                        .font(InvlogTheme.body(15))
                        .lineLimit(2...5)
                        .padding(InvlogTheme.Spacing.sm)
                        .background(Color.brandCard)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                        .accessibilityLabel("Stop notes")
                }

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(InvlogTheme.caption(12))
                        .foregroundColor(.red)
                }
            }
            .padding(InvlogTheme.Spacing.md)
        }
        .invlogScreenBackground()
        .navigationTitle("Add Stop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .frame(minWidth: 44, minHeight: 44)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task { await addStop() }
                }
                .font(InvlogTheme.body(15, weight: .bold))
                .foregroundColor(Color.brandPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .sheet(isPresented: $showPlacePicker) {
            PlacePickerView(selectedPlace: $selectedPlace)
        }
    }

    // MARK: - Submit

    private func addStop() async {
        guard let place = selectedPlace else { return }
        isSubmitting = true
        errorMessage = nil

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Ensure we have a restaurantId — create one if the place doesn't have one
            var restaurantId = place.restaurantId
            if restaurantId == nil {
                let (restaurant, _) = try await APIClient.shared.requestWrapped(
                    .createRestaurant(data: [
                        "name": place.name,
                        "latitude": place.latitude,
                        "longitude": place.longitude,
                        "addressLine1": place.address,
                    ]),
                    responseType: Restaurant.self
                )
                restaurantId = restaurant.id
            }

            try await APIClient.shared.requestVoid(
                .addTripStop(
                    tripId: tripId,
                    name: place.name,
                    restaurantId: restaurantId,
                    address: place.address.isEmpty ? nil : place.address,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    dayNumber: dayNumber,
                    sortOrder: defaultSortOrder,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    category: category,
                    estimatedDuration: estimatedDuration,
                    startTime: hasStartTime ? Self.timeFormatter.string(from: startTime) : nil,
                    endTime: hasStartTime ? computedEndTimeString : nil
                )
            )
            onStopAdded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    // MARK: - Helpers

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var computedEndTimeString: String {
        let endDate = startTime.addingTimeInterval(TimeInterval(estimatedDuration * 60))
        return Self.timeFormatter.string(from: endDate)
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
}
