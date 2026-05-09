import LumaCore
import SwiftUI

struct MissionInputBar: View {
    @ObservedObject var workspace: Workspace
    let mission: Mission

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 36, maxHeight: 96)
                .focused($isFocused)

            VStack(alignment: .trailing, spacing: 4) {
                Button("Send") { send(interrupt: false) }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Send Now") { send(interrupt: true) }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(mission.status != .running)
            }
            .disabled(trimmedDraft.isEmpty)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send(interrupt: Bool) {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        if interrupt {
            workspace.engine.sendMissionUserMessageNow(missionID: mission.id, text: text)
        } else {
            workspace.engine.appendMissionUserMessage(missionID: mission.id, text: text)
        }
        draft = ""
        isFocused = true
    }
}
