import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 3)
    @State private var hasDateRange = false
    @State private var isPublic = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showDiscardAlert = false

    private var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InvlogTheme.Spacing.lg) {
                // Title
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Trip Name *")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    TextField("e.g. Tokyo Food Tour", text: $title)
                        .font(InvlogTheme.body(15))
                        .padding(InvlogTheme.Spacing.sm)
                        .background(Color.brandCard)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                        .accessibilityLabel("Trip name")
                }

                // Description
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Description")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    TextField("What's this trip about?", text: $description, axis: .vertical)
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

                // Date Range Toggle
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xs) {
                    Toggle(isOn: $hasDateRange) {
                        HStack(spacing: InvlogTheme.Spacing.xs) {
                            Image(systemName: "calendar")
                                .foregroundColor(Color.brandPrimary)
                            Text("Set travel dates")
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

                // Visibility
                VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
                    Text("Visibility")
                        .font(InvlogTheme.caption(13, weight: .bold))
                        .foregroundColor(Color.brandTextSecondary)

                    HStack(spacing: InvlogTheme.Spacing.sm) {
                        visibilityOption(
                            icon: "lock.fill",
                            label: "Private",
                            subtitle: "Only you and collaborators",
                            isSelected: !isPublic
                        ) {
                            isPublic = false
                        }

                        visibilityOption(
                            icon: "globe",
                            label: "Public",
                            subtitle: "Anyone can discover",
                            isSelected: isPublic
                        ) {
                            isPublic = true
                        }
                    }
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
        .navigationTitle("New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasContent {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task { await createTrip() }
                }
                .font(InvlogTheme.body(15, weight: .bold))
                .foregroundColor(Color.brandPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!hasContent || isSubmitting)
            }
        }
        .alert("Discard Trip?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your trip details will be lost if you go back.")
        }
        .interactiveDismissDisabled(hasContent)
    }

    // MARK: - Visibility Option

    private func visibilityOption(
        icon: String,
        label: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: InvlogTheme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? Color.brandPrimary : Color.brandTextTertiary)
                Text(label)
                    .font(InvlogTheme.body(13, weight: .bold))
                    .foregroundColor(isSelected ? Color.brandText : Color.brandTextSecondary)
                Text(subtitle)
                    .font(InvlogTheme.caption(10))
                    .foregroundColor(Color.brandTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(InvlogTheme.Spacing.sm)
            .background(isSelected ? Color.brandOrangeLight : Color.brandCard)
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                    .stroke(isSelected ? Color.brandPrimary : Color.brandBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .frame(minHeight: 44)
        .accessibilityLabel("\(label) visibility")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Submit

    private func createTrip() async {
        isSubmitting = true
        errorMessage = nil

        let visibility = isPublic ? "public" : "private"
        let startDateStr = hasDateRange ? Self.dateFormatter.string(from: startDate) : nil
        let endDateStr = hasDateRange ? Self.dateFormatter.string(from: endDate) : nil
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await APIClient.shared.requestVoid(
                .createTrip(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: desc.isEmpty ? nil : desc,
                    startDate: startDateStr,
                    endDate: endDateStr,
                    visibility: visibility
                )
            )
            NotificationCenter.default.post(name: .didCreateTrip, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
