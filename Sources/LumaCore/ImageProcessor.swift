import Foundation

public struct ProcessedImage: Sendable, Equatable {
    public var mediaType: String
    public var data: Data
    public var width: Int
    public var height: Int

    public init(mediaType: String, data: Data, width: Int, height: Int) {
        self.mediaType = mediaType
        self.data = data
        self.width = width
        self.height = height
    }
}

public protocol ImageProcessor: Sendable {
    /// Decode `data` (PNG, JPEG, etc.) and return a re-encoded PNG whose
    /// longest edge is at most `maxDimension`. If the image already fits,
    /// the original may be returned unchanged. Returns nil if the input
    /// cannot be decoded.
    func scaleDown(data: Data, mediaType: String, maxDimension: Int) -> ProcessedImage?
}
