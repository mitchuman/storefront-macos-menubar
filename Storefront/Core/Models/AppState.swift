import SwiftUI
import Combine
import ServiceManagement

/// Which part of the panel keyboard navigation currently targets — the store rail
/// (search + list) or the right-hand section-card grid.
enum PanelFocusArea: Equatable {
    case rail
    case cards
}

/// Identifies a `SettingsRootView` sidebar pane — lets the status-item menu's quick
/// links jump straight to a specific pane instead of always landing on the default.
enum SettingsTab: String, Hashable, CaseIterable, Identifiable {
    case stores
    case sections
    case shortcuts
    case general
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .stores: "Stores"
        case .sections: "Sections"
        case .shortcuts: "Shortcuts"
        case .general: "General"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .stores: "bag"
        case .sections: "square.grid.2x2"
        case .shortcuts: "keyboard"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var stores: [Store]
    @Published var selectedStoreID: Store.ID?
    @Published var query: String = ""
    @Published var settings: AppSettings
    @Published var focusArea: PanelFocusArea = .rail
    @Published var focusedSectionIndex: Int = 0
    @Published var focusedRowIndex: Int = 0
    @Published var selectedSettingsTab: SettingsTab = .general
    /// Row IDs whose inline search field is currently expanded, per store — shared here
    /// (rather than local view state) so a keyboard shortcut can toggle a row's search
    /// regardless of which `CardLinkRow` instance it belongs to, and keyed per store so
    /// switching stores doesn't show/hide an unrelated store's search boxes.
    @Published var expandedSearchRowIDs: [Store.ID: Set<String>] = [:]
    /// Typed-but-not-yet-cleared search text per store/row, so switching stores and back
    /// (which tears down and recreates `CardLinkRow`, discarding any local `@State`)
    /// doesn't lose what the user typed.
    @Published var searchQueries: [Store.ID: [String: String]] = [:]

    private let persistence: PersistenceStore

    init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        let loaded = persistence.loadStores()
        self.stores = loaded
        self.selectedStoreID = loaded.first(where: { $0.isVisible })?.id ?? loaded.first?.id
        self.settings = persistence.loadSettings()
        reconcileLaunchAtLogin()
    }

    /// `SMAppService`'s registration can drift from our stored setting (e.g. the user
    /// removes the login item directly via System Settings) — correct our copy to match
    /// reality on launch rather than trusting a possibly-stale stored value.
    private func reconcileLaunchAtLogin() {
        let actuallyEnabled = SMAppService.mainApp.status == .enabled
        if settings.launchAtLogin != actuallyEnabled {
            settings.launchAtLogin = actuallyEnabled
        }
    }

    /// Registers/unregisters the app as a login item to match the toggle. Reverts to
    /// whatever `SMAppService` actually reports if the call fails, so the UI never
    /// claims a state that isn't real.
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.launchAtLogin = enabled
        } catch {
            settings.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        save()
    }

    /// Favorited stores first (starring moves a store to the top), each group
    /// otherwise in the user's chosen order.
    var visibleStores: [Store] {
        stores.filter(\.isVisible).sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var selectedStore: Store? {
        stores.first { $0.id == selectedStoreID }
    }

    /// `visibleStores`, further narrowed by the rail's search query — the exact list
    /// the rail renders, shared here so keyboard navigation and `⌘1`-`⌘9` index into
    /// the same set of rows the user actually sees.
    var filteredStores: [Store] {
        let stores = visibleStores
        guard !query.isEmpty else { return stores }
        return stores.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    /// All enabled sections, in display order — the exact list `StoreDetailView` renders,
    /// shared here so keyboard navigation can resolve a focused card/row without needing
    /// its own view-layer state.
    var enabledSections: [SectionID] {
        settings.sectionOrder.filter { settings.enabledSections.contains($0) }
    }

    func select(_ store: Store) {
        selectedStoreID = store.id
    }

    // MARK: - Keyboard navigation

    func selectAdjacentStore(offset: Int) {
        let stores = filteredStores
        guard !stores.isEmpty else { return }
        let currentIndex = stores.firstIndex(where: { $0.id == selectedStoreID }) ?? 0
        let count = stores.count
        let newIndex = ((currentIndex + offset) % count + count) % count
        select(stores[newIndex])
    }

    /// `⌘1`-`⌘9` jump straight to the Nth visible store, from either the rail or the
    /// card grid — 1-based to match the digit the user actually presses.
    func selectStore(atShortcutIndex index: Int) {
        let stores = filteredStores
        guard index >= 1, index <= stores.count else { return }
        select(stores[index - 1])
        focusArea = .rail
    }

    func enterCards() {
        guard !enabledSections.isEmpty else { return }
        focusArea = .cards
        focusedSectionIndex = 0
        focusedRowIndex = 0
    }

    func exitToRail() {
        focusArea = .rail
    }

    /// Left/Right — moves between cards in the same flat reading order the grid already
    /// lays out in (a flat index into `enabledSections` reads left-to-right, row-to-row,
    /// so no 2D math is needed). Wraps at either end — Esc is the way back to the rail.
    func moveCardFocus(offset: Int) {
        let sectionCount = enabledSections.count
        guard sectionCount > 0 else { return }
        focusedSectionIndex = ((focusedSectionIndex + offset) % sectionCount + sectionCount) % sectionCount
        focusedRowIndex = 0
    }

    /// Up/Down while focused on a card — wraps within that card's own rows, does not
    /// spill into the next/previous card.
    func moveRowFocus(offset: Int) {
        guard focusedSectionIndex < enabledSections.count else { return }
        let rowCount = StaticLinkCatalog.rows(for: enabledSections[focusedSectionIndex]).count
        guard rowCount > 0 else { return }
        focusedRowIndex = ((focusedRowIndex + offset) % rowCount + rowCount) % rowCount
    }

    /// The `LinkRow` the keyboard is currently focused on within the card grid, shared by
    /// `openFocusedLink()`/`openFocusedCreateLink()`/`toggleSearchForFocusedLink()` so they
    /// don't each repeat the same section/row lookup.
    private var focusedRow: LinkRow? {
        guard focusArea == .cards, focusedSectionIndex < enabledSections.count else { return nil }
        let rows = StaticLinkCatalog.rows(for: enabledSections[focusedSectionIndex])
        guard focusedRowIndex < rows.count else { return nil }
        return rows[focusedRowIndex]
    }

    /// Return — opens the currently keyboard-focused link, same as clicking it.
    func openFocusedLink() {
        guard let store = selectedStore, let row = focusedRow,
              let url = row.url(for: store.myshopifyDomain) else { return }
        openStoreLink(url, keepOpen: false)
    }

    /// Opens the focused row's "New +" create link, if it has one.
    func openFocusedCreateLink() {
        guard let store = selectedStore, let row = focusedRow,
              let url = row.createURL(for: store.myshopifyDomain) else { return }
        openStoreLink(url, keepOpen: false)
    }

    /// Opens the selected store's admin (panel shortcut; closes the panel).
    func openSelectedAdmin() {
        guard let url = selectedStore?.adminURL else { return }
        openStoreLink(url, keepOpen: false)
    }

    /// Opens the selected store's online storefront (panel shortcut; closes the panel).
    func openSelectedOnlineStore() {
        guard let url = selectedStore?.shopURL else { return }
        openStoreLink(url, keepOpen: false)
    }

    /// Toggles the focused row's inline search field, if it supports search. Returns
    /// the row's id and its new expanded state so the caller (which owns the `@FocusState`
    /// needed to actually focus the field) can react — `nil` if the focused row can't search.
    @discardableResult
    func toggleSearchForFocusedLink() -> (rowID: String, isNowExpanded: Bool)? {
        guard let store = selectedStore, let row = focusedRow, row.supportsSearch else { return nil }
        if expandedSearchRowIDs[store.id, default: []].contains(row.id) {
            expandedSearchRowIDs[store.id]?.remove(row.id)
            return (row.id, false)
        } else {
            expandedSearchRowIDs[store.id, default: []].insert(row.id)
            return (row.id, true)
        }
    }

    func save() {
        persistence.save(stores: stores)
        persistence.save(settings: settings)
    }

    func addStore(domain: String, displayName: String, colorHex: String) {
        let accountID = stores.first?.accountID ?? UUID()
        let nextOrder = (stores.map(\.sortOrder).max() ?? -1) + 1
        let store = Store(accountID: accountID, myshopifyDomain: domain, displayName: displayName, colorHex: colorHex, sortOrder: nextOrder)
        stores.append(store)
        if selectedStoreID == nil { selectedStoreID = store.id }
        save()
    }

    // MARK: - CSV import/export

    /// "Display Name,Domain,Color" — one row per store, in panel order.
    func storesCSV() -> String {
        var lines = ["Display Name,Domain,Color"]
        for store in stores.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            lines.append("\(CSV.escape(store.displayName)),\(CSV.escape(store.myshopifyDomain)),\(store.colorHex)")
        }
        return lines.joined(separator: "\n")
    }

    /// Adds a store per data row (skipping the header row and any duplicate domains).
    /// Returns the number of stores actually added.
    @discardableResult
    func importStoresCSV(_ contents: String) -> Int {
        let palette = ["1f6f4a", "c07a2c", "3a6ea8", "7a4b8c", "4a7a5c", "a8563a", "5c9fd6", "a37bb8"]
        var added = 0
        let rows = CSV.parse(contents)
        for row in rows.dropFirst() where row.count >= 2 {
            let displayName = row[0].trimmingCharacters(in: .whitespaces)
            var domain = row[1].trimmingCharacters(in: .whitespaces)
            guard !displayName.isEmpty, !domain.isEmpty else { continue }
            if !domain.hasSuffix(".myshopify.com") {
                domain = domain.replacingOccurrences(of: ".myshopify.com", with: "") + ".myshopify.com"
            }
            guard !stores.contains(where: { $0.myshopifyDomain == domain }) else { continue }
            let colorHex = row.count >= 3 && !row[2].isEmpty ? row[2] : palette[stores.count % palette.count]
            addStore(domain: domain, displayName: displayName, colorHex: colorHex)
            added += 1
        }
        return added
    }

    func toggleFavorite(_ store: Store) {
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        stores[index].isFavorite.toggle()
        save()
    }

    func removeStore(_ store: Store) {
        stores.removeAll { $0.id == store.id }
        save()
    }

    func moveStore(fromOffsets: IndexSet, toOffset: Int) {
        var ordered = stores.sorted { $0.sortOrder < $1.sortOrder }
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, var store) in ordered.enumerated() {
            store.sortOrder = index
            if let idx = stores.firstIndex(where: { $0.id == store.id }) {
                stores[idx] = store
            }
        }
        save()
    }

}
