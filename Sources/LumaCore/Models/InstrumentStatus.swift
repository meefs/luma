public enum InstrumentStatus: Sendable, Hashable {
    case incompatible(reason: String)
    case loadFailed(message: String, stack: String?)
    case reloadFailed(message: String, stack: String?)
    case configInvalid(message: String, stack: String?)

    public var summary: String {
        switch self {
        case .incompatible(let reason):
            return reason
        case .loadFailed(let message, _),
            .reloadFailed(let message, _),
            .configInvalid(let message, _):
            return message
        }
    }

    public var stack: String? {
        switch self {
        case .incompatible:
            return nil
        case .loadFailed(_, let stack),
            .reloadFailed(_, let stack),
            .configInvalid(_, let stack):
            return stack
        }
    }
}
