import SwiftUI
import CoreImage

// MARK: - Photo Filter View
// Reuses VideoFilter enum and VideoFilterView.applyCIFilter for consistency.

struct ImageFilterView: View {
    let images: [UIImage]
    let onComplete: ([UIImage]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: VideoFilter = .original
    @State private var selectedFilterIndex: Int = 0
    @State private var filterThumbnails: [VideoFilter: UIImage] = [:]
    @State private var filteredPreview: UIImage?
    @State private var isExporting = false
    @State private var dragOffset: CGFloat = 0

    private let ciContext = CIContext()
    private var previewSource: UIImage { images.first ?? UIImage() }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                imagePreviewSection
                filterCarouselSection
            }

            if isExporting {
                exportOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
                    .foregroundColor(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Use This") { handleExport() }
                    .font(InvlogTheme.body(15, weight: .bold))
                    .foregroundColor(Color.brandPrimary)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(isExporting)
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { generateFilterThumbnails() }
    }

    // MARK: - Image Preview

    private var imagePreviewSection: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * (5.0 / 4.0)
            let displayImage = filteredPreview ?? previewSource

            ZStack {
                Color.black

                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))

                // Filter name pill
                VStack {
                    Spacer()
                    Text(selectedFilter.rawValue)
                        .font(InvlogTheme.body(14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    // MARK: - Filter Carousel

    private var filterCarouselSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: InvlogTheme.Spacing.md)

            GeometryReader { geo in
                let itemWidth: CGFloat = 80
                let spacing: CGFloat = 12
                let totalItemWidth = itemWidth + spacing
                let centerOffset = (geo.size.width - itemWidth) / 2

                HStack(spacing: spacing) {
                    ForEach(Array(VideoFilter.allCases.enumerated()), id: \.element) { index, filter in
                        filterItem(filter: filter, index: index)
                            .frame(width: itemWidth)
                    }
                }
                .offset(x: centerOffset - CGFloat(selectedFilterIndex) * totalItemWidth + dragOffset)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: selectedFilterIndex)
                .gesture(
                    DragGesture()
                        .onChanged { value in dragOffset = value.translation.width }
                        .onEnded { value in
                            let threshold = totalItemWidth * 0.3
                            var newIndex = selectedFilterIndex
                            if value.translation.width < -threshold {
                                newIndex = min(selectedFilterIndex + 1, VideoFilter.allCases.count - 1)
                            } else if value.translation.width > threshold {
                                newIndex = max(selectedFilterIndex - 1, 0)
                            }
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            if velocity < -100 { newIndex = min(newIndex + 1, VideoFilter.allCases.count - 1) }
                            else if velocity > 100 { newIndex = max(newIndex - 1, 0) }
                            dragOffset = 0
                            selectFilter(VideoFilter.allCases[newIndex], at: newIndex)
                        }
                )
            }
            .frame(height: 100)

            HStack(spacing: 4) {
                ForEach(0..<VideoFilter.allCases.count, id: \.self) { i in
                    Circle()
                        .fill(i == selectedFilterIndex ? Color.brandPrimary : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.top, 8)

            Spacer().frame(height: InvlogTheme.Spacing.lg)
        }
        .background(Color.black)
    }

    private func filterItem(filter: VideoFilter, index: Int) -> some View {
        let isSelected = selectedFilterIndex == index
        return Button {
            selectFilter(filter, at: index)
        } label: {
            VStack(spacing: 6) {
                if let thumb = filterThumbnails[filter] {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm)
                                .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 2)
                        )
                        .scaleEffect(isSelected ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                } else {
                    Image(uiImage: previewSource)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                        .scaleEffect(isSelected ? 1.1 : 0.9)
                }

                Text(filter.rawValue)
                    .font(InvlogTheme.caption(10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color.brandPrimary : Color.brandTextSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.rawValue) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Export Overlay

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: InvlogTheme.Spacing.sm) {
                ProgressView().tint(.white).scaleEffect(1.2)
                Text("Applying filter...")
                    .font(InvlogTheme.body(14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(InvlogTheme.Spacing.xl)
            .background(Color.brandText.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
        }
    }

    // MARK: - Filter Selection

    private func selectFilter(_ filter: VideoFilter, at index: Int) {
        selectedFilterIndex = index
        selectedFilter = filter

        if filter == .original {
            filteredPreview = nil
            return
        }

        // Update preview in background
        let source = previewSource
        let ctx = ciContext
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let ci = CIImage(image: source) else { return nil }
                let filtered = VideoFilterView.applyCIFilter(to: ci, filter: filter)
                if let cg = ctx.createCGImage(filtered, from: filtered.extent) {
                    return UIImage(cgImage: cg)
                }
                return nil
            }.value
            await MainActor.run { filteredPreview = result }
        }
    }

    // MARK: - Thumbnail Generation

    private func generateFilterThumbnails() {
        let source = previewSource
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> [VideoFilter: UIImage] in
                guard let ciImage = CIImage(image: source) else { return [:] }
                // Scale down for thumbnails
                let scale = min(150.0 / source.size.width, 150.0 / source.size.height, 1.0)
                let scaledCI = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                let context = CIContext()
                var thumbs: [VideoFilter: UIImage] = [:]
                for filter in VideoFilter.allCases {
                    let filtered = VideoFilterView.applyCIFilter(to: scaledCI, filter: filter)
                    if let cg = context.createCGImage(filtered, from: filtered.extent) {
                        thumbs[filter] = UIImage(cgImage: cg)
                    }
                }
                return thumbs
            }.value
            await MainActor.run { filterThumbnails = result }
        }
    }

    // MARK: - Export

    private func handleExport() {
        if selectedFilter == .original {
            onComplete(images)
            dismiss()
            return
        }

        isExporting = true
        let filter = selectedFilter
        let ctx = ciContext

        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> [UIImage] in
                images.map { img in
                    guard let ci = CIImage(image: img) else { return img }
                    let filtered = VideoFilterView.applyCIFilter(to: ci, filter: filter)
                    if let cg = ctx.createCGImage(filtered, from: filtered.extent) {
                        return UIImage(cgImage: cg)
                    }
                    return img
                }
            }.value

            await MainActor.run {
                isExporting = false
                onComplete(result)
                dismiss()
            }
        }
    }
}
