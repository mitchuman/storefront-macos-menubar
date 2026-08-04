import SwiftUI

/// Protects the rail's hover-to-select navigation against accidental switches while the
/// cursor is transiting diagonally from the selected row toward the right panel — the
/// same "safe triangle" technique browser context menus use to keep a submenu open while
/// the cursor crosses sibling items on the way to it.
///
/// The apex freezes at the point the cursor first leaves the selected row for a
/// different one, paired with the right panel's fixed near-edge (top-left/bottom-left)
/// corners as the base. A row hover is suppressed (no highlight, no selection change) as
/// long as the cursor keeps landing inside that frozen triangle; it stops being
/// suppressed the moment the trajectory exits the triangle, a timeout elapses, or the
/// cursor reaches the panel.
///
/// (An earlier version recomputed the triangle every move using the *current* point as
/// the apex, tested against the *previous* point. That collapses to near-zero tolerance
/// in practice — consecutive `mouseMoved` events are only a pixel or two apart, so the
/// triangle's cross-section at that scale is razor-thin and the containment test almost
/// never passes. Freezing the apex at the transition point gives the test a triangle
/// wide enough to actually match natural mouse movement.)
@MainActor
final class SafeTriangleController: ObservableObject {
    @Published private(set) var suppressedRowID: Store.ID?

    private var rowFrames: [Store.ID: CGRect] = [:]
    private var rightPanelFrame: CGRect = .zero
    private var selectedRowID: Store.ID?
    private var onSelect: ((Store.ID) -> Void)?

    private var apex: CGPoint?
    private var isProtecting = false
    private var protectionDeadline: Date?
    private static let timeout: TimeInterval = 0.45

    func configure(onSelect: @escaping (Store.ID) -> Void) {
        self.onSelect = onSelect
    }

    func updateRowFrames(_ frames: [Store.ID: CGRect]) {
        rowFrames = frames
    }

    func updateRightPanelFrame(_ frame: CGRect) {
        rightPanelFrame = frame
    }

    func updateSelectedRowID(_ id: Store.ID?) {
        selectedRowID = id
    }

    func handleMouseMoved(to current: CGPoint) {
        guard rightPanelFrame != .zero else { return }

        // Cursor has reached the panel — nothing left to protect against.
        guard current.x < rightPanelFrame.minX else {
            endProtection()
            return
        }

        guard let hoveredRowID = rowFrames.first(where: { $0.value.contains(current) })?.key,
              hoveredRowID != selectedRowID else {
            endProtection()
            return
        }

        guard isProtecting, let apex else {
            // First moment the cursor has left the selected row for a different one —
            // freeze the apex here and hold off on selecting while we see where it goes.
            apex = current
            isProtecting = true
            protectionDeadline = Date().addingTimeInterval(Self.timeout)
            setSuppressedRowID(hoveredRowID)
            return
        }

        let base1 = CGPoint(x: rightPanelFrame.minX, y: rightPanelFrame.minY)
        let base2 = CGPoint(x: rightPanelFrame.minX, y: rightPanelFrame.maxY)

        guard !isTimedOut, Self.pointInTriangle(current, apex, base1, base2) else {
            // Trajectory broke (or timed out) — this is a deliberate hover, select it.
            endProtection()
            onSelect?(hoveredRowID)
            return
        }

        setSuppressedRowID(hoveredRowID)
    }

    private var isTimedOut: Bool {
        guard let protectionDeadline else { return false }
        return Date() > protectionDeadline
    }

    private func endProtection() {
        isProtecting = false
        apex = nil
        protectionDeadline = nil
        setSuppressedRowID(nil)
    }

    /// Avoid `@Published` noise when the suppressed row hasn't changed — every rail row
    /// observes this controller, so redundant assigns would refresh the whole list.
    private func setSuppressedRowID(_ id: Store.ID?) {
        guard suppressedRowID != id else { return }
        suppressedRowID = id
    }

    /// Standard sign-based point-in-triangle test.
    private static func pointInTriangle(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
        func sign(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
            (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
        }
        let d1 = sign(p, a, b)
        let d2 = sign(p, b, c)
        let d3 = sign(p, c, a)
        let hasNegative = (d1 < 0) || (d2 < 0) || (d3 < 0)
        let hasPositive = (d1 > 0) || (d2 > 0) || (d3 > 0)
        return !(hasNegative && hasPositive)
    }
}
