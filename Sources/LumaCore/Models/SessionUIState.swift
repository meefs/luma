import Foundation
import GRDB

public struct SessionUIState: Codable, Identifiable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "session_ui_state"

    public var sessionID: UUID
    public var detailSection: String?
    public var lastSelectedModuleID: String?
    public var lastSelectedThreadID: UInt?

    public var id: UUID { sessionID }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case detailSection = "detail_section"
        case lastSelectedModuleID = "last_selected_module_id"
        case lastSelectedThreadID = "last_selected_thread_id"
    }

    public init(
        sessionID: UUID,
        detailSection: String? = nil,
        lastSelectedModuleID: String? = nil,
        lastSelectedThreadID: UInt? = nil
    ) {
        self.sessionID = sessionID
        self.detailSection = detailSection
        self.lastSelectedModuleID = lastSelectedModuleID
        self.lastSelectedThreadID = lastSelectedThreadID
    }
}
