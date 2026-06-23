import Foundation
import Gtk
import LumaCore

@MainActor
enum PointerValueLabel {
    static func make(
        value: String,
        engine: Engine,
        sessionID: UUID,
        address: UInt64,
        context: AddressContext = AddressContext()
    ) -> Label {
        let label = Label(str: value)
        label.add(cssClass: "monospace")
        label.selectable = false
        label.halign = .start
        label.xalign = 0
        AddressActionMenu.attach(to: label, engine: engine, sessionID: sessionID, address: address, value: value, context: context)
        return label
    }
}
