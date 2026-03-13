import Foundation

/// Shared mute state for all videos in the session.
/// When a user unmutes one video, all videos become unmuted.
final class VideoMuteManager: ObservableObject {
    static let shared = VideoMuteManager()

    @Published var isMuted = true

    func unmute() {
        isMuted = false
    }

    func mute() {
        isMuted = true
    }

    func toggle() {
        isMuted.toggle()
    }
}
