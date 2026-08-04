import SwiftUI

struct StoreRailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var safeTriangle: SafeTriangleController
    @FocusState.Binding var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            searchField
                .padding(.bottom, 7)

            HStack(spacing: 6) {
                // Count only — `visibleStores` would also sort, which nothing here needs.
                Text("\(appState.stores.lazy.filter(\.isVisible).count) Stores")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.textMeta36)
                Spacer(minLength: 4)
                if appState.focusArea == .rail {
                    HStack(spacing: 0) {
                        Image(systemName: "arrow.up")
                        Image(systemName: "arrow.down")
                    }
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Theme.textMeta25)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            Divider().overlay(Theme.hairline)

            ScrollView {
                let stores = appState.filteredStores
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stores.enumerated()), id: \.element.id) { index, store in
                        StoreRowView(
                            store: store,
                            shortcutIndex: index + 1,
                            isSelected: store.id == appState.selectedStoreID,
                            isSuppressed: safeTriangle.suppressedRowID == store.id
                        ) {
                            appState.toggleFavorite(store)
                        }
                        .equatable()
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
        .background {
            if appState.settings.opaqueMenuBarWidget {
                Theme.panelOpaqueElevatedFill
            } else {
                SidebarGlassBackground(cornerRadius: Theme.railCornerRadius)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.railCornerRadius, style: .continuous))
        .overlay {
            if appState.settings.opaqueMenuBarWidget {
                RoundedRectangle(cornerRadius: Theme.railCornerRadius, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            }
        }
        .shadow(
            color: appState.settings.opaqueMenuBarWidget ? Theme.panelElevatedShadow : .clear,
            radius: 4,
            y: 1.5
        )
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMeta30)
                .allowsHitTesting(false)
            // Custom placeholder: AppKit's cell placeholder jumps when the field editor
            // attaches on focus; a SwiftUI label stays put.
            ZStack(alignment: .leading) {
                if appState.query.isEmpty {
                    Text("Search stores")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textMeta30)
                        .allowsHitTesting(false)
                }
            TextField("", text: Binding(
                get: { appState.query },
                set: { appState.query = $0.replacingOccurrences(of: "\n", with: "") }
            ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                    .focused($searchFocused)
                    .focusEffectDisabled()
                    .background(TextFieldAppKitTuning())
                    .onSubmit { }
            }
            KeyComboView(combo: appState.settings.focusSearchHotkey, font: .system(size: 8, weight: .regular))
                .foregroundStyle(Theme.textMeta25)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(Theme.searchFill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    /// Settings link at the bottom of the store rail — Update button sits above when OTA is available.
    private var navigationLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            if appState.updateAvailable {
                Button {
                    AppDelegate.shared?.checkForUpdates(nil)
                } label: {
                    Text("Update Available")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Install available update")
                .padding(.top, 6)
            }

            LegendLinkRow(systemImage: "gearshape", label: "Settings", help: "Settings", shortcutKey: ",") {
                appState.selectedSettingsTab = .general
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            }
            .padding(.top, 4)
        }
    }
}

/// Compact rail footer link — same hover fill language as store rows, but smaller so it
/// stays visually secondary to the sidebar list above.
private struct LegendLinkRow: View {
    let systemImage: String
    let label: String
    let help: String
    var shortcutKey: String? = nil
    let action: () -> Void
    @State private var isHovering = false

    private var contentColor: Color {
        isHovering ? Theme.textBody : Theme.textMeta36
    }

    private var iconColor: Color {
        isHovering ? Theme.textBody : Theme.textMeta30
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 10, alignment: .center)
                Text(label)
                    .font(.system(size: 10.5))
                    .foregroundStyle(contentColor)
                Spacer(minLength: 4)
                if let shortcutKey {
                    HStack(spacing: 1) {
                        Image(systemName: "command")
                            .font(.system(size: 8, weight: .medium))
                        Text(shortcutKey)
                            .font(.mono(9))
                    }
                    .foregroundStyle(isHovering ? Theme.textMeta36 : Theme.textMeta25)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering ? Theme.hoverFill : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovering = $0 }
    }
}

private struct StoreRowView: View, Equatable {
    let store: Store
    let shortcutIndex: Int
    let isSelected: Bool
    let isSuppressed: Bool
    let onToggleFavorite: () -> Void
    @State private var isHovering = false

    static func == (lhs: StoreRowView, rhs: StoreRowView) -> Bool {
        lhs.store == rhs.store
            && lhs.shortcutIndex == rhs.shortcutIndex
            && lhs.isSelected == rhs.isSelected
            && lhs.isSuppressed == rhs.isSuppressed
    }

    /// Hover state used for visual affordances only — false while the safe triangle is
    /// suppressing this row, so it shows no highlight at all mid-transit.
    private var effectiveHovering: Bool { isHovering && !isSuppressed }

    private var showStar: Bool { store.isFavorite || effectiveHovering || isSelected }
    /// Selected rows always show ←→; others keep `⌘N` through 9.
    private var hasBadge: Bool { isSelected || shortcutIndex <= 9 }

    private static let starWidth: CGFloat = 16
    private static let badgeGap: CGFloat = 2
    private static let edgeGap: CGFloat = 0
    private static let badgeWidth: CGFloat = 18
    /// Nudges ←→ into the row's trailing padding without moving the star.
    private static let selectedBadgeNudge: CGFloat = 3

    /// Distance from the row's trailing edge to the star's own right edge — flush
    /// near the edge when there's no badge, or just past the badge when there is.
    /// Always uses the `⌘N` slot metrics so selecting a store never shifts the star.
    private var starTrailingOffset: CGFloat {
        hasBadge ? Self.badgeWidth + Self.badgeGap : Self.edgeGap
    }

    /// Always reserve star room so hover/select opacity alone never reflows the name
    /// (and never re-emits row-frame preferences from a layout shift).
    private var nameTrailingReserve: CGFloat {
        hasBadge ? 4 : Self.starWidth + Self.edgeGap
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                StoreFaviconView(store: store, size: 16)
                Text(store.displayName)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textBody)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.trailing, nameTrailingReserve)
                Spacer(minLength: 4)
                shortcutBadge
                    .offset(x: isSelected ? Self.selectedBadgeNudge : 0)
            }

            StarButton(isFavorite: store.isFavorite, isRowHovering: effectiveHovering, action: onToggleFavorite)
                .padding(.trailing, starTrailingOffset)
                .opacity(showStar ? 1 : 0)
                // Keep the star hittable only while visible — opacity alone still receives taps.
                .allowsHitTesting(showStar)
        }
        .padding(.leading, 15)
        .padding(.trailing, 9)
        .padding(.vertical, 7)
        .background(rowBackground)
        // Accent bar inset from the row edge so it clears the rounded clip and sits
        // just ahead of the favicon with a small gap.
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(store.color)
                .frame(width: 3)
                .padding(.leading, 5)
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

    /// Selected: static ←→. Unselected (1–9): `⌘N`. Collapses past 9 when not selected.
    private var shortcutBadge: some View {
        Group {
            if isSelected {
                HStack(spacing: 0) {
                    Image(systemName: "arrow.left")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 8, weight: .medium))
            } else if shortcutIndex <= 9 {
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
