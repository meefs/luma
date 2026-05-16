import SwiftUI

struct PopoverFormSheetModifier: ViewModifier {
    let width: CGFloat
    let maxHeight: CGFloat?

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #else
        if let maxHeight {
            content.frame(width: width).frame(maxHeight: maxHeight)
        } else {
            content.frame(width: width)
        }
        #endif
    }
}

extension View {
    /// Wraps a popover body so it has a fixed width on macOS but expands to
    /// fill the adaptive sheet on iOS without centering its content vertically.
    func popoverFormSheet(width: CGFloat, maxHeight: CGFloat? = nil) -> some View {
        modifier(PopoverFormSheetModifier(width: width, maxHeight: maxHeight))
    }
}
