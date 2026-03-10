import Foundation
import Nuke
import NukeUI

enum ImagePipelineConfig {
    static func setup() {
        let pipeline = ImagePipeline {
            let memoryCache = ImageCache()
            memoryCache.countLimit = 100
            memoryCache.costLimit = 100 * 1024 * 1024 // 100 MB
            $0.imageCache = memoryCache

            let dataCache = try? DataCache(name: "com.invlog.images")
            dataCache?.sizeLimit = 300 * 1024 * 1024 // 300 MB
            $0.dataCache = dataCache

            $0.isProgressiveDecodingEnabled = true
        }
        ImagePipeline.shared = pipeline
    }
}
