import Foundation

struct LinkTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    /// Path template relative to the store, e.g. "/apps/my-app". Supports "{shop}" substitution.
    var pathTemplate: String
}

enum MenubarIconStyle: String, Codable, CaseIterable {
    case monochrome
    case colorTag
}

struct AppSettings: Codable, Equatable {
    /// All sections, in display/order — separate from which are enabled, so toggling
    /// one off doesn't reshuffle the list.
    var sectionOrder: [SectionID] = SectionID.defaultOrder
    var enabledSections: Set<SectionID> = Set(SectionID.allCases)
    var compactMode: Bool = false
    var launchAtLogin: Bool = false
    var globalHotkey: KeyCombo = .default
    var menubarIconStyle: MenubarIconStyle = .monochrome
    var customLinks: [LinkTemplate] = []
}
