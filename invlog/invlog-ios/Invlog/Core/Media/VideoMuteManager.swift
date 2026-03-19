import Foundation

/// Shared mute and pause state for all videos in the session.
/// When a user unmutes one video, all videos become unmuted.
final class VideoMuteManager: ObservableObject {
    static let shared = VideoMuteManager()

    @Published var isMuted = true
    /// When true, all AutoPlayVideoViews should pause playback (e.g. long-press).
    @Published var isPaused = false

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
