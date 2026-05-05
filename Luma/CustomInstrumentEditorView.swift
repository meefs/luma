import LumaCore
import SwiftUI
import SwiftyMonaco

struct CustomInstrumentEditorView: View {
    let defID: UUID
    @ObservedObject var workspace: Workspace

    @State private var draftSource: String = ""
    @State private var isDirty = false
    @State private var showSavedCheck = false

    private var def: CustomInstrumentDef? {
        workspace.engine.customInstruments.def(withId: defID)
    }

    var body: some View {
        Group {
            if let def {
                content(def: def)
            } else {
                Text("Custom instrument not found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func content(def: CustomInstrumentDef) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header(def: def)
            Divider()
            CodeEditorView(
                text: $draftSource,
                profile: EditorProfile.fridaCustomInstrument(
                    packages: workspace.engine.installedPackages,
                    def: def
                ),
                introspector: nil,
                workspace: workspace,
            )
            .accessibilityIdentifier("customInstrument.editor")
        }
        .padding(.top, 4)
        .onAppear { syncFromDef(def) }
        .onChange(of: defID) { _, _ in
            if let d = self.def { syncFromDef(d) }
        }
        .onChange(of: draftSource) { _, _ in recomputeDirty() }
    }

    private func header(def: CustomInstrumentDef) -> some View {
        HStack(spacing: 8) {
            Image(systemName: def.iconSystemName)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name).font(.headline)
                Text("Custom instrument")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            saveStatusIcon
            Button("Save") { saveDraft() }
                .disabled(!isDirty)
                .accessibilityIdentifier("customInstrument.save")
                .keyboardShortcut("s", modifiers: [.command])
        }
    }

    private var saveStatusIcon: some View {
        ZStack {
            if isDirty {
                Circle().frame(width: 6, height: 6)
            }
            if showSavedCheck {
                Image(systemName: "checkmark.circle.fill")
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: 14, height: 14)
    }

    private func saveDraft() {
        guard var d = def else { return }
        d.source = draftSource
        Task { @MainActor in
            await workspace.engine.updateCustomInstrument(d)
            isDirty = false
            showSavedCheck = true
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { showSavedCheck = false }
        }
    }

    private func syncFromDef(_ def: CustomInstrumentDef) {
        draftSource = def.source
        isDirty = false
    }

    private func recomputeDirty() {
        guard let def else { return }
        isDirty = draftSource != def.source
    }
}

struct CustomInstrumentFeaturesPopover: View {
    let def: CustomInstrumentDef
    @ObservedObject var workspace: Workspace
    @Environment(\.dismiss) private var dismiss

    @State private var draftFeatures: [CustomInstrumentDef.Feature] = []
    @State private var newFeatureID: String = ""
    @State private var newFeatureName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Features").font(.headline)
            Text("Per-session knobs the user can configure. Each has a typed schema (boolean, number, string, regex, combo, object, array, …). Agent code reads `config.features.<id>` directly; optional features may be undefined when the user has disabled them.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            featureList

            HStack(spacing: 6) {
                TextField("id", text: $newFeatureID).frame(maxWidth: 140)
                TextField("Name", text: $newFeatureName)
                Button("Add") { addFeature() }
                    .disabled(newFeatureID.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Spacer()
                Button("Done") { commit() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 520)
        .onAppear { draftFeatures = def.features }
    }

    @ViewBuilder
    private var featureList: some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            if draftFeatures.isEmpty {
                Text("No features defined.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach($draftFeatures) { $feature in
                    FeatureRow(feature: $feature) {
                        draftFeatures.removeAll { $0.id == feature.id }
                    }
                }
            }
        }

        ScrollView {
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func addFeature() {
        let id = newFeatureID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !draftFeatures.contains(where: { $0.id == id }) else { return }
        let typedName = newFeatureName.trimmingCharacters(in: .whitespaces)
        let displayName = typedName.isEmpty ? id : typedName
        draftFeatures.append(.init(id: id, name: displayName, schema: .boolean, optional: false))
        newFeatureID = ""
        newFeatureName = ""
    }

    private func commit() {
        var updated = def
        updated.features = draftFeatures
        Task { @MainActor in
            await workspace.engine.updateCustomInstrument(updated)
            dismiss()
        }
    }
}

private struct FeatureRow: View {
    @Binding var feature: CustomInstrumentDef.Feature
    let onDelete: () -> Void
    @State private var isExpanded: Bool = false

    private var isBooleanSchema: Bool {
        if case .boolean = feature.schema { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)
                Text(feature.id).font(.system(.caption, design: .monospaced))
                Text("—").foregroundStyle(.secondary)
                Text(feature.name)
                Spacer()
                Text(SchemaKind(from: feature.schema).label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !isBooleanSchema {
                        Toggle("Optional (user can disable)", isOn: $feature.optional)
                            .platformCheckboxToggleStyle()
                    }
                    if feature.optional {
                        Toggle("Enabled by default", isOn: $feature.enabledByDefault)
                            .platformCheckboxToggleStyle()
                    }
                    CustomInstrumentSchemaEditor(schema: $feature.schema)
                }
                .padding(.leading, 20)
                .padding(.top, 4)
                .onChange(of: feature.schema) { _, newSchema in
                    if case .boolean = newSchema, feature.optional {
                        feature.optional = false
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
    }
}
