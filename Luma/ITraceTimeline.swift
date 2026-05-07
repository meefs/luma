import LumaCore
import SwiftUI

struct ITraceTimeline: View {
    let functionCalls: [TraceFunctionCall]
    let totalEntryCount: Int
    @Binding var selectedCallIndex: Int?

    @Environment(\.colorScheme) private var colorScheme

    @State private var pageStart: Int = 0

    private let stripHeight: CGFloat = 32
    private static let paginationThreshold: Int = 200
    private static let pageSize: Int = 100

    var body: some View {
        if functionCalls.count > Self.paginationThreshold {
            paginatedTimeline
        } else {
            timelineStrip(calls: functionCalls, baseIndex: 0, denom: totalEntryCount)
        }
    }

    private var paginatedTimeline: some View {
        let clampedStart = clampedPageStart()
        let pageEnd = min(clampedStart + Self.pageSize, functionCalls.count)
        let pageCalls = Array(functionCalls[clampedStart..<pageEnd])
        let pageDenom = pageCalls.reduce(0) { $0 + $1.entryCount }
        return VStack(spacing: 4) {
            paginationControls(start: clampedStart, end: pageEnd)
            timelineStrip(calls: pageCalls, baseIndex: clampedStart, denom: pageDenom)
        }
        .onChange(of: selectedCallIndex) { _, newValue in
            guard let idx = newValue else { return }
            if idx < clampedStart || idx >= pageEnd {
                pageStart = (idx / Self.pageSize) * Self.pageSize
            }
        }
    }

    private func paginationControls(start: Int, end: Int) -> some View {
        HStack(spacing: 8) {
            Button {
                pageStart = max(0, start - Self.pageSize)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(start == 0)

            Text("\(start + 1)–\(end) of \(functionCalls.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                pageStart = min(start + Self.pageSize, lastPageStart())
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(end >= functionCalls.count)
        }
        .padding(.horizontal, 4)
    }

    private func clampedPageStart() -> Int {
        max(0, min(pageStart, lastPageStart()))
    }

    private func lastPageStart() -> Int {
        guard functionCalls.count > 0 else { return 0 }
        let last = ((functionCalls.count - 1) / Self.pageSize) * Self.pageSize
        return last
    }

    private func timelineStrip(calls: [TraceFunctionCall], baseIndex: Int, denom: Int) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let denominator = max(1, denom)

            Canvas { context, size in
                guard !calls.isEmpty else { return }

                var x: CGFloat = 0
                for (i, call) in calls.enumerated() {
                    let w = max(2, CGFloat(call.entryCount) / CGFloat(denominator) * width)
                    let absoluteIndex = baseIndex + i
                    let isSelected = selectedCallIndex == absoluteIndex

                    let hue = functionHue(call.functionName)
                    let color = Color(
                        hue: hue,
                        saturation: colorScheme == .dark ? 0.7 : 0.6,
                        brightness: colorScheme == .dark ? 0.55 : 0.7
                    )

                    let rect = CGRect(x: x, y: 0, width: w, height: size.height)
                    context.fill(Path(rect), with: .color(color))

                    if i > 0 {
                        let sep = CGRect(x: x, y: 2, width: 0.5, height: size.height - 4)
                        context.fill(
                            Path(sep),
                            with: .color(colorScheme == .dark ? .black.opacity(0.3) : .white.opacity(0.3))
                        )
                    }

                    if isSelected {
                        let inset = rect.insetBy(dx: 0.5, dy: 0.5)
                        let borderColor: Color = colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.7)
                        context.stroke(Path(roundedRect: inset, cornerRadius: 2), with: .color(borderColor), lineWidth: 1.5)
                    }

                    if w > 30 {
                        let label = call.shortName
                        let textRect = CGRect(x: x + 6, y: 2, width: w - 12, height: size.height - 4)
                        var labelCtx = context
                        labelCtx.clip(to: Path(textRect))
                        let resolved = labelCtx.resolve(
                            Text(label)
                                .font(.system(size: 9, weight: isSelected ? .bold : .regular, design: .monospaced))
                                .foregroundStyle(isSelected ? .white : (colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)))
                        )
                        labelCtx.draw(resolved, at: CGPoint(x: textRect.maxX, y: textRect.midY), anchor: .trailing)
                    }

                    x += w
                }
            }
            .background(colorScheme == .dark ? Color.black.opacity(0.7) : Color(white: 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            #if canImport(AppKit)
            .overlay {
                TimelineTooltipOverlay(
                    functionCalls: calls,
                    totalEntryCount: denominator,
                    width: width,
                    height: stripHeight
                )
            }
            #endif
            .contentShape(Rectangle())
            .onTapGesture { location in
                selectedCallIndex = callIndex(at: location.x, width: width, calls: calls, baseIndex: baseIndex, denom: denominator)
            }
        }
        .frame(height: stripHeight)
    }

    private func callIndex(at x: CGFloat, width: CGFloat, calls: [TraceFunctionCall], baseIndex: Int, denom: Int) -> Int {
        guard !calls.isEmpty, denom > 0 else { return baseIndex }

        var accX: CGFloat = 0
        for (i, call) in calls.enumerated() {
            let w = max(2, CGFloat(call.entryCount) / CGFloat(denom) * width)
            if x < accX + w {
                return baseIndex + i
            }
            accX += w
        }
        return baseIndex + calls.count - 1
    }

    private func functionHue(_ name: String) -> Double {
        var hash: UInt64 = 5381
        for byte in name.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Double(hash % 360) / 360.0
    }
}

#if canImport(AppKit)
import AppKit

private struct TimelineTooltipOverlay: NSViewRepresentable {
    let functionCalls: [TraceFunctionCall]
    let totalEntryCount: Int
    let width: CGFloat
    let height: CGFloat

    func makeNSView(context: Context) -> TimelineTooltipNSView {
        let view = TimelineTooltipNSView()
        view.update(functionCalls: functionCalls, totalEntryCount: totalEntryCount, width: width)
        return view
    }

    func updateNSView(_ view: TimelineTooltipNSView, context: Context) {
        view.update(functionCalls: functionCalls, totalEntryCount: totalEntryCount, width: width)
    }
}

class TimelineTooltipNSView: NSView {
    private var tooltipTags: [NSView.ToolTipTag] = []
    private var owners: [TooltipOwner] = []
    private var trackingArea: NSTrackingArea?

    func update(functionCalls: [TraceFunctionCall], totalEntryCount: Int, width: CGFloat) {
        for tag in tooltipTags {
            removeToolTip(tag)
        }
        tooltipTags.removeAll()
        owners.removeAll()

        guard totalEntryCount > 0 else { return }

        let h = max(bounds.height, 32)

        var x: CGFloat = 0
        for call in functionCalls {
            let w = max(2, CGFloat(call.entryCount) / CGFloat(totalEntryCount) * width)
            let rect = NSRect(x: x, y: 0, width: w, height: h)
            let owner = TooltipOwner(text: call.functionName)
            owners.append(owner)
            let tag = addToolTip(rect, owner: owner, userData: nil)
            tooltipTags.append(tag)
            x += w
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
    override func mouseDown(with event: NSEvent) { superview?.mouseDown(with: event) }
}

private class TooltipOwner: NSObject, NSViewToolTipOwner {
    let text: String

    init(text: String) {
        self.text = text
    }

    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        text
    }
}
#endif
