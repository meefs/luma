import LumaCore
import SwiftUI

struct InstrumentDetailView: View {
    let instanceID: UUID
    let sessionID: UUID
    let engine: Engine
    @Binding var selection: SidebarItemID?

    private var instance: LumaCore.InstrumentInstance? {
        engine.instrumentsBySession[sessionID]?.first(where: { $0.id == instanceID })
    }

    private var session: LumaCore.ProcessSession? {
        engine.sessions.first(where: { $0.id == sessionID })
    }

    private var configBinding: Binding<Data> {
        Binding(
            get: { instance?.configJSON ?? Data() },
            set: { newValue in
                guard let snapshot = instance else { return }
                Task { @MainActor in
                    await engine.applyInstrumentConfig(snapshot, configJSON: newValue)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let inst = instance, let ui = InstrumentUIRegistry.shared.ui(for: inst) {
                ui.makeConfigEditor(configJSON: configBinding, engine: engine, selection: $selection)
                    .environment(\.instrumentSession, session)
                    .environment(\.instrumentInstance, inst)
            } else {
                Text("This instrument doesn't expose any configurable settings yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                Spacer()
            }
        }
        .frame(minWidth: 360, minHeight: 300)
    }
}
