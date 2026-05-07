import LumaCore
import SwiftUI

struct ModuleDetailView: View {
    let sessionID: UUID
    let module: LumaCore.ProcessModule
    @ObservedObject var workspace: Workspace
    @Binding var selection: SidebarItemID?

    @State private var bundle: LumaCore.ModuleSymbolBundle?
    @State private var loadError: String?
    @State private var tab: Tab = .exports
    @State private var loadTask: Task<Void, Never>?

    enum Tab: String, CaseIterable, Identifiable {
        case exports = "Exports"
        case imports = "Imports"
        case symbols = "Symbols"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(label(for: t)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            content
        }
        .padding(.top, 8)
        .task(id: module.id) {
            await reload()
        }
    }

    private var header: some View {
        HStack {
            Text(module.name).font(.headline)
            Text(String(format: "0x%llx", module.base))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                loadTask = Task { await reload() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(workspace.engine.node(forSessionID: sessionID) == nil)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text(loadError).foregroundStyle(.red)
        } else if let bundle {
            switch tab {
            case .exports: exportsTable(bundle.exports)
            case .imports: importsTable(bundle.imports)
            case .symbols: symbolsTable(bundle.symbols)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func label(for tab: Tab) -> String {
        guard let bundle else { return tab.rawValue }
        switch tab {
        case .exports: return "Exports (\(bundle.exports.count))"
        case .imports: return "Imports (\(bundle.imports.count))"
        case .symbols: return "Symbols (\(bundle.symbols.count))"
        }
    }

    private func exportsTable(_ rows: [LumaCore.ModuleSymbolBundle.Export]) -> some View {
        Table(rows) {
            TableColumn("Name", value: \.name)
            TableColumn("Type") { e in Text(e.kind.rawValue) }
            TableColumn("Address") { e in
                addressCell(
                    address: e.address,
                    title: e.name,
                    context: addressContext(for: e.kind)
                )
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
    }

    private func importsTable(_ rows: [LumaCore.ModuleSymbolBundle.Import]) -> some View {
        Table(rows) {
            TableColumn("Name", value: \.name)
            TableColumn("Module") { i in Text(i.module ?? "—") }
            TableColumn("Type") { i in Text(i.kind?.rawValue ?? "—") }
            TableColumn("Address") { i in
                if let addr = i.address {
                    addressCell(
                        address: addr,
                        title: i.name,
                        context: i.kind.map(addressContext(for:)) ?? AddressContext()
                    )
                } else {
                    Text("—")
                }
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
    }

    private func symbolsTable(_ rows: [LumaCore.ModuleSymbolBundle.Symbol]) -> some View {
        Table(rows) {
            TableColumn("Name", value: \.name)
            TableColumn("Type") { s in Text(s.type) }
            TableColumn("Section") { s in Text(s.sectionID ?? "—") }
            TableColumn("Size") { s in
                Text(s.size.map { String(format: "0x%x", $0) } ?? "—")
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn("Address") { s in
                addressCell(
                    address: s.address,
                    title: s.name,
                    context: addressContext(for: s)
                )
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
    }

    private func addressCell(
        address: UInt64,
        title: String,
        context: AddressContext
    ) -> some View {
        Text(String(format: "0x%llx", address))
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { openInsight(at: address, title: title, context: context) }
            .contextMenu { addressMenu(address: address, title: title, context: context) }
    }

    @ViewBuilder
    private func addressMenu(address: UInt64, title: String, context: AddressContext) -> some View {
        Button {
            openInsight(at: address, title: title, context: context)
        } label: {
            Label(defaultInsightLabel(for: context), systemImage: defaultInsightIcon(for: context))
        }

        Divider()

        Button {
            openInsight(at: address, title: title, kindOverride: .memory)
        } label: {
            Label("Open Memory", systemImage: "doc.text.magnifyingglass")
        }

        Button {
            openInsight(at: address, title: title, kindOverride: .disassembly)
        } label: {
            Label("Open Disassembly", systemImage: "hammer")
        }

        let actions = workspace.engine.addressActions(sessionID: sessionID, address: address, context: context)
        if !actions.isEmpty {
            Divider()
            ForEach(actions) { action in
                Button(role: action.role == .destructive ? .destructive : nil) {
                    Task { @MainActor in
                        if let target = await action.perform() {
                            selection = workspace.sidebarItem(for: target)
                        }
                    }
                } label: {
                    if let icon = action.systemImage {
                        Label(action.title, systemImage: icon)
                    } else {
                        Text(action.title)
                    }
                }
            }
        }
    }

    private func openInsight(
        at address: UInt64,
        title: String,
        context: AddressContext = AddressContext(),
        kindOverride: LumaCore.AddressInsight.Kind? = nil
    ) {
        let kind: LumaCore.AddressInsight.Kind
        if let kindOverride {
            kind = kindOverride
        } else if context.kind == .data {
            kind = .memory
        } else {
            kind = .disassembly
        }

        Task { @MainActor in
            do {
                let insight = try workspace.engine.getOrCreateInsight(
                    sessionID: sessionID,
                    pointer: address,
                    kind: kind
                )
                selection = .insight(sessionID, insight.id)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func reload() async {
        loadError = nil
        guard let node = workspace.engine.node(forSessionID: sessionID) else {
            loadError = "Process is detached."
            bundle = nil
            return
        }
        do {
            bundle = try await node.enumerateModuleSymbols(name: module.name)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private func addressContext(for kind: LumaCore.ModuleSymbolBundle.SymbolKind) -> AddressContext {
    switch kind {
    case .function: return AddressContext(kind: .function, typeHint: "function")
    case .variable: return AddressContext(kind: .data, typeHint: "variable")
    }
}

private func addressContext(for symbol: LumaCore.ModuleSymbolBundle.Symbol) -> AddressContext {
    if symbol.isCode {
        return AddressContext(kind: .function, typeHint: symbol.type)
    }
    if symbol.isData {
        return AddressContext(kind: .data, typeHint: symbol.type)
    }
    return AddressContext(kind: .unspecified, typeHint: symbol.type)
}

private func defaultInsightLabel(for context: AddressContext) -> String {
    context.kind == .data ? "Open Memory" : "Open Disassembly"
}

private func defaultInsightIcon(for context: AddressContext) -> String {
    context.kind == .data ? "doc.text.magnifyingglass" : "hammer"
}
