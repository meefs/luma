import Foundation

@MainActor
enum MissionMarkdown {
    static func pangoMarkup(from text: String) -> String {
        let escaped = StyledTextPango.escape(text)
        var out = ""
        out.reserveCapacity(escaped.count)
        var i = escaped.startIndex
        while i < escaped.endIndex {
            if escaped[i...].hasPrefix("```") {
                let openEnd = escaped.index(i, offsetBy: 3)
                if let closeRange = escaped.range(of: "```", range: openEnd..<escaped.endIndex) {
                    let body = String(escaped[openEnd..<closeRange.lowerBound])
                    out += "<tt>\(stripFenceLanguage(body))</tt>"
                    i = closeRange.upperBound
                    continue
                }
                out.append(escaped[i])
                i = escaped.index(after: i)
                continue
            }
            if escaped[i...].hasPrefix("**") {
                let bodyStart = escaped.index(i, offsetBy: 2)
                if let closeRange = escaped.range(of: "**", range: bodyStart..<escaped.endIndex) {
                    let body = String(escaped[bodyStart..<closeRange.lowerBound])
                    out += "<b>\(body)</b>"
                    i = closeRange.upperBound
                    continue
                }
            }
            if escaped[i] == "*" || escaped[i] == "_" {
                let marker = escaped[i]
                let bodyStart = escaped.index(after: i)
                if let close = scanInlineDelimiter(escaped, from: bodyStart, marker: marker) {
                    let body = String(escaped[bodyStart..<close])
                    out += "<i>\(body)</i>"
                    i = escaped.index(after: close)
                    continue
                }
            }
            if escaped[i] == "`" {
                let bodyStart = escaped.index(after: i)
                if let close = escaped[bodyStart...].firstIndex(of: "`") {
                    let body = String(escaped[bodyStart..<close])
                    out += "<tt>\(body)</tt>"
                    i = escaped.index(after: close)
                    continue
                }
            }
            out.append(escaped[i])
            i = escaped.index(after: i)
        }
        return out
    }

    private static func scanInlineDelimiter(
        _ string: String,
        from start: String.Index,
        marker: Character
    ) -> String.Index? {
        var idx = start
        while idx < string.endIndex {
            if string[idx] == marker {
                let next = string.index(after: idx)
                if next == string.endIndex || string[next] != marker {
                    return idx
                }
            }
            if string[idx] == "\n" { return nil }
            idx = string.index(after: idx)
        }
        return nil
    }

    private static func stripFenceLanguage(_ body: String) -> String {
        guard let first = body.first, first != "\n" else {
            var s = body
            if s.first == "\n" { s.removeFirst() }
            if s.last == "\n" { s.removeLast() }
            return s
        }
        if let nl = body.firstIndex(of: "\n") {
            var s = String(body[body.index(after: nl)...])
            if s.last == "\n" { s.removeLast() }
            return s
        }
        return body
    }
}
