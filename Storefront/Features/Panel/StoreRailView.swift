import SwiftUI

struct StoreRailView: View {
    @EnvironmentObject var appState: AppState
    @FocusState.Binding var searchFocused: Bool
    @Environment(\.openSettings) private var openSettings

    var filteredStores: [Store] {
        let stores = appState.visibleStores
        guard !appState.query.isEmpty else { return stores }
        return stores.filter { $0.displayName.localizedCaseInsensitiveContains(appState.query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            searchField
                .padding(.bottom, 7)

            Text("STORES · \(appState.visibleStores.count)")
                .font(.mono(9.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMeta36)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            ForEach(Array(filteredStores.enumerated()), id: \.element.id) { index, store in
                StoreRowView(store: store, shortcutIndex: index + 1, isSelected: store.id == appState.selectedStoreID) {
                    appState.toggleFavorite(store)
                }
            }

            Spacer(minLength: 0)

            railAction(title: "Settings…", shortcut: "⌘,") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 7)
        .frame(width: Theme.railWidth)
        .background(Theme.railBackground)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMeta30)
            TextField("Search all stores", text: Binding(
                get: { appState.query },
                set: { appState.query = $0.replacingOccurrences(of: "\n", with: "") }
            ))
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .focused($searchFocused)
                .onSubmit { }
            Text(appState.settings.globalHotkey.displayString)
                .font(.mono(9.5))
                .foregroundStyle(Theme.textMeta25)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.searchFill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func railAction(title: String, shortcut: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(shortcut)
                    .font(.mono(10.5))
                    .foregroundStyle(Theme.textMeta25)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct StoreRowView: View {
    @EnvironmentObject var safeTriangle: SafeTriangleController
    let store: Store
    let shortcutIndex: Int
    let isSelected: Bool
    let onToggleFavorite: () -> Void
    @State private var isHovering = false

    private var isSuppressed: Bool { safeTriangle.suppressedRowID == store.id }
    /// Hover state used for visual affordances only — false while the safe triangle is
    /// suppressing this row, so it shows no highlight at all mid-transit.
    private var effectiveHovering: Bool { isHovering && !isSuppressed }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(store.color)
                .frame(width: 7, height: 7)
            Text(store.displayName)
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textBody)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            StarButton(isFavorite: store.isFavorite, isRowHovering: effectiveHovering, action: onToggleFavorite)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: RowFramePreferenceKey.self, value: [store.id: geo.frame(in: .named("panel"))])
            }
        )
        .onHover { hovering in
            // Selection itself is driven centrally by SafeTriangleController, sourced
            // from one continuous mouse-tracking stream — this is only for this row's
            // own local visual state (its hover fill, the star's fade-in).
            isHovering = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected { return Theme.controlFill }
        if effectiveHovering { return Theme.hoverFill }
        return .clear
    }
}

/// Favorite toggle at a row's trailing edge. Always reserves its frame and only
/// fades via opacity (visible when favorited, or while the row is hovered) so
/// its appearance never shifts the row's layout.
private struct StarButton: View {
    let isFavorite: Bool
    let isRowHovering: Bool
    let action: () -> Void

    var body: some View {
        Image(systemName: isFavorite ? "star.fill" : "star")
            .font(.system(size: 10))
            .foregroundStyle(isFavorite ? Theme.accent : Theme.textMeta30)
            .frame(width: 16, height: 16)
            .opacity(isFavorite || isRowHovering ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}
