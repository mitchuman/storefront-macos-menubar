import SwiftUI

/// Accumulates each rail row's frame (in the shared "panel" coordinate space) into a
/// single dictionary so `SafeTriangleController` can hit-test the cursor against them.
struct RowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Store.ID: CGRect] = [:]

    static func reduce(value: inout [Store.ID: CGRect], nextValue: () -> [Store.ID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
