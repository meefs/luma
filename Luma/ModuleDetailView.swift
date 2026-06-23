import LumaCore
import SwiftUI

struct ModuleDetailView: View {
    let sessionID: UUID
    let module: LumaCore.ProcessModule
    let engine: Engine
    @Binding var selection: SidebarItemID?

    @State private var bundles: [LumaCore.ProcessModule.ID: LumaCore.ModuleSymbolBundle] = [:]
    @State private var loadErrors: [LumaCore.ProcessModule.ID: String] = [:]
    @State private var tab: Tab = .exports
    @State private var selectedRowID: String?

    enum Tab: String, CaseIterable, Identifiable {
        case exports = "Exports"
        case imports = "Imports"
        case symbols = "Symbols"

        var id: String { rawValue }
    }

    private var displayBundle: LumaCore.ModuleSymbolBundle {
        bundles[module.id] ?? LumaCore.ModuleSymbolBundle()
    }
    private var loadError: String? { loadErrors[module.id] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(label(for: t)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: module.id) {
            guard bundles[module.id] == nil, loadError == nil else { return }
            await load(module)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text(loadError)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch tab {
            case .exports: exportsTable(displayBundle.exports)
            case .imports: importsTable(displayBundle.imports)
            case .symbols: symbolsTable(displayBundle.symbols)
            }
        }
    }

    private func label(for tab: Tab) -> String {
        guard let bundle = bundles[module.id] else { return tab.rawValue }
        switch tab {
        case .exports: return "Exports (\(bundle.exports.count))"
        case .imports: return "Imports (\(bundle.imports.count))"
        case .symbols: return "Symbols (\(bundle.symbols.count))"
        }
    }

    private func exportsTable(_ rows: [LumaCore.ModuleSymbolBundle.Export]) -> some View {
        Table(rows, selection: $selectedRowID) {
            TableColumn("Name", value: \.name)
            TableColumn("Type") { e in Text(e.kind.rawValue) }
            TableColumn("Address") { e in
                addressCell(address: e.address, context: addressContext(for: e))
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
    }

    private func importsTable(_ rows: [LumaCore.ModuleSymbolBundle.Import]) -> some View {
        Table(rows, selection: $selectedRowID) {
            TableColumn("Name", value: \.name)
            TableColumn("Module") { i in Text(i.module ?? "—") }
            TableColumn("Type") { i in Text(i.kind?.rawValue ?? "—") }
            TableColumn("Address") { i in
                if let addr = i.address {
                    addressCell(address: addr, context: addressContext(for: i))
                } else {
                    Text("—")
                }
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
    }

    private func symbolsTable(_ rows: [LumaCore.ModuleSymbolBundle.Symbol]) -> some View {
        Table(rows, selection: $selectedRowID) {
            TableColumn("Name", value: \.name)
            TableColumn("Type") { s in Text(s.type) }
            TableColumn("Section") { s in Text(s.sectionID ?? "—") }
            TableColumn("Size") { s in
                Text(s.size.map { String(format: "0x%x", $0) } ?? "—")
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn("Address") { s in
                addressCell(address: s.address, context: addressContext(for: s))
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
    }

    private func addressCell(address: UInt64, context: AddressContext) -> some View {
        PointerValueText(
            engine: engine,
            sessionID: sessionID,
            value: String(format: "0x%llx", address),
            address: address,
            context: context,
            selection: $selection
        )
    }

    private func load(_ module: LumaCore.ProcessModule) async {
        guard let node = engine.node(forSessionID: sessionID) else {
            loadErrors[module.id] = "Process is detached."
            return
        }
        do {
            let result = try await node.enumerateModuleSymbols(name: module.name)
            bundles[module.id] = result
            loadErrors.removeValue(forKey: module.id)
        } catch {
            loadErrors[module.id] = error.localizedDescription
        }
    }
}

extension ModuleDetailView {
    fileprivate func addressContext(for export: LumaCore.ModuleSymbolBundle.Export) -> AddressContext {
        AddressContext(
            kind: export.kind == .function ? .function : .data,
            typeHint: export.kind.rawValue,
            anchorHint: .moduleExport(name: module.name, export: export.name)
        )
    }

    fileprivate func addressContext(for imp: LumaCore.ModuleSymbolBundle.Import) -> AddressContext {
        let kind: AddressContext.Kind
        switch imp.kind {
        case .function: kind = .function
        case .variable: kind = .data
        case nil: kind = .unspecified
        }
        let anchorHint: AddressAnchor? = imp.module.map { .moduleExport(name: $0, export: imp.name) }
        return AddressContext(kind: kind, typeHint: imp.kind?.rawValue, anchorHint: anchorHint)
    }

    fileprivate func addressContext(for symbol: LumaCore.ModuleSymbolBundle.Symbol) -> AddressContext {
        let kind: AddressContext.Kind = symbol.isCode
            ? .function
            : (symbol.isData ? .data : .unspecified)
        return AddressContext(kind: kind, typeHint: symbol.type)
    }
}
