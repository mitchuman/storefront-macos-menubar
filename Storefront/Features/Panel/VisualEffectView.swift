import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .menu
    // `.withinWindow` keeps the blur based on the popover's own content instead of
    // sampling whatever's on screen behind it (desktop wallpaper, other windows) —
    // `.behindWindow` was picking up a color cast from behind the panel and tinting
    // the native scroll indicator along with it.
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
