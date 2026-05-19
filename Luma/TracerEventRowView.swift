import SwiftUI
import LumaCore

struct TracerEventRowView: View {
    let messageView: AnyView
    let sessionID: UUID?
    let backtrace: [JSInspectValue]?
    let engine: Engine
    @Binding var selection: SidebarItemID?

    @State private var showBacktracePopover = false

    @Environment(\.pauseEventStream) private var pauseEventStream

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            messageView

            if let sessionID, let backtrace, !backtrace.isEmpty {
                Spacer(minLength: 0)

                Button {
                    if !showBacktracePopover {
                        pauseEventStream()
                    }
                    showBacktracePopover.toggle()
                } label: {
                    Text("Backtrace")
                        .font(.system(.footnote, design: .monospaced))
                        .hidden()
                        .overlay {
                            Image(systemName: "list.bullet.rectangle")
                                .imageScale(.small)
                        }
                }
                .buttonStyle(.borderless)
                .help("Show backtrace")
                .popover(isPresented: $showBacktracePopover, arrowEdge: .bottom) {
                    TracerBacktraceView(
                        sessionID: sessionID,
                        pointers: backtrace,
                        engine: engine,
                        selection: $selection
                    )
                    .frame(minWidth: 520, minHeight: 280)
                    .padding()
                }
            }
        }
    }
}

private struct TracerBacktraceView: View {
    let sessionID: UUID
    let pointers: [JSInspectValue]
    let engine: Engine
    @Binding var selection: SidebarItemID?

    @State private var symbols: [SymbolicateResult?] = []
    @State private var isLoading = false
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Backtrace")
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if lastError != nil, engine.node(forSessionID: sessionID) != nil {
                    Button("Symbolicate") {
                        Task { await symbolicate() }
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(pointers.enumerated()), id: \.offset) { idx, ptrValue in
                        let addr = ptrValue.nativePointerAddress ?? 0
                        let anchor = engine.anchor(sessionID: sessionID, address: addr)

                        HStack(alignment: .center, spacing: 8) {
                            Text("#\(idx + 1)")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(displayString(idx: idx, anchor: anchor))
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)

                            Spacer(minLength: 0)

                            Button {
                                openDisassembly(at: addr)
                            } label: {
                                Image(systemName: "arrow.right.circle")
                                    .imageScale(.small)
                                    .padding(4)
                            }
                            .buttonStyle(.borderless)
                            .help("Open Disassembly")
                        }
                        .padding(.vertical, 4)

                        Divider()
                    }
                }
            }
        }
        .task {
            await symbolicate()
        }
    }

    private func displayString(
        idx: Int,
        anchor: AddressAnchor
    ) -> String {
        guard idx < symbols.count, let symbol = symbols[idx] else {
            return anchor.displayString
        }
        return symbol.displayString
    }

    private func openDisassembly(at address: UInt64) {
        do {
            let insight = try engine.getOrCreateInsight(
                sessionID: sessionID,
                pointer: address,
                kind: .disassembly
            )
            selection = .insight(sessionID, insight.id)
        } catch {
            lastError = "Can’t open disassembly: \(error.localizedDescription)"
        }
    }

    private func symbolicate() async {
        guard let node = engine.node(forSessionID: sessionID) else {
            lastError = "Symbolication needs a live session."
            return
        }
        if isLoading { return }
        isLoading = true
        lastError = nil

        do {
            symbols = try await node.symbolicate(addresses: pointers.compactMap { $0.nativePointerAddress })
        } catch {
            lastError = "Symbolication failed: \(error)"
        }

        isLoading = false
    }
}
