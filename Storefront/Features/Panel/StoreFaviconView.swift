import SwiftUI
import AppKit

/// Rounded store mark: cached favicon when available, otherwise initials on the store accent.
struct StoreFaviconView: View {
    let store: Store
    var size: CGFloat = 18
    @Environment(AppState.self) private var appState

    @ObservedObject private var favicons = FaviconStore.shared

    private var radius: CGFloat { size * 0.22 }
    private var cornerStyle: RoundedCornerStyle {
        WidgetChrome.current(settings: appState.settings).cornerStyle
    }

    var body: some View {
        Group {
            if let image = favicons.image(for: store.id) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .background(Theme.faviconPlate)
            } else {
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: cornerStyle))
        // Touch `revision` so the view refreshes when a download finishes.
        .animation(nil, value: favicons.revision)
    }

    private var initialsFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: cornerStyle)
                .fill(store.color)
            Text(store.initials)
                .font(.system(size: max(8, size * 0.42), weight: .semibold))
                .foregroundStyle(store.accentTextColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}
