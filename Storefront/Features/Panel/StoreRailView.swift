import SwiftUI

struct StoreRailView: View {
    @EnvironmentObject var appState: AppState
    @FocusState.Binding var searchFocused: Bool

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

            Divider().overlay(Theme.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(appState.filteredStores.enumerated()), id: \.element.id) { index, store in
                        StoreRowView(store: store, shortcutIndex: index + 1, isSelected: store.id == appState.selectedStoreID) {
                            appState.toggleFavorite(store)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .frame(maxHeight: .infinity)

            Divider().overlay(Theme.hairline)

            navigationLegend
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
            TextField("Search stores", text: Binding(
                get: { appState.query },
                set: { appState.query = $0.replacingOccurrences(of: "\n", with: "") }
            ))
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .focused($searchFocused)
                .onSubmit { }
            KeyComboView(combo: appState.settings.globalHotkey, font: .system(size: 8, weight: .regular))
                .foregroundStyle(Theme.textMeta25)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.searchFill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// A compact, non-interactive reminder of the panel's keyboard shortcuts — replaces
    /// the old "Settings" row (Settings is still reachable via the status-bar right-click
    /// menu).
    private var navigationLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Navigate:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textMeta36)
                Spacer()
                Button {
                    appState.selectedSettingsTab = .shortcuts
                    // Reuses the same path the status-item menu's tab shortcuts use —
                    // `AppDelegate` posts this same notification because it's an `NSObject`
                    // outside the SwiftUI hierarchy and can't hold `@Environment(\.openWindow)`
                    // itself; from here (a SwiftUI view) it'd be simpler to call it directly,
                    // but reusing the one existing path keeps "how Settings gets opened" in
                    // a single place rather than two slightly different ones.
                    NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.textMeta30)
                }
                .buttonStyle(.plain)
                .help("All keyboard shortcuts")
            }
            legendItem(symbolNames: ["arrow.up", "arrow.down"], label: "Stores")
            legendItem(symbolNames: ["arrow.left", "arrow.right"], label: "Cards")
            legendItem(symbolNames: ["arrow.up", "arrow.down"], label: "Links")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
    }

    private func legendItem(symbolNames: [String], label: String) -> some View {
        HStack(spacing: 5) {
            HStack(spacing: 3) {
                ForEach(Array(symbolNames.enumerated()), id: \.offset) { index, name in
                    if index > 0 {
                        Text("/")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.textMeta30)
                    }
                    Image(systemName: name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textMeta30)
                        .frame(width: 10, alignment: .center)
                }
            }
            .frame(width: 36, alignment: .leading)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textMeta36)
        }
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

    private var showStar: Bool { store.isFavorite || effectiveHovering }
    private var hasBadge: Bool { shortcutIndex <= 9 }

    private static let starWidth: CGFloat = 16
    private static let badgeGap: CGFloat = 2
    private static let edgeGap: CGFloat = 0
    private static let badgeWidth: CGFloat = 18

    /// Distance from the row's trailing edge to the star's own right edge — flush
    /// near the edge when there's no `⌘N` badge, or just past the badge when there is.
    private var starTrailingOffset: CGFloat {
        hasBadge ? Self.badgeWidth + Self.badgeGap : Self.edgeGap
    }

    /// How much room the name needs to reserve while the star is showing, on top of
    /// what the badge slot already reserves natively — small, since in the has-badge
    /// case that native reservation already covers most of it.
    private var nameTrailingReserve: CGFloat {
        guard showStar else { return 0 }
        return hasBadge ? 4 : Self.starWidth + Self.edgeGap
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Text(store.displayName)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textBody)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Only reserved while the star is actually shown, so the name can use
                    // that width the rest of the time — the star itself sits in a fixed
                    // overlay (below) rather than this HStack's flow, so toggling this
                    // padding never shifts the `⌘N` badge that follows.
                    .padding(.trailing, nameTrailingReserve)
                Spacer(minLength: 4)
                shortcutBadge
            }

            StarButton(isFavorite: store.isFavorite, isRowHovering: effectiveHovering, action: onToggleFavorite)
                .padding(.trailing, starTrailingOffset)
                .opacity(showStar ? 1 : 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 9)
        .padding(.vertical, 7)
        .background(rowBackground)
        // A left-edge accent bar instead of a leading color dot — one less element (and
        // its spacing) before the store name, and the color still reads at a glance.
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(store.color)
                .frame(width: 3)
                .padding(.vertical, 5)
        }
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

    /// Collapses to zero width past `⌘9` — `starTrailingOffset` accounts for this same
    /// `hasBadge` check, so the star sits flush near the edge when there's no badge at all.
    private var shortcutBadge: some View {
        Group {
            if hasBadge {
                HStack(spacing: 1) {
                    Image(systemName: "command")
                        .font(.system(size: 8, weight: .medium))
                    Text("\(shortcutIndex)")
                        .font(.mono(9))
                }
            }
        }
        .frame(width: hasBadge ? Self.badgeWidth : 0, alignment: .trailing)
        .foregroundStyle(Theme.textMeta25)
    }

    private var rowBackground: Color {
        if isSelected { return Theme.controlFill }
        if effectiveHovering { return Theme.hoverFill }
        return .clear
    }
}

/// Favorite toggle drawn as a fixed-position overlay (see `StoreRowView`) rather than
/// an `HStack` participant, so its own fade-in/out never nudges any sibling.
private struct StarButton: View {
    let isFavorite: Bool
    let isRowHovering: Bool
    let action: () -> Void

    var body: some View {
        Image(systemName: isFavorite ? "star.fill" : "star")
            .font(.system(size: 10))
            .foregroundStyle(isFavorite ? Theme.textPrimary : Theme.textMeta30)
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}
