import SwiftUI

// MARK: - Filter Model

struct FeedFilters {
    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case top = "Top Rated"
        case nearby = "Nearby"
    }

    var sort: SortOption = .newest
    var minRating: Int? = nil
    var cuisineTypes: Set<String> = []

    var isActive: Bool {
        sort != .newest || minRating != nil || !cuisineTypes.isEmpty
    }

    func apply(to posts: [Post]) -> [Post] {
        var result = posts

        // Rating filter
        if let min = minRating {
            result = result.filter { ($0.rating ?? 0) >= min }
        }

        // Sort
        switch sort {
        case .newest: break // already sorted by API
        case .top: result.sort { ($0.likeCount ) > ($1.likeCount ) }
        case .nearby: break // would need location data
        }

        return result
    }
}

// MARK: - Filter Sheet View

struct FeedFilterSheet: View {
    @Binding var filters: FeedFilters
    @Environment(\.dismiss) private var dismiss

    private let commonCuisines = ["Italian", "Japanese", "Mexican", "Chinese", "Indian", "Thai", "American", "Korean", "Mediterranean", "Vietnamese"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Reset") {
                    filters = FeedFilters()
                }
                .font(InvlogTheme.body(14))
                .foregroundColor(Color.brandPrimary)
                .frame(minWidth: 44, minHeight: 44)

                Spacer()

                Text("Filter Feed")
                    .font(InvlogTheme.body(16, weight: .bold))
                    .foregroundColor(Color.brandText)

                Spacer()

                Button("Done") { dismiss() }
                    .font(InvlogTheme.body(14, weight: .semibold))
                    .foregroundColor(Color.brandPrimary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 12)

            Divider().padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Sort section
                    sectionHeader("Sort By")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FeedFilters.SortOption.allCases, id: \.self) { option in
                                Button {
                                    filters.sort = option
                                } label: {
                                    Text(option.rawValue)
                                }
                                .buttonStyle(InvlogFilterPillStyle(isActive: filters.sort == option))
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Rating section
                    sectionHeader("Minimum Rating")
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                filters.minRating = (filters.minRating == star) ? nil : star
                            } label: {
                                Image(systemName: star <= (filters.minRating ?? 0) ? "star.fill" : "star")
                                    .font(.system(size: 24))
                                    .foregroundColor(star <= (filters.minRating ?? 0) ? Color.brandSecondary : Color.brandBorder)
                            }
                            .buttonStyle(.plain)
                        }

                        if filters.minRating != nil {
                            Text("\(filters.minRating!)+ stars")
                                .font(InvlogTheme.caption(12))
                                .foregroundColor(Color.brandTextSecondary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal)

                    // Cuisine section
                    sectionHeader("Cuisine")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonCuisines, id: \.self) { cuisine in
                                Button {
                                    if filters.cuisineTypes.contains(cuisine) {
                                        filters.cuisineTypes.remove(cuisine)
                                    } else {
                                        filters.cuisineTypes.insert(cuisine)
                                    }
                                } label: {
                                    Text(cuisine)
                                }
                                .buttonStyle(InvlogFilterPillStyle(isActive: filters.cuisineTypes.contains(cuisine)))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
            }
        }
        .background(Color.brandCard)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(InvlogTheme.body(14, weight: .bold))
            .foregroundColor(Color.brandText)
            .padding(.horizontal)
    }
}
