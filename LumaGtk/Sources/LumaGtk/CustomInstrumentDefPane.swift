import Adw
import CGtk
import Foundation
import GLibObject
import Gtk
import LumaCore

@MainActor
final class CustomInstrumentDefPane {
    let widget: Box
    private(set) var def: CustomInstrumentDef
    private(set) var file: CustomInstrumentFile

    private weak var engine: Engine?
    private let sourceEditor: MonacoEditor
    private let saveButton: Button
    private let headerNameLabel: Label
    private let headerPathLabel: Label
    private let headerEntrypointTag: Label
    private let headerIconHost: Box
    private var draftContent: String

    init(engine: Engine, def: CustomInstrumentDef, file: CustomInstrumentFile, sourceEditor: MonacoEditor) {
        self.engine = engine
        self.def = def
        self.file = file
        self.draftContent = file.content
        self.sourceEditor = sourceEditor

        widget = Box(orientation: .vertical, spacing: 8)
        widget.hexpand = true
        widget.vexpand = true
        widget.marginTop = 12

        saveButton = Button(label: "Save")
        saveButton.add(cssClass: "suggested-action")
        saveButton.sensitive = false

        headerNameLabel = Label(str: def.name)
        headerNameLabel.halign = .start
        headerNameLabel.add(cssClass: "title-3")

        headerPathLabel = Label(str: file.path)
        headerPathLabel.halign = .start
        headerPathLabel.add(cssClass: "caption")
        headerPathLabel.add(cssClass: "dim-label")

        headerEntrypointTag = Label(str: "entrypoint")
        headerEntrypointTag.add(cssClass: "caption")
        headerEntrypointTag.add(cssClass: "accent")
        headerEntrypointTag.visible = file.path == def.entrypoint

        headerIconHost = Box(orientation: .horizontal, spacing: 0)
        headerIconHost.append(child: InstrumentIconView.makeImage(for: def.icon, pixelSize: 24))

        saveButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.commit() }
        }

        layout()
    }

    func refresh(def: CustomInstrumentDef, file: CustomInstrumentFile) {
        let pathChanged = self.file.path != file.path
        let storedContentChanged = self.file.content != file.content
        if pathChanged {
            flushDraftIfNeeded()
        }
        self.def = def
        self.file = file
        headerNameLabel.label = def.name
        headerPathLabel.label = file.path
        headerEntrypointTag.visible = file.path == def.entrypoint
        replaceIconHost()
        let packages = (try? engine?.store.fetchPackagesState().packages) ?? []
        sourceEditor.setProfile(currentProfile(def: def, file: file, packages: packages))
        if pathChanged || (storedContentChanged && !isDirty()) {
            sourceEditor.setText(file.content)
            draftContent = file.content
            saveButton.sensitive = false
        }
    }

    private func currentProfile(
        def: CustomInstrumentDef,
        file: CustomInstrumentFile,
        packages: [LumaCore.InstalledPackage]
    ) -> EditorProfile {
        let files = engine?.customInstruments.files(forDefID: def.id) ?? []
        return EditorProfile.fridaCustomInstrument(
            packages: packages,
            def: def,
            files: files,
            activePath: CustomInstrumentFile.workspaceRelativePath(defID: def.id, path: file.path)
        )
    }

    private func replaceIconHost() {
        var child = headerIconHost.firstChild
        while let cur = child {
            child = cur.nextSibling
            headerIconHost.remove(child: cur)
        }
        headerIconHost.append(child: InstrumentIconView.makeImage(for: def.icon, pixelSize: 24))
    }

    private func layout() {
        widget.append(child: header())
        widget.append(child: sourceEditorContainer())
    }

    private func header() -> Box {
        let row = Box(orientation: .horizontal, spacing: 8)
        row.marginStart = 12
        row.marginEnd = 12
        row.append(child: headerIconHost)

        let titles = Box(orientation: .vertical, spacing: 0)
        titles.hexpand = true
        titles.append(child: headerNameLabel)

        let pathRow = Box(orientation: .horizontal, spacing: 6)
        pathRow.append(child: headerPathLabel)
        pathRow.append(child: headerEntrypointTag)
        titles.append(child: pathRow)

        row.append(child: titles)
        row.append(child: saveButton)
        return row
    }

    private func sourceEditorContainer() -> Box {
        let container = Box(orientation: .vertical, spacing: 0)
        container.hexpand = true
        container.vexpand = true
        let packages = (try? engine?.store.fetchPackagesState().packages) ?? []
        sourceEditor.setProfile(currentProfile(def: def, file: file, packages: packages))
        sourceEditor.setText(draftContent)
        sourceEditor.installInto(container)
        sourceEditor.onTextChanged = { [weak self] text in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.draftContent = text
                self.saveButton.sensitive = self.isDirty()
            }
        }
        return container
    }

    private func commit() {
        guard let engine else { return }
        let defID = def.id
        let path = file.path
        let content = draftContent
        Task { @MainActor in
            await engine.writeCustomInstrumentFile(defID: defID, path: path, content: content)
            self.saveButton.sensitive = false
        }
    }

    func flushDraftIfNeeded() {
        guard isDirty(), let engine else { return }
        let defID = def.id
        let path = file.path
        let content = draftContent
        Task { @MainActor in
            await engine.writeCustomInstrumentFile(defID: defID, path: path, content: content)
        }
    }

    private func isDirty() -> Bool {
        draftContent != file.content
    }
}
