import Foundation

/// One searchable settings destination — selecting a hit navigates to `tab`.
struct SettingsSearchHit: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let tab: SettingsTab
    let keywords: [String]

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if title.lowercased().contains(q) { return true }
        if subtitle.lowercased().contains(q) { return true }
        return keywords.contains { $0.lowercased().contains(q) }
    }
}

enum SettingsSearchIndex {
    /// Static labels / controls across Settings panes.
    static let staticHits: [SettingsSearchHit] = [
        // Panes themselves
        hit("pane.stores", "Stores", "Stores", .stores, ["shopify", "myshopify", "store list"]),
        hit("pane.sections", "Sections", "Sections", .sections, ["admin sections", "cards", "panel"]),
        hit("pane.shortcuts", "Shortcuts", "Shortcuts", .shortcuts, ["hotkey", "keyboard", "keymap"]),
        hit("pane.general", "General", "General", .general, ["preferences", "options"]),
        hit("pane.about", "About", "About", .about, ["version", "credits", "update"]),

        // Stores
        hit("stores.add", "Add store", "Stores", .stores, ["new store", "create"]),
        hit("stores.import", "Import CSV", "Stores", .stores, ["csv", "import"]),
        hit("stores.export", "Export CSV", "Stores", .stores, ["csv", "export"]),
        hit("stores.deleteAll", "Delete All", "Stores", .stores, ["remove", "clear"]),
        hit("stores.hideAll", "Hide All / Show All", "Stores", .stores, ["visibility", "enable"]),
        hit("stores.displayName", "Display name", "Stores", .stores, ["name", "rename"]),
        hit("stores.accent", "Accent color", "Stores", .stores, ["color", "swatch"]),
        hit("stores.domain", "Store domain", "Stores", .stores, ["myshopify.com", "url"]),

        // Sections
        hit("sections.enableAll", "Enable All / Disable All", "Sections", .sections, ["toggle"]),
        hit("sections.reset", "Reset to Default", "Sections", .sections, ["default order"]),
        hit("sections.reorder", "Reorder sections", "Sections", .sections, ["drag", "order"]),

        // Shortcuts
        hit("shortcuts.global", "Open or close the panel", "Shortcuts", .shortcuts, ["global hotkey", "toggle panel"]),
        hit("shortcuts.quit", "Quit Storefront", "Shortcuts", .shortcuts, ["quit", "exit"]),
        hit("shortcuts.focusSearch", "Focus the store search field", "Shortcuts", .shortcuts, ["search", "find store"]),
        hit("shortcuts.storeList", "Move through the store list", "Shortcuts", .shortcuts, ["arrows", "navigate"]),
        hit("shortcuts.jumpStore", "Jump to a specific store", "Shortcuts", .shortcuts, ["command", "⌘1", "⌘9"]),
        hit("shortcuts.openAdmin", "Open Admin", "Shortcuts", .shortcuts, ["admin", "backend"]),
        hit("shortcuts.openOnlineStore", "Open Online Store", "Shortcuts", .shortcuts, ["storefront", "online store"]),
        hit("shortcuts.sectionGrid", "Move between cards", "Shortcuts", .shortcuts, ["sections", "grid"]),
        hit("shortcuts.openLink", "Open the focused link", "Shortcuts", .shortcuts, ["return", "enter"]),
        hit("shortcuts.keepOpen", "Open a link and keep the panel open", "Shortcuts", .shortcuts, ["command-click", "⌘-click"]),
        hit("shortcuts.linkSearch", "Toggle search on the focused link", "Shortcuts", .shortcuts, ["inline search"]),
        hit("shortcuts.create", "Open the focused link's New +", "Shortcuts", .shortcuts, ["create", "add"]),
        hit("shortcuts.escape", "Step back, then close the panel", "Shortcuts", .shortcuts, ["escape", "esc"]),

        // General
        hit("general.login", "Launch at login", "General", .general, ["startup", "login item"]),
        hit("general.menubar", "Show in menu bar", "General", .general, ["status item", "menu bar"]),
        hit("general.dock", "Show in Dock", "General", .general, ["dock icon", "activation"]),

        // About
        hit("about.version", "Version", "About", .about, ["build", "release"]),
        hit("about.repo", "Repository", "About", .about, ["github", "source"]),
        hit("about.dev", "Developed by", "About", .about, ["nuotsu", "author"]),
        hit("about.updates", "Check for Updates", "About", .about, ["sparkle", "update"]),
    ]

    static func hits(query: String, storeNames: [String], sectionTitles: [String]) -> [SettingsSearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var all = staticHits

        for name in storeNames where !name.isEmpty {
            all.append(
                hit(
                    "store.\(name)",
                    name,
                    "Stores",
                    .stores,
                    ["store", "shop"]
                )
            )
        }
        for title in sectionTitles {
            all.append(
                hit(
                    "section.\(title)",
                    title,
                    "Sections",
                    .sections,
                    ["section", "admin", "card"]
                )
            )
        }

        guard !q.isEmpty else { return [] }
        return all.filter { $0.matches(q) }
    }

    /// Tabs that should remain visible in the sidebar while searching (any hit lands here).
    static func matchingTabs(query: String, storeNames: [String], sectionTitles: [String]) -> [SettingsTab] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return SettingsTab.allCases }
        let tabs = Set(hits(query: q, storeNames: storeNames, sectionTitles: sectionTitles).map(\.tab))
        return SettingsTab.allCases.filter { tabs.contains($0) }
    }

    private static func hit(
        _ id: String,
        _ title: String,
        _ subtitle: String,
        _ tab: SettingsTab,
        _ keywords: [String]
    ) -> SettingsSearchHit {
        SettingsSearchHit(id: id, title: title, subtitle: subtitle, tab: tab, keywords: keywords)
    }
}
