import SwiftUI
import UIKit

// MARK: - Crop Aspect Ratio

enum CropAspectRatio: String, CaseIterable {
    case original = "Original"
    case square = "1:1"
    case portrait = "4:5"
    case landscape = "1.91:1"

    var icon: String {
        switch self {
        case .original: return "arrow.up.left.and.arrow.down.right"
        case .square: return "square"
        case .portrait: return "rectangle.portrait"
        case .landscape: return "rectangle"
        }
    }

    func ratio(for imageSize: CGSize) -> CGFloat {
        switch self {
        case .original:
            guard imageSize.height > 0 else { return 1.0 }
            let r = imageSize.width / imageSize.height
            return min(max(r, 4.0 / 5.0), 1.91)
        case .square: return 1.0
        case .portrait: return 4.0 / 5.0
        case .landscape: return 1.91
        }
    }
}

// MARK: - ImageCropView

struct ImageCropView: View {
    let image: UIImage
    let imageNumber: Int
    let totalImages: Int
    let onCrop: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRatio: CropAspectRatio = .original
    @State private var cropperKey = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Crop area
            GeometryReader { geo in
                let cropSize = cropRect(in: geo.size)
                CropScrollViewRepresentable(
                    image: image,
                    cropSize: cropSize,
                    containerSize: geo.size
                )
                .id(cropperKey)
            }

            // Aspect ratio buttons
            VStack(spacing: 0) {
                Rectangle().fill(Color.brandBorder).frame(height: 0.5)

                HStack(spacing: 0) {
                    ForEach(CropAspectRatio.allCases, id: \.self) { ratio in
                        Button {
                            selectedRatio = ratio
                            cropperKey = UUID()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: ratio.icon)
                                    .font(.system(size: 18))
                                Text(ratio.rawValue)
                                    .font(InvlogTheme.caption(10, weight: .medium))
                            }
                            .foregroundColor(selectedRatio == ratio ? Color.brandPrimary : Color.brandTextTertiary)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("\(ratio.rawValue) crop")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, InvlogTheme.Spacing.md)
            }
            .background(Color.brandCard)
        }
        .background(Color.black)
        .navigationTitle(totalImages > 1 ? "Crop \(imageNumber) of \(totalImages)" : "Crop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .frame(minWidth: 44, minHeight: 44)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    performCrop()
                }
                .font(InvlogTheme.body(15, weight: .bold))
                .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private func cropRect(in containerSize: CGSize) -> CGSize {
        let ratio = selectedRatio.ratio(for: image.size)
        let maxWidth = containerSize.width
        let maxHeight = containerSize.height - 20 // small padding

        if maxWidth / ratio <= maxHeight {
            return CGSize(width: maxWidth, height: maxWidth / ratio)
        } else {
            return CGSize(width: maxHeight * ratio, height: maxHeight)
        }
    }

    private func performCrop() {
        let ratio = selectedRatio.ratio(for: image.size)
        let imgW = image.size.width
        let imgH = image.size.height
        let imgRatio = imgW / imgH

        let cropW: CGFloat
        let cropH: CGFloat

        if imgRatio > ratio {
            // Image is wider than crop — constrain by height
            cropH = imgH
            cropW = imgH * ratio
        } else {
            // Image is taller than crop — constrain by width
            cropW = imgW
            cropH = imgW / ratio
        }

        let cropX = (imgW - cropW) / 2
        let cropY = (imgH - cropH) / 2

        guard let cgImage = image.cgImage else {
            onCrop(image)
            return
        }

        // Convert to pixel coordinates
        let scale = image.scale
        let pixelRect = CGRect(
            x: cropX * scale,
            y: cropY * scale,
            width: cropW * scale,
            height: cropH * scale
        )

        if let cropped = cgImage.cropping(to: pixelRect) {
            onCrop(UIImage(cgImage: cropped, scale: scale, orientation: image.imageOrientation))
        } else {
            onCrop(image)
        }
    }
}

// MARK: - Crop Scroll View (UIViewRepresentable)

struct CropScrollViewRepresentable: UIViewRepresentable {
    let image: UIImage
    let cropSize: CGSize
    let containerSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.clipsToBounds = true

        // Scroll view
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.decelerationRate = .fast
        container.addSubview(scrollView)

        // Image view
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        // Overlay mask
        let overlayView = CropOverlayView()
        overlayView.isUserInteractionEnabled = false
        container.addSubview(overlayView)
        context.coordinator.overlayView = overlayView

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let scrollView = context.coordinator.scrollView,
              let imageView = context.coordinator.imageView,
              let overlayView = context.coordinator.overlayView else { return }

        let frame = CGRect(origin: .zero, size: containerSize)
        container.frame = frame
        scrollView.frame = frame
        overlayView.frame = frame

        // Calculate crop rect centered in container
        let cropRect = CGRect(
            x: (containerSize.width - cropSize.width) / 2,
            y: (containerSize.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )
        overlayView.cropRect = cropRect
        overlayView.setNeedsDisplay()

        // Size image view to image aspect ratio fitting the crop rect
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return }

        // Image view should be sized so it fills the crop rect at minimum zoom
        let scaleW = cropSize.width / imgSize.width
        let scaleH = cropSize.height / imgSize.height
        let fillScale = max(scaleW, scaleH)

        let imageViewSize = CGSize(width: imgSize.width * fillScale, height: imgSize.height * fillScale)
        imageView.frame = CGRect(origin: .zero, size: imageViewSize)

        scrollView.contentSize = imageViewSize
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.zoomScale = 1.0

        // Center the image so the crop rect shows the center
        let offsetX = max(0, (imageViewSize.width - cropSize.width) / 2)
        let offsetY = max(0, (imageViewSize.height - cropSize.height) / 2)

        // Adjust content inset so scrolling is constrained to keep image filling crop rect
        let insetH = (containerSize.height - cropSize.height) / 2
        let insetW = (containerSize.width - cropSize.width) / 2
        scrollView.contentInset = UIEdgeInsets(top: insetH, left: insetW, bottom: insetH, right: insetW)

        scrollView.contentOffset = CGPoint(x: offsetX - insetW, y: offsetY - insetH)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        weak var overlayView: CropOverlayView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
        }

        private func centerContent(in scrollView: UIScrollView) {
            guard let imageView else { return }
            let boundsSize = scrollView.bounds.size
            let contentSize = imageView.frame.size

            let offsetX = max(0, (boundsSize.width - contentSize.width) / 2)
            let offsetY = max(0, (boundsSize.height - contentSize.height) / 2)

            imageView.center = CGPoint(
                x: contentSize.width / 2 + offsetX,
                y: contentSize.height / 2 + offsetY
            )
        }
    }
}

// MARK: - Crop Overlay

fileprivate class CropOverlayView: UIView {
    var cropRect: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Fill everything with semi-transparent black
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        ctx.fill(rect)

        // Clear the crop rect
        ctx.setBlendMode(.clear)
        ctx.fill(cropRect)

        // Draw border around crop rect
        ctx.setBlendMode(.normal)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1.0)
        ctx.stroke(cropRect)

        // Draw grid lines (rule of thirds)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(0.5)

        let thirdW = cropRect.width / 3
        let thirdH = cropRect.height / 3

        for i in 1...2 {
            let x = cropRect.minX + thirdW * CGFloat(i)
            ctx.move(to: CGPoint(x: x, y: cropRect.minY))
            ctx.addLine(to: CGPoint(x: x, y: cropRect.maxY))

            let y = cropRect.minY + thirdH * CGFloat(i)
            ctx.move(to: CGPoint(x: cropRect.minX, y: y))
            ctx.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        ctx.strokePath()
    }
}
