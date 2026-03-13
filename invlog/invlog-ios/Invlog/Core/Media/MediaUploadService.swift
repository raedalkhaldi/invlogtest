import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Response Models

struct PresignResponse: Decodable {
    let mediaId: String
    let uploadUrl: String
    let publicUrl: String
}

// MARK: - Media Item

enum MediaItem {
    case image(UIImage)
    case video(URL, UIImage) // video URL + thumbnail
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

    /// Upload multiple media items (images and videos), returns array of media IDs in order
    func uploadMedia(_ items: [MediaItem]) async throws -> [String] {
        var mediaIds: [String] = []
        let total = Double(items.count)

        for (index, item) in items.enumerated() {
            states[index] = .compressing

            let mediaData: Data
            let fileName: String
            let contentType: String

            switch item {
            case .image(let image):
                // Try HEIC first at 0.92 quality, fallback to JPEG at 0.92
                if let resized = resizeIfNeeded(image: image, maxDimension: 4096) {
                    mediaData = resized
                    // resizeIfNeeded returns HEIC-first data
                    fileName = "photo_\(index).heic"
                    contentType = "image/heic"
                } else if let heicData = heicData(for: image, quality: 0.92) {
                    mediaData = heicData
                    fileName = "photo_\(index).heic"
                    contentType = "image/heic"
                } else if let jpegData = image.jpegData(compressionQuality: 0.92) {
                    mediaData = jpegData
                    fileName = "photo_\(index).jpg"
                    contentType = "image/jpeg"
                } else {
                    states[index] = .failed("Failed to compress image")
                    continue
                }

            case .video(let url, _):
                do {
                    mediaData = try Data(contentsOf: url)
                    fileName = "video_\(index).mp4"
                    contentType = "video/mp4"
                } catch {
                    states[index] = .failed("Failed to read video file")
                    continue
                }
            }

            states[index] = .uploading(progress: 0.1)
            overallProgress = (Double(index) + 0.1) / total

            // 2. Request presigned URL
            let (presign, _) = try await APIClient.shared.requestWrapped(
                .presignUpload(
                    fileName: fileName,
                    contentType: contentType,
                    fileSize: mediaData.count
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
                mediaData,
                to: uploadUrl,
                contentType: contentType
            )

            states[index] = .uploading(progress: 0.8)
            overallProgress = (Double(index) + 0.8) / total

            // 4. Mark upload complete → triggers server-side processing
            let (imgWidth, imgHeight): (Int?, Int?) = {
                switch item {
                case .image(let img):
                    return (Int(img.size.width * img.scale), Int(img.size.height * img.scale))
                case .video:
                    return (nil, nil)
                }
            }()
            let (_, _) = try await APIClient.shared.requestWrapped(
                .completeUpload(mediaId: presign.mediaId, width: imgWidth, height: imgHeight),
                responseType: PostMedia.self
            )

            states[index] = .processing
            mediaIds.append(presign.mediaId)
            overallProgress = (Double(index) + 1.0) / total
        }

        // Mark all as completed
        for index in items.indices {
            if case .processing = states[index] {
                states[index] = .completed
            }
        }
        overallProgress = 1.0

        return mediaIds
    }

    /// Legacy convenience: upload images only
    func uploadImages(_ images: [UIImage]) async throws -> [String] {
        try await uploadMedia(images.map { .image($0) })
    }

    // MARK: - Eager Upload

    private var eagerTask: Task<[String], Error>?
    private var eagerMediaIds: [String]?

    /// Start uploading immediately in background. Call `awaitEagerUpload()` to get the IDs.
    func startEagerUpload(_ items: [MediaItem]) {
        cancelEagerUpload()
        eagerMediaIds = nil
        eagerTask = Task {
            let ids = try await uploadMedia(items)
            eagerMediaIds = ids
            return ids
        }
    }

    /// Await completion of an eager upload started with `startEagerUpload`.
    /// If no eager upload is in progress, falls back to uploading the provided items.
    func awaitEagerUpload(fallbackItems: [MediaItem]) async throws -> [String] {
        if let task = eagerTask {
            return try await task.value
        }
        return try await uploadMedia(fallbackItems)
    }

    /// Cancel any in-progress eager upload (e.g. when media selection changes).
    func cancelEagerUpload() {
        eagerTask?.cancel()
        eagerTask = nil
        eagerMediaIds = nil
    }

    func reset() {
        cancelEagerUpload()
        states = [:]
        overallProgress = 0
    }

    // MARK: - Private

    private func heicData(for image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.heic" as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func resizeIfNeeded(image: UIImage, maxDimension: CGFloat) -> Data? {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return nil }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        // Try HEIC first, fallback to JPEG
        if let heic = heicData(for: resized, quality: 0.92) {
            return heic
        }
        return resized.jpegData(compressionQuality: 0.92)
    }
}
