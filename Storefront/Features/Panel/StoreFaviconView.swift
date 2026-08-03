import SwiftUI
import AppKit

/// Rounded store mark: cached favicon when available, otherwise initials on the store accent.
struct StoreFaviconView: View {
    let store: Store
    var size: CGFloat = 18
    var cornerRadius: CGFloat? = nil

    @ObservedObject private var favicons = FaviconStore.shared

    private var radius: CGFloat { cornerRadius ?? size * 0.22 }

    var body: some View {
        Group {
            if let image = favicons.image(for: store.id) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        // Touch `revision` so the view refreshes when a download finishes.
        .animation(nil, value: favicons.revision)
    }

    private var initialsFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(store.color)
            Text(store.initials)
                .font(.system(size: max(8, size * 0.42), weight: .semibold))
                .foregroundStyle(store.accentTextColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}
