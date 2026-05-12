import Foundation

public struct HookPackBundle: Sendable {
    public struct File: Sendable {
        public let path: String
        public let content: Data

        public init(path: String, content: Data) {
            self.path = path
            self.content = content
        }
    }

    public struct IconAttachment: Sendable {
        public let filename: String
        public let data: Data

        public init(filename: String, data: Data) {
            self.filename = filename
            self.data = data
        }
    }

    public let manifestData: Data
    public let files: [File]
    public let icon: IconAttachment?

    public init(
        manifestData: Data,
        files: [File],
        icon: IconAttachment?
    ) {
        self.manifestData = manifestData
        self.files = files
        self.icon = icon
    }
}
