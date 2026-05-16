import LumaCore
import SwiftUI

struct CustomInstrumentConfigView: View {
    let defID: UUID
    @Binding var config: CustomInstrumentConfig
    let engine: Engine
    @Binding var selection: SidebarItemID?

    @Environment(\.instrumentInstance) private var instrumentInstance

    @State private var isShowingRename = false
    @State private var isShowingCompatibility = false
    @State private var isShowingFeaturesEditor = false
    @State private var isShowingWidgetsEditor = false
    @State private var isShowingDeleteConfirm = false
    @State private var renameEntrypointPrompt = RenamePromptState()

    private var def: CustomInstrumentDef? {
        engine.customInstruments.def(withId: defID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            GroupBox("Features") {
                Group {
                    if let def, !def.features.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(def.features) { feature in
                                InstrumentFeatureRow(
                                    feature: feature,
                                    state: stateBinding(for: feature)
                                )
                            }
                        }
                    } else {
                        Text("This custom instrument does not declare any features.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let def {
                InstrumentWidgetsRenderer(widgets: def.widgets, engine: engine)
            }

            Spacer()
        }
        .padding(8)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let def {
                InstrumentIconView(icon: def.icon, pointSize: 14)
                Text(def.name).font(.headline)
            } else {
                Text("Custom Instrument").font(.headline)
            }
            Spacer()
            if instrumentInstance != nil {
                Button("Edit Source\u{2026}") {
                    if let entrypoint = def?.entrypoint {
                        selection = .customInstrumentFile(defID, entrypoint)
                    } else {
                        selection = .customInstrumentDef(defID)
                    }
                }
                .accessibilityIdentifier("customInstrument.editSource")
            }
            metadataMenu
        }
        .modifier(CustomInstrumentMetadataSheets(
            defID: defID,
            def: def,
            engine: engine,
            selection: $selection,
            isShowingRename: $isShowingRename,
            isShowingCompatibility: $isShowingCompatibility,
            isShowingFeaturesEditor: $isShowingFeaturesEditor,
            isShowingWidgetsEditor: $isShowingWidgetsEditor,
            isShowingDeleteConfirm: $isShowingDeleteConfirm,
            renameEntrypointPrompt: $renameEntrypointPrompt
        ))
    }

    @ViewBuilder
    private var metadataMenu: some View {
        if def != nil {
            Menu {
                Button {
                    isShowingRename = true
                } label: {
                    Label("Rename & Icon\u{2026}", systemImage: "pencil")
                }
                Button {
                    isShowingCompatibility = true
                } label: {
                    Label("Compatibility\u{2026}", systemImage: "checkmark.shield")
                }
                Button {
                    isShowingFeaturesEditor = true
                } label: {
                    Label("Features\u{2026}", systemImage: "switch.2")
                }
                Button {
                    isShowingWidgetsEditor = true
                } label: {
                    Label("Widgets\u{2026}", systemImage: "chart.xyaxis.line")
                }
                if let entrypoint = def?.entrypoint {
                    Divider()
                    Button {
                        renameEntrypointPrompt.present(current: entrypoint)
                    } label: {
                        Label("Rename Entrypoint File\u{2026}", systemImage: "pencil")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    isShowingDeleteConfirm = true
                } label: {
                    Label("Delete Custom Instrument", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Custom instrument actions")
        }
    }

    private func stateBinding(for feature: CustomInstrumentDef.Feature) -> Binding<FeatureState> {
        Binding(
            get: {
                config.features[feature.id]
                    ?? FeatureState(enabled: feature.enabledByDefault, value: feature.schema.defaultValue)
            },
            set: { newValue in
                var updated = config
                updated.features[feature.id] = newValue
                config = updated
            }
        )
    }
}

private struct CustomInstrumentMetadataSheets: ViewModifier {
    let defID: UUID
    let def: CustomInstrumentDef?
    let engine: Engine
    @Binding var selection: SidebarItemID?
    @Binding var isShowingRename: Bool
    @Binding var isShowingCompatibility: Bool
    @Binding var isShowingFeaturesEditor: Bool
    @Binding var isShowingWidgetsEditor: Bool
    @Binding var isShowingDeleteConfirm: Bool
    @Binding var renameEntrypointPrompt: RenamePromptState

    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isShowingRename, arrowEdge: .trailing) {
                if let def {
                    CustomInstrumentRenamePopover(def: def, engine: engine)
                }
            }
            .popover(isPresented: $isShowingCompatibility, arrowEdge: .trailing) {
                if let def {
                    CustomInstrumentCompatibilityPopover(def: def, engine: engine)
                }
            }
            .popover(isPresented: $isShowingFeaturesEditor, arrowEdge: .trailing) {
                if let def {
                    CustomInstrumentFeaturesPopover(def: def, engine: engine)
                }
            }
            .popover(isPresented: $isShowingWidgetsEditor, arrowEdge: .trailing) {
                if let def {
                    CustomInstrumentWidgetsPopover(def: def, engine: engine)
                }
            }
            .alert("Rename Entrypoint File", isPresented: $renameEntrypointPrompt.isPresented) {
                TextField("path/to/file.ts", text: $renameEntrypointPrompt.draft)
                    .disableAutocorrection(true)
                Button("Rename") { commitRenameEntrypoint() }
                    .disabled(!renameEntrypointPrompt.canCommit(originalPath: def?.entrypoint ?? ""))
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Renames the entrypoint file and updates the entrypoint automatically.")
            }
            .confirmationDialog(
                "Delete \"\(def?.name ?? "")\"?",
                isPresented: $isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteInstrument() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the custom instrument from the project and from any sessions where it is loaded.")
            }
    }

    private func commitRenameEntrypoint() {
        let trimmed = renameEntrypointPrompt.draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let original = def?.entrypoint, trimmed != original else { return }
        let id = defID
        Task { @MainActor in
            await engine.renameCustomInstrumentFile(defID: id, from: original, to: trimmed)
            await engine.setCustomInstrumentEntrypoint(defID: id, path: trimmed)
        }
    }

    private func deleteInstrument() {
        let id = defID
        Task { @MainActor in
            await engine.deleteCustomInstrument(id)
            if selection?.belongsTo(defID: id) ?? false {
                selection = .notebook
            }
        }
    }
}
