import SwiftUI
import ImageIO

/// UIViewRepresentable that loads and displays animated GIFs using UIImageView.
/// UIImageView natively supports animated GIF frames, unlike SwiftUI.Image.
/// Downloads raw GIF data and extracts frames for animation.
struct AnimatedGIFView: UIViewRepresentable {
    let url: URL?
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = false // Let touches pass through to parent Button
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.contentMode = contentMode

        guard let url else {
            imageView.image = nil
            imageView.animationImages = nil
            return
        }

        // Store the URL to detect stale updates
        let currentURL = url.absoluteString
        objc_setAssociatedObject(imageView, &AnimatedGIFView.urlKey, currentURL, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                await MainActor.run {
                    // Check if this view still wants this URL
                    let storedURL = objc_getAssociatedObject(imageView, &AnimatedGIFView.urlKey) as? String
                    guard storedURL == currentURL else { return }

                    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                        imageView.image = UIImage(data: data)
                        return
                    }

                    let frameCount = CGImageSourceGetCount(source)

                    if frameCount > 1 {
                        // Animated GIF — extract all frames
                        var images: [UIImage] = []
                        var totalDuration: Double = 0

                        for i in 0..<frameCount {
                            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                            images.append(UIImage(cgImage: cgImage))

                            // Get per-frame delay
                            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                               let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                                let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                                    ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                                    ?? 0.1
                                totalDuration += max(delay, 0.02)
                            } else {
                                totalDuration += 0.1
                            }
                        }

                        imageView.animationImages = images
                        imageView.animationDuration = totalDuration
                        imageView.animationRepeatCount = 0 // loop forever
                        imageView.image = images.first
                        imageView.startAnimating()
                    } else {
                        // Static image
                        imageView.animationImages = nil
                        imageView.image = UIImage(data: data)
                    }
                }
            } catch {
                await MainActor.run {
                    let storedURL = objc_getAssociatedObject(imageView, &AnimatedGIFView.urlKey) as? String
                    guard storedURL == currentURL else { return }
                    imageView.image = nil
                }
            }
        }
    }

    private static var urlKey: UInt8 = 0
}
