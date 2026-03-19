import AVFoundation
import UIKit

/// Shared utility for generating video thumbnails.
/// Replaces duplicate `generateThumbnail` functions in CreateStoryView and CreatePostView.
enum VideoThumbnailGenerator {
    /// Generate a thumbnail from a video URL at the given time (defaults to start).
    static func generateThumbnail(
        from url: URL,
        at time: CMTime = .zero,
        maxSize: CGSize = CGSize(width: 1024, height: 1024)
    ) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}
