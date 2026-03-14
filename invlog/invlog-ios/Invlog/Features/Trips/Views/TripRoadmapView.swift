import SwiftUI

struct TripRoadmapView: View {
    let stops: [TripStop]

    @State private var selectedDayFilter: Int? = nil

    private var dayNumbers: [Int] {
        Array(Set(stops.map(\.dayNumber))).sorted()
    }

    private var filteredStops: [TripStop] {
        let filtered: [TripStop]
        if let day = selectedDayFilter {
            filtered = stops.filter { $0.dayNumber == day }
        } else {
            filtered = stops
        }
        return filtered.sorted { ($0.dayNumber, $0.sortOrder) < ($1.dayNumber, $1.sortOrder) }
    }

    var body: some View {
        VStack(spacing: 0) {
            dayFilterBar

            ScrollView {
                if filteredStops.isEmpty {
                    VStack(spacing: InvlogTheme.Spacing.sm) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 32))
                            .foregroundColor(Color.brandTextTertiary)
                        Text("No stops to display")
                            .font(InvlogTheme.body(14))
                            .foregroundColor(Color.brandTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    roadmapContent
                }
            }
        }
    }

    // MARK: - Day Filter Bar

    private var dayFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: InvlogTheme.Spacing.xs) {
                Button("All") {
                    selectedDayFilter = nil
                }
                .buttonStyle(InvlogFilterPillStyle(isActive: selectedDayFilter == nil))

                ForEach(dayNumbers, id: \.self) { day in
                    Button("Day \(day)") {
                        selectedDayFilter = day
                    }
                    .buttonStyle(InvlogFilterPillStyle(isActive: selectedDayFilter == day))
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.vertical, InvlogTheme.Spacing.xs)
        }
    }

    // MARK: - Roadmap Content

    private var roadmapContent: some View {
        VStack(spacing: 0) {
            // Start marker
            startMarker
                .padding(.top, InvlogTheme.Spacing.lg)

            ForEach(Array(filteredStops.enumerated()), id: \.element.id) { index, stop in
                let isLeft = index % 2 == 0
                let color = dayColor(for: stop.dayNumber)
                let isLast = index == filteredStops.count - 1

                // Connecting path segment
                RoadmapConnector(isLeft: isLeft, color: color)
                    .frame(height: 50)

                // Stop node
                RoadmapStopNode(
                    stop: stop,
                    index: index + 1,
                    isLeft: isLeft,
                    color: color,
                    isLast: isLast
                )
            }

            // End marker
            if !filteredStops.isEmpty {
                endMarker
                    .padding(.top, InvlogTheme.Spacing.sm)
                    .padding(.bottom, InvlogTheme.Spacing.xxl)
            }
        }
        .padding(.horizontal, InvlogTheme.Spacing.md)
    }

    // MARK: - Start / End Markers

    private var startMarker: some View {
        VStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 18))
                .foregroundColor(Color.brandPrimary)
            Text("START")
                .font(InvlogTheme.caption(10, weight: .bold))
                .foregroundColor(Color.brandPrimary)
                .tracking(1.5)
        }
        .frame(width: 60, height: 60)
        .background(Color.brandOrangeLight)
        .clipShape(Circle())
    }

    private var endMarker: some View {
        VStack(spacing: 4) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 18))
                .foregroundColor(Color.brandAccent)
            Text("END")
                .font(InvlogTheme.caption(10, weight: .bold))
                .foregroundColor(Color.brandAccent)
                .tracking(1.5)
        }
        .frame(width: 60, height: 60)
        .background(Color.brandTealLight)
        .clipShape(Circle())
    }
}

// MARK: - Connector (dashed curved line between stops)

private struct RoadmapConnector: View {
    let isLeft: Bool
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let midX = width / 2

            Path { path in
                // Curve from center to the side, then back toward center on the other side
                let startX = midX
                let endX = midX + (isLeft ? -width * 0.25 : width * 0.25)

                path.move(to: CGPoint(x: startX, y: 0))
                path.addCurve(
                    to: CGPoint(x: endX, y: height),
                    control1: CGPoint(x: startX, y: height * 0.4),
                    control2: CGPoint(x: endX, y: height * 0.6)
                )
            }
            .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))
            .foregroundColor(color.opacity(0.5))
        }
    }
}

// MARK: - Stop Node (the card for each stop on the roadmap)

private struct RoadmapStopNode: View {
    let stop: TripStop
    let index: Int
    let isLeft: Bool
    let color: Color
    let isLast: Bool

    var body: some View {
        HStack(spacing: 0) {
            if !isLeft {
                Spacer()
            }

            // Card side
            stopCard
                .frame(maxWidth: UIScreen.main.bounds.width * 0.52)

            if !isLeft {
                Spacer().frame(width: InvlogTheme.Spacing.sm)
            }

            // Center node (numbered circle)
            nodeCircle

            if isLeft {
                Spacer().frame(width: InvlogTheme.Spacing.sm)
            }

            if isLeft {
                Spacer()
            }
        }
    }

    private var nodeCircle: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)

            Text("\(index)")
                .font(InvlogTheme.caption(13, weight: .bold))
                .foregroundColor(.white)
        }
        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private var stopCard: some View {
        Group {
            if let restaurantId = stop.restaurantId {
                NavigationLink(value: StopRestaurantDestination(restaurantId: restaurantId)) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: isLeft ? .trailing : .leading, spacing: 4) {
            // Category + Name
            HStack(spacing: 6) {
                if !isLeft {
                    categoryBadge
                }

                Text(stop.name)
                    .font(InvlogTheme.body(14, weight: .bold))
                    .foregroundColor(Color.brandText)
                    .lineLimit(2)
                    .multilineTextAlignment(isLeft ? .trailing : .leading)

                if isLeft {
                    categoryBadge
                }
            }

            // Address
            if let address = stop.address, !address.isEmpty {
                Text(address)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextSecondary)
                    .lineLimit(1)
                    .multilineTextAlignment(isLeft ? .trailing : .leading)
            }

            // Meta row: Day badge + time
            HStack(spacing: 6) {
                if isLeft { Spacer() }

                Text("Day \(stop.dayNumber)")
                    .font(InvlogTheme.caption(10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .clipShape(Capsule())

                if let time = stop.startTime, !time.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(time)
                            .font(InvlogTheme.caption(10))
                    }
                    .foregroundColor(Color.brandTextTertiary)
                }

                if let duration = stop.estimatedDuration, duration > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9))
                        Text(formatDuration(duration))
                            .font(InvlogTheme.caption(10))
                    }
                    .foregroundColor(Color.brandTextTertiary)
                }

                if !isLeft { Spacer() }
            }

            // Notes
            if let notes = stop.notes, !notes.isEmpty {
                Text(notes)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(isLeft ? .trailing : .leading)
            }

            // Tap hint for linked restaurants
            if stop.restaurantId != nil {
                HStack(spacing: 4) {
                    if isLeft { Spacer() }
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 10))
                    Text("View Place")
                        .font(InvlogTheme.caption(11, weight: .semibold))
                    if !isLeft { Spacer() }
                }
                .foregroundColor(Color.brandAccent)
            }
        }
        .padding(InvlogTheme.Spacing.sm)
        .background(Color.brandCard)
        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: InvlogTheme.Radius.md)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var categoryBadge: some View {
        Image(systemName: categoryIcon(stop.category))
            .font(.system(size: 12))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(color)
            .clipShape(Circle())
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}
