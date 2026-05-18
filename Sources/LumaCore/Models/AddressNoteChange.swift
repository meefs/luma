import Foundation

public enum AddressNoteChange: Sendable {
    case noteAdded(AddressNote)
    case noteUpdated(AddressNote)
    case noteRemoved(AddressNote)
    case messageAppended(AddressNoteMessage)
    case messageEdited(AddressNoteMessage)
}
