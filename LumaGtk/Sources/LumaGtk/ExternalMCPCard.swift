import Adw
import Foundation
import Gdk
import Gtk
import LumaCore

@MainActor
final class ExternalMCPCard {
    let widget: Box

    private weak var engine: Engine?
    private let onCopied: (String) -> Void

    private let toggleButton: Button
    private let runningBox: Box
    private let urlValueLabel: Label
    private let tokenValueLabel: Label
    private let descriptionLabel: Label
    private let errorLabel: Label

    private var isToggling = false {
        didSet { refreshToggleSensitivity() }
    }

    init(engine: Engine, onCopied: @escaping (String) -> Void) {
        self.engine = engine
        self.onCopied = onCopied

        widget = Box(orientation: .vertical, spacing: 8)
        toggleButton = Button(label: "Enable")
        descriptionLabel = Label(str: "Run Frida tools from Claude Code or any MCP-aware client.")
        runningBox = Box(orientation: .vertical, spacing: 4)
        urlValueLabel = Label(str: "")
        tokenValueLabel = Label(str: "")
        errorLabel = Label(str: "")

        widget.add(cssClass: "card")
        widget.marginStart = 0
        widget.marginEnd = 0
        widget.marginTop = 0
        widget.marginBottom = 0

        let inner = Box(orientation: .vertical, spacing: 8)
        inner.marginStart = 12
        inner.marginEnd = 12
        inner.marginTop = 12
        inner.marginBottom = 12
        widget.append(child: inner)

        let header = Box(orientation: .horizontal, spacing: 8)
        let icon = Gtk.Image(iconName: "network-transmit-receive-symbolic")
        icon.pixelSize = 16
        icon.add(cssClass: "accent")
        header.append(child: icon)

        let title = Label(str: "External MCP Server")
        title.halign = .start
        title.hexpand = true
        title.add(cssClass: "heading")
        header.append(child: title)

        toggleButton.add(cssClass: "suggested-action")
        header.append(child: toggleButton)
        inner.append(child: header)

        descriptionLabel.halign = .start
        descriptionLabel.wrap = true
        descriptionLabel.xalign = 0
        descriptionLabel.add(cssClass: "dim-label")
        inner.append(child: descriptionLabel)

        runningBox.visible = false
        inner.append(child: runningBox)

        urlValueLabel.add(cssClass: "monospace")
        urlValueLabel.add(cssClass: "caption")
        urlValueLabel.halign = .start
        urlValueLabel.selectable = true
        urlValueLabel.wrap = true
        urlValueLabel.xalign = 0
        runningBox.append(child: ExternalMCPCard.row(label: "URL", value: urlValueLabel))

        tokenValueLabel.add(cssClass: "monospace")
        tokenValueLabel.add(cssClass: "caption")
        tokenValueLabel.halign = .start
        tokenValueLabel.selectable = true
        runningBox.append(child: ExternalMCPCard.row(label: "Bearer token", value: tokenValueLabel))

        let actions = Box(orientation: .horizontal, spacing: 6)
        actions.marginTop = 4

        let claudeCmdButton = Button(label: "Copy `claude mcp add`")
        claudeCmdButton.add(cssClass: "flat")
        claudeCmdButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.copyClaudeCommand() }
        }
        actions.append(child: claudeCmdButton)

        let configButton = Button(label: "Copy MCP config JSON")
        configButton.add(cssClass: "flat")
        configButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.copyMCPConfig() }
        }
        actions.append(child: configButton)

        let rotateButton = Button(label: "Rotate token")
        rotateButton.add(cssClass: "flat")
        rotateButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.rotate() }
        }
        actions.append(child: rotateButton)

        runningBox.append(child: actions)

        errorLabel.halign = .start
        errorLabel.wrap = true
        errorLabel.xalign = 0
        errorLabel.add(cssClass: "error")
        errorLabel.visible = false
        inner.append(child: errorLabel)

        toggleButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.toggle() }
        }

        refresh()
    }

    func refresh() {
        guard let engine else { return }
        if engine.isExternalMCPRunning,
            let url = engine.externalMCPURL,
            let token = engine.externalMCPServer?.bearerToken
        {
            toggleButton.label = "Disable"
            toggleButton.remove(cssClass: "suggested-action")
            urlValueLabel.label = url.absoluteString
            tokenValueLabel.label = String(token.prefix(12)) + "…"
            tokenValueLabel.tooltipText = token
            runningBox.visible = true
            descriptionLabel.visible = false
        } else {
            toggleButton.label = "Enable"
            toggleButton.add(cssClass: "suggested-action")
            runningBox.visible = false
            descriptionLabel.visible = true
        }
    }

    private func toggle() {
        guard let engine else { return }
        if engine.isExternalMCPRunning {
            disable()
        } else {
            enable()
        }
    }

    private func enable() {
        guard let engine else { return }
        isToggling = true
        showError(nil)
        Task { @MainActor [weak self] in
            do {
                _ = try await engine.enableExternalMCPServer()
                self?.showError(nil)
            } catch {
                self?.showError("could not enable: \(error.localizedDescription)")
            }
            self?.isToggling = false
            self?.refresh()
        }
    }

    private func disable() {
        guard let engine else { return }
        isToggling = true
        showError(nil)
        Task { @MainActor [weak self] in
            await engine.disableExternalMCPServer()
            self?.isToggling = false
            self?.refresh()
        }
    }

    private func rotate() {
        guard let engine else { return }
        isToggling = true
        showError(nil)
        Task { @MainActor [weak self] in
            do {
                _ = try await engine.rotateExternalMCPToken()
                self?.showError(nil)
            } catch {
                self?.showError("could not rotate: \(error.localizedDescription)")
            }
            self?.isToggling = false
            self?.refresh()
        }
    }

    private func copyClaudeCommand() {
        guard let engine,
            let url = engine.externalMCPURL,
            let token = engine.externalMCPServer?.bearerToken
        else { return }
        let cmd =
            "claude mcp add --transport http luma '\(url.absoluteString)' --header 'Authorization: Bearer \(token)'"
        copy(cmd)
        onCopied("`claude mcp add` command copied")
    }

    private func copyMCPConfig() {
        guard let engine,
            let url = engine.externalMCPURL,
            let token = engine.externalMCPServer?.bearerToken
        else { return }
        let payload: [String: Any] = [
            "mcpServers": [
                "luma": [
                    "type": "http",
                    "url": url.absoluteString,
                    "headers": ["Authorization": "Bearer \(token)"],
                ]
            ]
        ]
        let data =
            (try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )) ?? Data("{}".utf8)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        copy(json)
        onCopied("MCP config copied")
    }

    private func copy(_ text: String) {
        guard let display = Display.getDefault() else { return }
        display.clipboard.set(text: text)
    }

    private func showError(_ message: String?) {
        if let message {
            errorLabel.label = message
            errorLabel.visible = true
        } else {
            errorLabel.visible = false
        }
    }

    private func refreshToggleSensitivity() {
        toggleButton.sensitive = !isToggling
    }

    private static func row(label: String, value: Label) -> Box {
        let row = Box(orientation: .horizontal, spacing: 8)
        let key = Label(str: "\(label):")
        key.halign = .start
        key.add(cssClass: "dim-label")
        key.add(cssClass: "caption")
        row.append(child: key)
        row.append(child: value)
        return row
    }
}
