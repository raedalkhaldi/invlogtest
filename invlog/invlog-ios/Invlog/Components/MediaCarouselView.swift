import SwiftUI
@preconcurrency import NukeUI

@MainActor
struct MediaCarouselView: View {
    let media: [PostMedia]
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                    mediaItem(item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)
            .aspectRatio(4/5, contentMode: .fit)
            .clipped()

            // Page dots (only for 2+ items)
            if media.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<media.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Capsule().fill(Color.black.opacity(0.4)))
                .padding(.bottom, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Post media, \(media.count) \(media.count == 1 ? "item" : "items")")
    }

    @ViewBuilder
    private func mediaItem(_ item: PostMedia) -> some View {
        if item.mediaType == "video", let videoUrl = URL(string: item.url) {
            AutoPlayVideoView(
                url: videoUrl,
                thumbnailUrl: URL(string: item.thumbnailUrl ?? item.url),
                blurhash: item.blurhash
            )
        } else {
            LazyImage(url: URL(string: item.mediumUrl ?? item.url)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if state.isLoading {
                    ZStack {
                        if let blurhash = item.blurhash {
                            BlurhashView(blurhash: blurhash)
                        }
                        ShimmerView()
                            .opacity(0.4)
                    }
                } else {
                    Rectangle()
                        .fill(Color.brandBorder)
                }
            }
        }
    }
}
