import SwiftUI

struct BlurhashView: View {
    let blurhash: String
    let size: CGSize

    init(blurhash: String, size: CGSize = CGSize(width: 32, height: 32)) {
        self.blurhash = blurhash
        self.size = size
    }

    var body: some View {
        if let uiImage = UIImage(blurHash: blurhash, size: size) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
        }
    }
}
