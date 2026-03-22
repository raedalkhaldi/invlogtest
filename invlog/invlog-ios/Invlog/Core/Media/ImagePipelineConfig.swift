import Foundation
import Nuke
@preconcurrency import NukeUI

enum ImagePipelineConfig {
    static func setup() {
        let pipeline = ImagePipeline {
            let memoryCache = ImageCache()
            memoryCache.countLimit = 250    // More images in memory (was 100)
            memoryCache.costLimit = 200 * 1024 * 1024 // 200 MB (was 100)
            $0.imageCache = memoryCache

            let dataCache = try? DataCache(name: "com.invlog.images")
            dataCache?.sizeLimit = 500 * 1024 * 1024 // 500 MB (was 300)
            $0.dataCache = dataCache

            $0.isProgressiveDecodingEnabled = true
            $0.isTaskCoalescingEnabled = true  // Prevent duplicate downloads
        }
        ImagePipeline.shared = pipeline
    }
}
