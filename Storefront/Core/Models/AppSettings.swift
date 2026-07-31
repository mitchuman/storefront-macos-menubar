import Foundation

struct LinkTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    /// Path template relative to the store, e.g. "/apps/my-app". Supports "{shop}" substitution.
    var pathTemplate: String
}

struct AppSettings: Codable, Equatable {
    /// All sections, in display/order — separate from which are enabled, so toggling
    /// one off doesn't reshuffle the list.
    var sectionOrder: [SectionID] = SectionID.defaultOrder
    var enabledSections: Set<SectionID> = Set(SectionID.allCases)
    var launchAtLogin: Bool = false
    /// When false, the bag status item is removed from the menu bar. Toggle off/on to recreate a missing icon.
    var showInMenuBar: Bool = true
    /// When true, the app uses a regular activation policy and appears in the Dock.
    var showInDock: Bool = false
    var globalHotkey: KeyCombo = .default
    /// Panel-local: open the selected store's Shopify admin.
    var openAdminHotkey: KeyCombo = .openAdminDefault
    /// Panel-local: open the selected store's online storefront.
    var openOnlineStoreHotkey: KeyCombo = .openOnlineStoreDefault
    /// Panel-local: focus the store search field.
    var focusSearchHotkey: KeyCombo = .focusSearchDefault
    /// Panel-local: toggle inline search on the focused link.
    var toggleLinkSearchHotkey: KeyCombo = .toggleLinkSearchDefault
    /// Panel-local: open the focused link's "New +" create URL.
    var openCreateLinkHotkey: KeyCombo = .openCreateLinkDefault
    var customLinks: [LinkTemplate] = []
}
