import SwiftUI
import Combine

@MainActor
final class StoryUploadManager: ObservableObject {
    static let shared = StoryUploadManager()

    enum UploadStatus: Equatable {
        case idle
        case uploading(progress: Double)
        case processing
        case completed
        case failed(String)
    }

    @Published private(set) var status: UploadStatus = .idle

    var isActive: Bool {
        switch status {
        case .uploading, .processing: return true
        default: return false
        }
    }

    private let uploadService = MediaUploadService()
    private var progressCancellable: AnyCancellable?

    private init() {}

    func upload(mediaItem: MediaItem, caption: String? = nil, locationName: String? = nil, restaurantId: String? = nil) {
        status = .uploading(progress: 0)

        // Observe upload progress
        progressCancellable = uploadService.$overallProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self else { return }
                if case .uploading = self.status {
                    self.status = .uploading(progress: progress * 0.8) // 80% for upload, 20% for processing
                }
            }

        Task {
            do {
                let mediaIds = try await uploadService.uploadMedia([mediaItem])
                progressCancellable = nil

                guard let mediaId = mediaIds.first else {
                    status = .failed("Upload failed — no media ID returned.")
                    scheduleClearFailure()
                    return
                }

                status = .processing

                // Backend now waits for video processing before creating story
                try await APIClient.shared.requestVoid(.createStory(mediaId: mediaId, caption: caption, locationName: locationName, restaurantId: restaurantId))

                status = .completed
                NotificationCenter.default.post(name: .didCreateStory, object: nil)

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if status == .completed {
                    status = .idle
                }
            } catch {
                progressCancellable = nil
                status = .failed(error.localizedDescription)
                scheduleClearFailure()
            }
        }
    }

    private func scheduleClearFailure() {
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if case .failed = status {
                status = .idle
            }
        }
    }
}
