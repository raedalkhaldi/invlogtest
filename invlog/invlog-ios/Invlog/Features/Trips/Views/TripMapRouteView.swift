import SwiftUI
import MapKit

// MARK: - Map Center Request

struct MapCenterRequest: Equatable {
    let coordinate: CLLocationCoordinate2D
    let stopId: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.stopId == rhs.stopId
    }
}

// MARK: - Trip Map Route View

struct TripMapRouteView: View {
    let stops: [TripStop]

    @State private var selectedDayFilter: Int? = nil
    @State private var selectedStopId: String? = nil
    @State private var mapCenterRequest: MapCenterRequest? = nil

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
        return filtered
            .filter { $0.latitude != nil && $0.longitude != nil }
            .sorted { ($0.dayNumber, $0.sortOrder) < ($1.dayNumber, $1.sortOrder) }
    }

    var body: some View {
        VStack(spacing: 0) {
            dayFilterBar

            TripRouteMapView(
                stops: filteredStops,
                selectedStopId: $selectedStopId,
                centerRequest: $mapCenterRequest
            )
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
            .padding(.horizontal, InvlogTheme.Spacing.md)

            stopCarousel
        }
    }

    // MARK: - Day Filter Bar

    private var dayFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: InvlogTheme.Spacing.xs) {
                Button("All") {
                    selectedDayFilter = nil
                    selectedStopId = nil
                }
                .buttonStyle(InvlogFilterPillStyle(isActive: selectedDayFilter == nil))

                ForEach(dayNumbers, id: \.self) { day in
                    Button("Day \(day)") {
                        selectedDayFilter = day
                        selectedStopId = nil
                    }
                    .buttonStyle(InvlogFilterPillStyle(isActive: selectedDayFilter == day))
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
            .padding(.vertical, InvlogTheme.Spacing.xs)
        }
    }

    // MARK: - Stop Carousel

    private var stopCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InvlogTheme.Spacing.sm) {
                    ForEach(filteredStops) { stop in
                        stopCarouselCard(stop)
                            .id(stop.id)
                            .onTapGesture {
                                selectedStopId = stop.id
                                if let lat = stop.latitude, let lng = stop.longitude {
                                    mapCenterRequest = MapCenterRequest(
                                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                        stopId: stop.id
                                    )
                                }
                            }
                    }
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
                .padding(.vertical, InvlogTheme.Spacing.sm)
            }
            .onChange(of: selectedStopId) { newId in
                if let newId = newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 120)
    }

    // MARK: - Carousel Card

    private func stopCarouselCard(_ stop: TripStop) -> some View {
        VStack(alignment: .leading, spacing: InvlogTheme.Spacing.xxs) {
            HStack(spacing: InvlogTheme.Spacing.xs) {
                Image(systemName: categoryIcon(stop.category))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(dayColor(for: stop.dayNumber))
                    .clipShape(Circle())

                Text(stop.name)
                    .font(InvlogTheme.body(13, weight: .bold))
                    .foregroundColor(Color.brandText)
                    .lineLimit(1)
            }

            if let address = stop.address, !address.isEmpty {
                Text(address)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(Color.brandTextSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: InvlogTheme.Spacing.xxs) {
                Text("Day \(stop.dayNumber)")
                    .font(InvlogTheme.caption(10, weight: .bold))
                    .foregroundColor(dayColor(for: stop.dayNumber))

                if let time = stop.startTime, !time.isEmpty {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(Color.brandTextTertiary)
                    Text(time)
                        .font(InvlogTheme.caption(10))
                        .foregroundColor(Color.brandTextSecondary)
                }

                if let duration = stop.estimatedDuration, duration > 0 {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                        .foregroundColor(Color.brandTextTertiary)
                    Text(formatDuration(duration))
                        .font(InvlogTheme.caption(10))
                        .foregroundColor(Color.brandTextSecondary)
                }
            }
        }
        .padding(InvlogTheme.Spacing.sm)
        .frame(width: 160, alignment: .leading)
        .invlogCard()
        .overlay(
            RoundedRectangle(cornerRadius: InvlogTheme.Card.cornerRadius)
                .stroke(
                    selectedStopId == stop.id ? Color.brandPrimary : Color.clear,
                    lineWidth: 2
                )
        )
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}

// MARK: - Day Colors

func dayColor(for day: Int) -> Color {
    let colors: [Color] = [
        .brandPrimary,
        .brandAccent,
        .brandSecondary,
        Color(hex: 0x7048E8),
        Color(hex: 0x4C6EF5),
        Color(hex: 0xE64980),
    ]
    return colors[(day - 1) % colors.count]
}

private func dayUIColor(for day: Int) -> UIColor {
    let colors: [UIColor] = [
        UIColor(red: 232/255, green: 89/255, blue: 12/255, alpha: 1),   // brandPrimary
        UIColor(red: 18/255, green: 184/255, blue: 134/255, alpha: 1),  // brandAccent
        UIColor(red: 245/255, green: 159/255, blue: 0/255, alpha: 1),   // brandSecondary
        UIColor(red: 112/255, green: 72/255, blue: 232/255, alpha: 1),  // purple
        UIColor(red: 76/255, green: 110/255, blue: 245/255, alpha: 1),  // blue
        UIColor(red: 230/255, green: 73/255, blue: 128/255, alpha: 1),  // pink
    ]
    return colors[(day - 1) % colors.count]
}

// MARK: - MKAnnotation Subclass

class StopPointAnnotation: NSObject, MKAnnotation {
    let stopId: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let category: String
    let dayNumber: Int

    init(stopId: String, coordinate: CLLocationCoordinate2D, name: String, category: String, dayNumber: Int) {
        self.stopId = stopId
        self.coordinate = coordinate
        self.title = name
        self.category = category
        self.dayNumber = dayNumber
    }
}

// MARK: - Day Polyline

class DayPolyline: MKPolyline {
    var dayNumber: Int = 0
}

// MARK: - Trip Route Map View (UIViewRepresentable)

struct TripRouteMapView: UIViewRepresentable {
    let stops: [TripStop]
    @Binding var selectedStopId: String?
    @Binding var centerRequest: MapCenterRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        updateAnnotations(on: mapView)
        updateOverlays(on: mapView)

        if let request = centerRequest {
            let region = MKCoordinateRegion(
                center: request.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async { centerRequest = nil }
        } else if context.coordinator.needsFitAll {
            fitAllAnnotations(on: mapView)
            context.coordinator.needsFitAll = false
        }
    }

    // MARK: - Annotation Updates

    private func updateAnnotations(on mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? StopPointAnnotation }
        let existingIds = Set(existing.map(\.stopId))
        let newIds = Set(stops.compactMap { $0.latitude != nil ? $0.id : nil })

        // Remove stale
        let toRemove = existing.filter { !newIds.contains($0.stopId) }
        mapView.removeAnnotations(toRemove)

        // Add new
        let toAdd = stops.filter { stop in
            guard let lat = stop.latitude, let lng = stop.longitude else { return false }
            return !existingIds.contains(stop.id) && lat != 0 && lng != 0
        }
        for stop in toAdd {
            guard let lat = stop.latitude, let lng = stop.longitude else { continue }
            let annotation = StopPointAnnotation(
                stopId: stop.id,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                name: stop.name,
                category: stop.category,
                dayNumber: stop.dayNumber
            )
            mapView.addAnnotation(annotation)
        }

        // Update selection appearance
        for annotation in mapView.annotations.compactMap({ $0 as? StopPointAnnotation }) {
            if let view = mapView.view(for: annotation) {
                let isSelected = annotation.stopId == selectedStopId
                UIView.animate(withDuration: 0.2) {
                    view.transform = isSelected ? CGAffineTransform(scaleX: 1.3, y: 1.3) : .identity
                }
            }
        }
    }

    // MARK: - Overlay Updates

    private func updateOverlays(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)

        let withCoords = stops.filter { $0.latitude != nil && $0.longitude != nil }
        let grouped = Dictionary(grouping: withCoords) { $0.dayNumber }

        for (day, dayStops) in grouped.sorted(by: { $0.key < $1.key }) {
            let sorted = dayStops.sorted { $0.sortOrder < $1.sortOrder }
            let coords = sorted.compactMap { stop -> CLLocationCoordinate2D? in
                guard let lat = stop.latitude, let lng = stop.longitude else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            guard coords.count >= 2 else { continue }

            var mutableCoords = coords
            let polyline = DayPolyline(coordinates: &mutableCoords, count: mutableCoords.count)
            polyline.dayNumber = day
            mapView.addOverlay(polyline)
        }
    }

    // MARK: - Fit All

    private func fitAllAnnotations(on mapView: MKMapView) {
        let annotations = mapView.annotations.compactMap { $0 as? StopPointAnnotation }
        guard !annotations.isEmpty else { return }

        var minLat = annotations[0].coordinate.latitude
        var maxLat = minLat
        var minLng = annotations[0].coordinate.longitude
        var maxLng = minLng

        for annotation in annotations {
            minLat = min(minLat, annotation.coordinate.latitude)
            maxLat = max(maxLat, annotation.coordinate.latitude)
            minLng = min(minLng, annotation.coordinate.longitude)
            maxLng = max(maxLng, annotation.coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.01)
        )
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TripRouteMapView
        var needsFitAll = true

        init(_ parent: TripRouteMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let stopAnnotation = annotation as? StopPointAnnotation else { return nil }

            let identifier = "StopPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation

            let size: CGFloat = 32
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            let image = renderer.image { ctx in
                let color = dayUIColor(for: stopAnnotation.dayNumber)
                color.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))

                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
                if let symbol = UIImage(systemName: categoryIcon(stopAnnotation.category), withConfiguration: config) {
                    let tinted = symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
                    let symbolSize = tinted.size
                    let origin = CGPoint(
                        x: (size - symbolSize.width) / 2,
                        y: (size - symbolSize.height) / 2
                    )
                    tinted.draw(at: origin)
                }
            }
            view.image = image
            view.centerOffset = CGPoint(x: 0, y: -size / 2)
            view.canShowCallout = false

            let isSelected = stopAnnotation.stopId == parent.selectedStopId
            view.transform = isSelected ? CGAffineTransform(scaleX: 1.3, y: 1.3) : .identity

            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? DayPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = dayUIColor(for: polyline.dayNumber)
                renderer.lineWidth = 3
                renderer.lineDashPattern = [8, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let stopAnnotation = view.annotation as? StopPointAnnotation else { return }
            parent.selectedStopId = stopAnnotation.stopId
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
}
