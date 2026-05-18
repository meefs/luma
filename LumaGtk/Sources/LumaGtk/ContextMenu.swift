import GIO
import GLib
import Gtk

@MainActor
enum ContextMenu {
    struct Item {
        let label: String
        let isDestructive: Bool
        let handler: () -> Void

        init(_ label: String, destructive: Bool = false, handler: @escaping () -> Void) {
            self.label = label
            self.isDestructive = destructive
            self.handler = handler
        }
    }

    static func present(
        _ sections: [[Item]],
        at anchor: Widget,
        x: Double,
        y: Double
    ) {
        let menu = GIO.Menu()
        let group = GIO.SimpleActionGroup()
        var destructiveButtons: [(id: String, text: String, handler: () -> Void)] = []
        var idx = 0

        for items in sections where !items.isEmpty {
            let section = GIO.Menu()
            for item in items {
                let name = "a\(idx)"
                idx += 1

                if item.isDestructive {
                    let mi = GIO.MenuItem(label: nil, detailedAction: nil)
                    let value = GLib.Variant(string: name)
                    _ = value.refSink()
                    mi.setAttributeValue(attribute: "custom", value: value)
                    section.append(item: mi)
                    destructiveButtons.append((id: name, text: item.label, handler: item.handler))
                } else {
                    let action = GIO.SimpleAction(name: name, parameterType: nil as GLib.VariantTypeRef?)
                    let handler = item.handler
                    action.onActivate { _, _ in
                        MainActor.assumeIsolated { handler() }
                    }
                    group.add(action: action)
                    section.append(label: item.label, detailedAction: "menu.\(name)")
                }
            }
            menu.appendSection(label: nil, section: section)
        }

        anchor.insertActionGroup(name: "menu", group: group)

        let popover = PopoverMenu(model: menu)
        popover.hasArrow = false

        for item in destructiveButtons {
            let label = Label(str: item.text)
            label.halign = .start
            label.xalign = 0
            label.hexpand = true
            let button = Button()
            button.set(child: label)
            button.add(cssClass: "flat")
            button.add(cssClass: "luma-menu-destructive")
            let handler = item.handler
            button.onClicked { _ in
                MainActor.assumeIsolated {
                    popover.popdown()
                    _Concurrency.Task { @MainActor in handler() }
                }
            }
            _ = popover.add(child: button, id: item.id)
        }

        popover.set(parent: anchor)
        popover.presentPointing(at: x, y: y)
    }
}
