import SwiftUI
import PhotosUI

// MARK: - Response Models

struct PresignResponse: Decodable {
    let mediaId: String
    let uploadUrl: String
    let publicUrl: String
}

// MARK: - Upload Service

final class MediaUploadService: ObservableObject {
    enum UploadState: Equatable {
        case idle
        case compressing
        case uploading(progress: Double)
        case processing
        case completed
        case failed(String)
    }

    @Published private(set) var states: [Int: UploadState] = [:]
    @Published private(set) var overallProgress: Double = 0

    var isUploading: Bool {
        states.values.contains { state in
            if case .idle = state { return false }
            if case .completed = state { return false }
            if case .failed = state { return false }
            return true
        }
    }

    /// Upload multiple images, returns array of media IDs in order
    func uploadImages(_ images: [UIImage]) async throws -> [String] {
        var mediaIds: [String] = []
        let total = Double(images.count)

        for (index, image) in images.enumerated() {
            states[index] = .compressing

            // 1. Compress to JPEG
            let imageData: Data
            if let resized = resizeIfNeeded(image: image, maxDimension: 4096) {
                imageData = resized
            } else if let jpeg = image.jpegData(compressionQuality: 0.8) {
                imageData = jpeg
            } else {
                states[index] = .failed("Failed to compress image")
                continue
            }

            states[index] = .uploading(progress: 0.1)
            overallProgress = (Double(index) + 0.1) / total

            // 2. Request presigned URL
            let fileName = "photo_\(index).jpg"
            let (presign, _) = try await APIClient.shared.requestWrapped(
                .presignUpload(
                    fileName: fileName,
                    contentType: "image/jpeg",
                    fileSize: imageData.count
                ),
                responseType: PresignResponse.self
            )

            states[index] = .uploading(progress: 0.3)
            overallProgress = (Double(index) + 0.3) / total

            // 3. Upload to presigned URL (direct to MinIO/S3)
            guard let uploadUrl = URL(string: presign.uploadUrl) else {
                states[index] = .failed("Invalid upload URL")
                continue
            }

            try await APIClient.shared.uploadData(
                imageData,
                to: uploadUrl,
                contentType: "image/jpeg"
            )

            states[index] = .uploading(progress: 0.8)
            overallProgress = (Double(index) + 0.8) / total

            // 4. Mark upload complete → triggers server-side processing
            let (_, _) = try await APIClient.shared.requestWrapped(
                .completeUpload(mediaId: presign.mediaId),
                responseType: PostMedia.self
            )

            states[index] = .processing
            mediaIds.append(presign.mediaId)
            overallProgress = (Double(index) + 1.0) / total
        }

        // Mark all as completed
        for index in images.indices {
            if case .processing = states[index] {
                states[index] = .completed
            }
        }
        overallProgress = 1.0

        return mediaIds
    }

    func reset() {
        states = [:]
        overallProgress = 0
    }

    // MARK: - Private

    private func resizeIfNeeded(image: UIImage, maxDimension: CGFloat) -> Data? {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return nil }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
