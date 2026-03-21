import SwiftUI

/// Iterates through multiple photos, presenting VideoOverlayEditorView (photo mode)
/// for each one. Collects all results and returns them via onComplete.
/// Uses fullScreenCover to avoid NavigationStack corruption issues.
struct PhotoOverlayFlowView: View {
    let images: [UIImage]
    let placeName: String?
    let onComplete: ([UIImage]) -> Void

    @State private var currentIndex = 0
    @State private var results: [UIImage] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if currentIndex < images.count {
                VideoOverlayEditorView(
                    image: images[currentIndex],
                    placeName: placeName
                ) { overlayedImage in
                    var updatedResults = results
                    updatedResults.append(overlayedImage)
                    results = updatedResults

                    if currentIndex + 1 < images.count {
                        currentIndex += 1
                    } else {
                        onComplete(updatedResults)
                    }
                }
                .id(currentIndex)
            }
        }
    }
}
