import SwiftUI
import AppKit

/// A transparent, click-through overlay that reports continuous mouse-moved positions
/// (in its own flipped, top-left-origin coordinate space — matching SwiftUI's own
/// coordinate convention) via `onMove`. Backed by an `NSTrackingArea`, so it only
/// observes while actually visible on screen; no manual start/stop needed.
struct MouseTrackingOverlay: NSViewRepresentable {
    let onMove: (CGPoint) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMove = onMove
    }
}

final class TrackingNSView: NSView {
    var onMove: ((CGPoint) -> Void)?
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMove?(point)
    }

    /// SwiftUI's `.allowsHitTesting(false)` governs SwiftUI's own gesture system, not
    /// necessarily this raw NSView's hit-testing at the AppKit level — without this
    /// override, this view can still win `hitTest` for real clicks and swallow them
    /// before they reach the buttons/tap gestures underneath. `NSTrackingArea` mouse
    /// tracking is independent of `hitTest` and keeps working regardless.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
