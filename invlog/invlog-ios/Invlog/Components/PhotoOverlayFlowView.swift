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
                    results.append(overlayedImage)

                    if currentIndex + 1 < images.count {
                        currentIndex += 1
                    } else {
                        // All done
                        onComplete(results)
                    }
                }
                .id(currentIndex) // Force view recreation for each image
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip All") {
                    // Skip overlay — add remaining unedited images
                    var finalResults = results
                    for i in currentIndex..<images.count {
                        finalResults.append(images[i])
                    }
                    onComplete(finalResults)
                }
            }
        }
    }
}
