import CLuma
import Foundation
import LumaCore

struct HostImageProcessor: ImageProcessor {
    func scaleDown(data: Data, mediaType: String, maxDimension: Int) -> ProcessedImage? {
        var outBytes: UnsafeMutablePointer<UInt8>? = nil
        var outSize: Int = 0
        var outWidth: Int32 = 0
        var outHeight: Int32 = 0
        let ok = data.withUnsafeBytes { buffer -> Bool in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else { return false }
            return luma_image_normalize_to_png(base, buffer.count, Int32(maxDimension), &outBytes, &outSize, &outWidth, &outHeight)
        }
        guard ok, let outBytes, outSize > 0 else { return nil }
        defer { free(outBytes) }
        return ProcessedImage(
            mediaType: "image/png",
            data: Data(bytes: outBytes, count: outSize),
            width: Int(outWidth),
            height: Int(outHeight)
        )
    }
}
