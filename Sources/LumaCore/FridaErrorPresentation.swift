import Frida

extension Frida.Error: @retroactive CustomStringConvertible {}

extension InstrumentStatus {
    public static func from(error: Swift.Error, kind: FailureKind) -> InstrumentStatus {
        let (message, stack) = describe(error)
        switch kind {
        case .load:
            return .loadFailed(message: message, stack: stack)
        case .reload:
            return .reloadFailed(message: message, stack: stack)
        case .configInvalid:
            return .configInvalid(message: message, stack: stack)
        }
    }

    public enum FailureKind: Sendable {
        case load
        case reload
        case configInvalid
    }

    private static func describe(_ error: Swift.Error) -> (message: String, stack: String?) {
        if let rpc = error as? Frida.Error,
            case let .rpcError(message: message, stackTrace: stackTrace) = rpc
        {
            return (message, stackTrace)
        }
        return (String(describing: error), nil)
    }
}
