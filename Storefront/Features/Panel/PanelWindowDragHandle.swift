import SwiftUI

/// Floating-panel-only: drag the window from a label (e.g. store title).
/// Uses SwiftUI’s `WindowDragGesture` so it never installs an AppKit view that
/// can steal hits from neighboring controls.
struct PanelWindowDragModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            if #available(macOS 15.0, *) {
                content.gesture(WindowDragGesture())
            } else {
                content
            }
        } else {
            content
        }
    }
}
