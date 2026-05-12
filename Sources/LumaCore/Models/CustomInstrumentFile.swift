import Foundation
import GRDB

public struct CustomInstrumentFile: Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "custom_instrument_file"

    public var defID: UUID
    public var path: String
    public var content: String

    public init(defID: UUID, path: String, content: String) {
        self.defID = defID
        self.path = path
        self.content = content
    }

    public init(row: Row) throws {
        defID = UUID(uuidString: row["def_id"])!
        path = row["path"]
        content = row["content"]
    }

    public func encode(to container: inout PersistenceContainer) {
        container["def_id"] = defID.uuidString
        container["path"] = path
        container["content"] = content
    }

    public func toJSON() -> [String: Any] {
        ["path": path, "content": content]
    }

    public static func fromJSON(defID: UUID, _ obj: [String: Any]) -> CustomInstrumentFile? {
        guard let path = obj["path"] as? String,
            let content = obj["content"] as? String
        else { return nil }
        return CustomInstrumentFile(defID: defID, path: path, content: content)
    }

    public static func sortedByPath(_ files: [CustomInstrumentFile], entrypoint: String) -> [CustomInstrumentFile] {
        files.sorted { lhs, rhs in
            if lhs.path == entrypoint { return true }
            if rhs.path == entrypoint { return false }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    public static func workspaceRelativePath(defID: UUID, path: String) -> String {
        let encoded = path.replacingOccurrences(of: " ", with: "%20")
        return "InstrumentSources/Custom/\(defID.uuidString)/\(encoded)"
    }
}

public struct CustomInstrumentBundle: Sendable, Equatable {
    public var def: CustomInstrumentDef
    public var files: [CustomInstrumentFile]

    public init(def: CustomInstrumentDef, files: [CustomInstrumentFile]) {
        self.def = def
        self.files = files
    }

    public func toJSON() -> [String: Any] {
        var obj = def.toJSON()
        obj["files"] = files.map { $0.toJSON() }
        return obj
    }

    public static func fromJSON(_ obj: [String: Any]) -> CustomInstrumentBundle? {
        guard let def = CustomInstrumentDef.fromJSON(obj) else { return nil }
        let filesArr = (obj["files"] as? [[String: Any]]) ?? []
        let files = filesArr.compactMap { CustomInstrumentFile.fromJSON(defID: def.id, $0) }
        return CustomInstrumentBundle(def: def, files: files)
    }
}
