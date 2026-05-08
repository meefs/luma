import Adw
import Foundation
import Gtk
import LumaCore

@MainActor
enum SessionDetachedBanner {
    static func make(
        for session: LumaCore.ProcessSession,
        gatingActive: Bool,
        onReattach: @escaping () -> Void,
        onDisarm: @escaping () -> Void,
        onArm: @escaping () -> Void,
        onResumeGating: @escaping () -> Void
    ) -> Adw.Banner {
        if isArmedAndIdle(session) {
            return makeArmed(
                for: session,
                gatingActive: gatingActive,
                onDisarm: onDisarm,
                onResumeGating: onResumeGating
            )
        }
        if session.lastAttachedAt == nil {
            return makeIdle(for: session, onArm: onArm)
        }
        let banner = Adw.Banner(title: title(for: session))
        banner.useMarkup = true
        banner.buttonLabel = "\(session.kind.reestablishLabel)\u{2026}"
        banner.setButton(style: .suggested)
        banner.revealed = true
        banner.sensitive = session.phase != .attaching
        banner.onButtonClicked { _ in
            MainActor.assumeIsolated { onReattach() }
        }
        return banner
    }

    private static func makeArmed(
        for session: LumaCore.ProcessSession,
        gatingActive: Bool,
        onDisarm: @escaping () -> Void,
        onResumeGating: @escaping () -> Void
    ) -> Adw.Banner {
        let banner = Adw.Banner(title: armedTitle(for: session, gatingActive: gatingActive))
        banner.useMarkup = true
        banner.revealed = true
        if !gatingActive {
            banner.buttonLabel = "Resume"
            banner.setButton(style: .suggested)
            banner.onButtonClicked { _ in
                MainActor.assumeIsolated { onResumeGating() }
            }
        } else {
            banner.buttonLabel = "Disarm"
            banner.onButtonClicked { _ in
                MainActor.assumeIsolated { onDisarm() }
            }
        }
        return banner
    }

    private static func makeIdle(
        for session: LumaCore.ProcessSession,
        onArm: @escaping () -> Void
    ) -> Adw.Banner {
        let banner = Adw.Banner(title: idleTitle(for: session))
        banner.useMarkup = true
        banner.buttonLabel = "Arm\u{2026}"
        banner.setButton(style: .suggested)
        banner.revealed = true
        banner.onButtonClicked { _ in
            MainActor.assumeIsolated { onArm() }
        }
        return banner
    }

    private static func idleTitle(for session: LumaCore.ProcessSession) -> String {
        let name = escapeMarkup(session.processName)
        return "<b>\(name)</b> · Idle — not waiting for a launch."
    }

    private static func isArmedAndIdle(_ session: LumaCore.ProcessSession) -> Bool {
        guard case .armed = session.armingState else { return false }
        return session.phase != .attached
    }

    private static func armedTitle(for session: LumaCore.ProcessSession, gatingActive: Bool) -> String {
        let name = escapeMarkup(session.processName)
        return "<b>\(name)</b> · \(escapeMarkup(armedStatusText(for: session, gatingActive: gatingActive)))"
    }

    private static func armedStatusText(for session: LumaCore.ProcessSession, gatingActive: Bool) -> String {
        if let lastError = session.lastError, !lastError.isEmpty {
            return "Armed but inactive — \(lastError)"
        }
        if !gatingActive {
            return "Armed but inactive — spawn gating is paused. Resume to enable it."
        }
        let pattern = session.armingState.matchPattern ?? ""
        return pattern.isEmpty
            ? "Waiting for the next matching launch."
            : "Waiting for the next launch matching \(pattern)."
    }

    private static func title(for session: LumaCore.ProcessSession) -> String {
        let name = escapeMarkup(session.processName)
        guard let status = statusText(for: session) else {
            return "<b>\(name)</b>"
        }
        return "<b>\(name)</b> · \(escapeMarkup(status))"
    }

    private static func statusText(for session: LumaCore.ProcessSession) -> String? {
        if session.phase == .attaching {
            return "\(session.kind.reestablishLabel)ing\u{2026}"
        }
        if let lastError = session.lastError, !lastError.isEmpty {
            return "Last \(session.kind.verbDisplayName) attempt failed: \(lastError)"
        }
        switch session.detachReason {
        case .applicationRequested:
            return nil
        case .processReplaced:
            return "Detached because the process was replaced."
        case .processTerminated:
            return "Detached because the process terminated."
        case .connectionTerminated:
            return "Detached because the connection was terminated."
        case .deviceLost:
            return "Detached because the device connection was lost."
        }
    }

    private static func escapeMarkup(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "'": out.append("&apos;")
            case "\"": out.append("&quot;")
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    static func shouldShow(for session: LumaCore.ProcessSession) -> Bool {
        if session.phase == .attached { return false }
        if session.phase == .attaching && session.lastAttachedAt == nil { return false }
        return true
    }
}
