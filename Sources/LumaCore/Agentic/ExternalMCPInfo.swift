import Foundation

public struct ExternalMCPInfo: Sendable {
    public let url: URL
    public let bearerToken: String
    public let missionID: UUID

    public init(url: URL, bearerToken: String, missionID: UUID) {
        self.url = url
        self.bearerToken = bearerToken
        self.missionID = missionID
    }
}
