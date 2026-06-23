import CGtk
import Foundation
import Gdk
import Gtk
import LumaCore

@MainActor
enum AddressActionMenu {
    static var navigator: ((UUID, UUID) -> Void)?
    static var errorReporter: ((String) -> Void)?
    static var navigateToTarget: ((LumaCore.NavigationTarget) -> Void)?

    static func attach(
        to anchor: Widget,
        engine: Engine,
        sessionID: UUID,
        address: UInt64,
        value: String,
        context: AddressContext = AddressContext()
    ) {
        let gesture = GestureClick()
        gesture.set(button: 3)
        gesture.propagationPhase = GTK_PHASE_CAPTURE
        gesture.onPressed { [anchor] _, _, x, y in
            MainActor.assumeIsolated {
                present(at: anchor, x: x, y: y, engine: engine, sessionID: sessionID, address: address, value: value, context: context)
            }
        }
        anchor.install(controller: gesture)
    }

    static func present(
        at anchor: Widget,
        x: Double,
        y: Double,
        engine: Engine,
        sessionID: UUID,
        address: UInt64,
        value: String,
        context: AddressContext = AddressContext(),
        extraSections: [[ContextMenu.Item]] = []
    ) {
        Task { @MainActor in
            let facts = await engine.addressFacts(sessionID: sessionID, address: address, context: context)
            presentResolved(
                at: anchor, x: x, y: y, engine: engine, sessionID: sessionID,
                address: address, value: value, context: context, facts: facts, extraSections: extraSections)
        }
    }

    private static func presentResolved(
        at anchor: Widget,
        x: Double,
        y: Double,
        engine: Engine,
        sessionID: UUID,
        address: UInt64,
        value: String,
        context: AddressContext,
        facts: AddressFacts,
        extraSections: [[ContextMenu.Item]]
    ) {
        let copySection: [ContextMenu.Item] = [
            .init("Copy") { copyToClipboard(value) }
        ]

        var inspectSection: [ContextMenu.Item] = []
        if facts.mapping == .executable {
            inspectSection.append(.init("Open Disassembly") {
                openInsight(engine: engine, sessionID: sessionID, address: address, kind: .disassembly, preferredAnchor: context.anchorHint, failureLabel: "Can\u{2019}t open disassembly")
            })
        }
        if facts.mapping != .unmapped {
            inspectSection.append(.init("Open Memory") {
                openInsight(engine: engine, sessionID: sessionID, address: address, kind: .memory, preferredAnchor: context.anchorHint, failureLabel: "Can\u{2019}t open memory")
            })
        }

        let pluggableSection: [ContextMenu.Item] = engine
            .addressActions(sessionID: sessionID, address: address, context: context, facts: facts)
            .map { action in
                ContextMenu.Item(action.title, destructive: action.role == .destructive) {
                    Task { @MainActor in
                        guard let target = await action.perform() else { return }
                        navigateToTarget?(target)
                    }
                }
            }

        ContextMenu.present([copySection, inspectSection] + extraSections + [pluggableSection], at: anchor, x: x, y: y)
    }

    static func openInsight(
        engine: Engine,
        sessionID: UUID,
        address: UInt64,
        kind: AddressInsight.Kind,
        preferredAnchor: AddressAnchor? = nil,
        failureLabel: String
    ) {
        do {
            let insight = try engine.getOrCreateInsight(sessionID: sessionID, pointer: address, kind: kind, preferredAnchor: preferredAnchor)
            navigator?(sessionID, insight.id)
        } catch {
            errorReporter?("\(failureLabel): \(error.localizedDescription)")
        }
    }

    private static func copyToClipboard(_ value: String) {
        guard let display = Display.getDefault() else { return }
        display.clipboard.set(text: value)
    }
}
