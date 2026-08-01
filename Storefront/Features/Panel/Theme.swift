import SwiftUI
import AppKit

enum Theme {
    static let accent = Color.adaptive(light: Color(hex: "1f6f4a"), dark: Color(hex: "4fbf8b"))
    static let accentOnFill = Color.adaptive(light: .white, dark: Color(hex: "10261c"))
    static let accentTintRow = Color.adaptive(light: Color(hex: "1f6f4a").opacity(0.09), dark: Color(hex: "4fbf8b").opacity(0.09))
    static let accentTintBadge = Color.adaptive(light: Color(hex: "1f6f4a").opacity(0.12), dark: Color(hex: "4fbf8b").opacity(0.12))
    static let errorDot = Color(hex: "c0562c")
    /// Hotkey recorder “listening” label.
    static let recordingText = Color.adaptive(light: Color(hex: "d4785a"), dark: Color(hex: "e8a090"))

    /// Legacy flat rail wash — prefer `SidebarGlassBackground` for the floating rail.
    static let railBackground = Color.adaptive(light: .black.opacity(0.025), dark: .white.opacity(0.03))
    static let footerBackground = Color.adaptive(light: .black.opacity(0.02), dark: .white.opacity(0.02))
    static let hoverFill = Color.adaptive(light: .black.opacity(0.045), dark: .white.opacity(0.07))
    static let controlFill = Color.adaptive(light: .black.opacity(0.07), dark: .white.opacity(0.1))
    static let searchFill = Color.adaptive(light: .black.opacity(0.055), dark: .white.opacity(0.08))
    static let hairline = Color.adaptive(light: .black.opacity(0.07), dark: .white.opacity(0.08))
    static let divider = Color.adaptive(light: .black.opacity(0.08), dark: .white.opacity(0.08))
    static let borderColor = Color.adaptive(light: .black.opacity(0.12), dark: .white.opacity(0.1))

    /// Legacy flat card wash / border — prefer `SidebarGlassBackground` for panel section cards.
    static let cardFill = Color.adaptive(light: .white.opacity(0.28), dark: .white.opacity(0.035))
    static let cardBorder = Color.adaptive(light: .black.opacity(0.08), dark: .white.opacity(0.07))

    /// Opaque card/list background for the Settings window (not the vibrancy-backed
    /// panel — legacy `cardFill` above is too transparent against Settings' opaque window
    /// background). `.controlBackgroundColor` is the system-adaptive content-area color
    /// AppKit windows use, so it automatically flips with light/dark appearance.
    static let settingsCardFill = Color(nsColor: .controlBackgroundColor)

    /// Opaque menu bar widget body fill (Liquid Glass off).
    static let panelOpaqueFill = Color(nsColor: .windowBackgroundColor)
    /// Opaque elevated surfaces for the floating rail and section cards (Liquid Glass off).
    static let panelOpaqueElevatedFill = Color(nsColor: .controlBackgroundColor)
    /// Soft drop shadow for opaque elevated rail/cards.
    static let panelElevatedShadow = Color.adaptive(light: .black.opacity(0.08), dark: .black.opacity(0.28))

    static let textPrimary = Color.adaptive(light: Color(hex: "111111"), dark: Color(hex: "f2f2f4"))
    static let textBody = Color.adaptive(light: .black.opacity(0.82), dark: .white.opacity(0.82))
    static let textSecondary = Color.adaptive(light: .black.opacity(0.5), dark: .white.opacity(0.5))
    static let textMeta40 = Color.adaptive(light: .black.opacity(0.4), dark: .white.opacity(0.4))
    static let textMeta36 = Color.adaptive(light: .black.opacity(0.36), dark: .white.opacity(0.36))
    static let textMeta30 = Color.adaptive(light: .black.opacity(0.3), dark: .white.opacity(0.35))
    static let textMeta25 = Color.adaptive(light: .black.opacity(0.25), dark: .white.opacity(0.3))

    static let panelShadowColor = Color.adaptive(light: .black.opacity(0.2), dark: .black.opacity(0.42))

    static let panelSize = CGSize(width: 560, height: 520)
    static let railWidth: CGFloat = 186
    /// Inset around the floating glass rail (leading / top / bottom).
    static let railInset: CGFloat = 8
    /// Gap between the floating rail and the detail column.
    static let railGap: CGFloat = 8
    static let railCornerRadius: CGFloat = 12

    static var monoFont: Font.Design { .monospaced }
}

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    /// A color that automatically resolves to `light` or `dark` based on the current
    /// system/window appearance, without needing `@Environment(\.colorScheme)` threaded
    /// through every view.
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        }))
    }
}
