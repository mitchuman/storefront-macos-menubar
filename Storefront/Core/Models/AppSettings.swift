import AppKit
import Foundation
import SwiftUI

struct LinkTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    /// Path template relative to the store, e.g. "/apps/my-app". Supports "{shop}" substitution.
    var pathTemplate: String
}

/// User-saved section layout (order + enabled set) for Settings → Sections presets.
struct SavedSectionPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var sectionOrder: [SectionID]
    var enabledSections: Set<SectionID>
}

/// Dock / About icon choice — mirrors cmux `AppIconMode`.
///
/// Auto (and Light/Dark when they already match system) clear
/// `applicationIconImage` so the Dock uses Icon Composer `AppIcon` with the
/// same Liquid Glass chrome/size. Forced Light-on-dark / Dark-on-light uses an
/// inset imageset so the tile scale matches that chrome.
enum AppIconPreference: String, Codable, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Settings order: Auto → Light → Dark.
    static let displayOrder: [AppIconPreference] = [.system, .light, .dark]

    /// Thumbnail asset. Auto uses Light for a single-tile fallback.
    var imageName: String {
        switch self {
        case .system, .light: "AppIconLight"
        case .dark: "AppIconDark"
        }
    }

    /// Updates the running app's Dock / About icon.
    @MainActor
    static func apply(_ preference: AppIconPreference) {
        let systemDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        switch preference {
        case .system:
            NSApp.applicationIconImage = nil
        case .light:
            // Same chrome/size as Auto whenever system is already Light.
            NSApp.applicationIconImage = systemDark ? dockOverrideImage(named: "AppIconLight") : nil
        case .dark:
            // Same chrome/size as Auto whenever system is already Dark.
            NSApp.applicationIconImage = systemDark ? nil : dockOverrideImage(named: "AppIconDark")
        }
    }

    /// Pads a flattened imageset so `applicationIconImage` matches the Dock’s
    /// system App Icon content scale (full-bleed overrides read ~15–20% larger).
    @MainActor
    private static func dockOverrideImage(named name: String) -> NSImage? {
        guard let source = NSImage(named: name) else { return nil }
        let canvas: CGFloat = 1024
        // Empirically matches Icon Composer + Dock Liquid Glass tile scale.
        let content: CGFloat = canvas * 0.80
        let image = NSImage(size: NSSize(width: canvas, height: canvas))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(
            x: (canvas - content) / 2,
            y: (canvas - content) / 2,
            width: content,
            height: content
        )
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [
            .interpolation: NSImageInterpolation.high
        ])
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

/// Menu bar status-item glyph — SF Symbol bag, or Polaris Cart / Store × outline / filled.
enum MenuBarIconPreference: String, Codable, CaseIterable, Identifiable, Hashable {
    case bag
    case bagFilled
    case cart
    case cartFilled
    case store
    case storeFilled

    var id: Self { self }

    enum Family: String, CaseIterable, Identifiable {
        case bag
        case cart
        case store

        var id: Self { self }

        var title: String {
            switch self {
            case .bag: "Bag"
            case .cart: "Cart"
            case .store: "Store"
            }
        }

        /// Settings chip order: Bag → Store → Cart.
        static let displayOrder: [Family] = [.bag, .store, .cart]
    }

    var family: Family {
        switch self {
        case .bag, .bagFilled: .bag
        case .cart, .cartFilled: .cart
        case .store, .storeFilled: .store
        }
    }

    var isFilled: Bool {
        switch self {
        case .bagFilled, .cartFilled, .storeFilled: true
        case .bag, .cart, .store: false
        }
    }

    var title: String { family.title }

    /// SF Symbol for bag options (nil for Polaris asset glyphs).
    var systemSymbolName: String? {
        switch self {
        case .bag: "bag"
        case .bagFilled: "bag.fill"
        case .cart, .cartFilled, .store, .storeFilled: nil
        }
    }

    /// Asset catalog imageset name for Polaris glyphs (nil for SF Symbol bag).
    var assetName: String? {
        switch self {
        case .bag, .bagFilled: nil
        case .cart: "CartIcon"
        case .cartFilled: "CartFilledIcon"
        case .store: "StoreIcon"
        case .storeFilled: "StoreFilledIcon"
        }
    }

    static func preference(family: Family, filled: Bool) -> MenuBarIconPreference {
        switch (family, filled) {
        case (.bag, false): .bag
        case (.bag, true): .bagFilled
        case (.cart, false): .cart
        case (.cart, true): .cartFilled
        case (.store, false): .store
        case (.store, true): .storeFilled
        }
    }
}

/// App-wide light/dark preference for the menu bar panel and Settings window.
enum AppearancePreference: String, Codable, CaseIterable, Identifiable, Hashable {
    case light
    case dark
    case system

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "Auto"
        }
    }

    /// System Settings order: Auto → Light → Dark.
    static let displayOrder: [AppearancePreference] = [.system, .light, .dark]

    /// Always a concrete aqua / darkAqua. `.system` resolves against the real macOS
    /// appearance (`NSApp.appearance` must be `nil` first) — assigning `nil` to a
    /// window after `.darkAqua` can leave Liquid Glass / dynamic colors stuck dark.
    var nsAppearance: NSAppearance {
        switch self {
        case .light:
            return NSAppearance(named: .aqua) ?? NSAppearance()
        case .dark:
            return NSAppearance(named: .darkAqua) ?? NSAppearance()
        case .system:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
            return NSAppearance(named: match) ?? NSAppearance()
        }
    }

    /// Concrete scheme so SwiftUI sees Light↔System as a real change (not `.dark`→`nil`).
    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system:
            NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? .dark : .light
        }
    }

    /// Applies appearance to the menu bar panel and Settings window only.
    /// Never sets `NSApp.appearance` — that forces the status-item template icon to
    /// tint against the app theme instead of the menu bar (e.g. black on a dark bar).
    @MainActor
    static func apply(_ preference: AppearancePreference) {
        NSApp.appearance = nil
        AppDelegate.shared?.applyAppearancePreference(preference)
    }
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
    /// Light / Dark / System — drives panel + Settings appearance.
    var appearancePreference: AppearancePreference = .system
    /// Auto / Light / Dark Dock icon (cmux-style). Auto uses Icon Composer chrome.
    var appIconPreference: AppIconPreference = .system
    /// Glyph shown in the menu bar status item (Polaris bag / cart / store).
    var menuBarIconPreference: MenuBarIconPreference = .bag
    /// When true, the menu bar widget uses opaque chrome instead of Liquid Glass vibrancy.
    var opaqueMenuBarWidget: Bool = false
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
    /// Named user layouts available in the Sections presets picker (built-ins are not stored here).
    var savedSectionPresets: [SavedSectionPreset] = []
    /// When true, the Presets picker shows Custom even if the current layout still
    /// exact-matches a named/saved preset (selecting Custom is otherwise a no-op).
    var prefersCustomSectionPreset: Bool = false
    /// Sticky saved-preset selection when that preset’s layout also matches a built-in
    /// (layout matching alone would otherwise resolve to the built-in and hide Rename/Delete).
    var preferredSavedSectionPresetID: UUID? = nil

    init(
        sectionOrder: [SectionID] = SectionID.defaultOrder,
        enabledSections: Set<SectionID> = Set(SectionID.allCases),
        launchAtLogin: Bool = false,
        showInMenuBar: Bool = true,
        showInDock: Bool = false,
        appearancePreference: AppearancePreference = .system,
        appIconPreference: AppIconPreference = .system,
        menuBarIconPreference: MenuBarIconPreference = .bag,
        opaqueMenuBarWidget: Bool = false,
        globalHotkey: KeyCombo = .default,
        openAdminHotkey: KeyCombo = .openAdminDefault,
        openOnlineStoreHotkey: KeyCombo = .openOnlineStoreDefault,
        focusSearchHotkey: KeyCombo = .focusSearchDefault,
        toggleLinkSearchHotkey: KeyCombo = .toggleLinkSearchDefault,
        openCreateLinkHotkey: KeyCombo = .openCreateLinkDefault,
        customLinks: [LinkTemplate] = [],
        savedSectionPresets: [SavedSectionPreset] = [],
        prefersCustomSectionPreset: Bool = false,
        preferredSavedSectionPresetID: UUID? = nil
    ) {
        self.sectionOrder = sectionOrder
        self.enabledSections = enabledSections
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.showInDock = showInDock
        self.appearancePreference = appearancePreference
        self.appIconPreference = appIconPreference
        self.menuBarIconPreference = menuBarIconPreference
        self.opaqueMenuBarWidget = opaqueMenuBarWidget
        self.globalHotkey = globalHotkey
        self.openAdminHotkey = openAdminHotkey
        self.openOnlineStoreHotkey = openOnlineStoreHotkey
        self.focusSearchHotkey = focusSearchHotkey
        self.toggleLinkSearchHotkey = toggleLinkSearchHotkey
        self.openCreateLinkHotkey = openCreateLinkHotkey
        self.customLinks = customLinks
        self.savedSectionPresets = savedSectionPresets
        self.prefersCustomSectionPreset = prefersCustomSectionPreset
        self.preferredSavedSectionPresetID = preferredSavedSectionPresetID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sectionOrder = try c.decodeIfPresent([SectionID].self, forKey: .sectionOrder) ?? SectionID.defaultOrder
        enabledSections = try c.decodeIfPresent(Set<SectionID>.self, forKey: .enabledSections) ?? Set(SectionID.allCases)
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        showInDock = try c.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false
        appearancePreference = try c.decodeIfPresent(AppearancePreference.self, forKey: .appearancePreference) ?? .system
        appIconPreference = try c.decodeIfPresent(AppIconPreference.self, forKey: .appIconPreference) ?? .system
        menuBarIconPreference = try c.decodeIfPresent(MenuBarIconPreference.self, forKey: .menuBarIconPreference) ?? .bag
        opaqueMenuBarWidget = try c.decodeIfPresent(Bool.self, forKey: .opaqueMenuBarWidget) ?? false
        globalHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .globalHotkey) ?? .default
        openAdminHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .openAdminHotkey) ?? .openAdminDefault
        openOnlineStoreHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .openOnlineStoreHotkey) ?? .openOnlineStoreDefault
        focusSearchHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .focusSearchHotkey) ?? .focusSearchDefault
        toggleLinkSearchHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .toggleLinkSearchHotkey) ?? .toggleLinkSearchDefault
        openCreateLinkHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .openCreateLinkHotkey) ?? .openCreateLinkDefault
        customLinks = try c.decodeIfPresent([LinkTemplate].self, forKey: .customLinks) ?? []
        savedSectionPresets = try c.decodeIfPresent([SavedSectionPreset].self, forKey: .savedSectionPresets) ?? []
        prefersCustomSectionPreset = try c.decodeIfPresent(Bool.self, forKey: .prefersCustomSectionPreset) ?? false
        preferredSavedSectionPresetID = try c.decodeIfPresent(UUID.self, forKey: .preferredSavedSectionPresetID)
    }
}
