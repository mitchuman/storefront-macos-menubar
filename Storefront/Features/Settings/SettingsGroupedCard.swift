import SwiftUI

/// Shared metrics for Settings list/card rows (aligned with Keybindings).
enum SettingsRowMetrics {
    static let horizontalPadding: CGFloat = 11
    static let reorderWidth: CGFloat = 22
    static let rowSpacing: CGFloat = 6
    /// Subtle left cutoff for inter-row hairlines (Keybindings / non-reorder rows).
    static let separatorLeading: CGFloat = 11
    /// Hairline starts after the reorder grip + gap (not underneath the handle).
    static var afterReorderSeparatorLeading: CGFloat {
        horizontalPadding + reorderWidth + rowSpacing
    }
}

/// Hairline between grouped rows — inset on the leading edge like Keybindings.
struct SettingsGroupedDivider: View {
    var leadingInset: CGFloat = SettingsRowMetrics.separatorLeading

    var body: some View {
        Divider()
            .overlay(Theme.hairline)
            .padding(.leading, leadingInset)
    }
}

/// Full-width bordered group for settings rows (cmux-style card chrome).
struct SettingsGroupedCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(Theme.settingsCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.borderColor, lineWidth: 1)
        )
    }
}

/// One full-width row: title (+ optional subtitle) on the left, control on the right.
struct SettingsGroupedRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    var alignment: VerticalAlignment
    @ViewBuilder let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        alignment: VerticalAlignment = .center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.alignment = alignment
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 12) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, SettingsRowMetrics.horizontalPadding)
        .padding(.vertical, 9)
    }
}

/// Plain text action link for Settings footers — no pill chrome.
struct SettingsTextLink: View {
    let title: String
    var isEnabled: Bool = true
    var isDestructive: Bool = false
    let action: () -> Void

    init(
        _ title: String,
        isEnabled: Bool = true,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.action = action
    }

    private var textColor: Color {
        guard isEnabled else { return Theme.textMeta40 }
        return isDestructive ? .red : Color.accentColor
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(textColor)
            .disabled(!isEnabled)
    }
}

extension View {
    /// Soft progressive blur at the top scroll edge (Tahoe+). No-op below macOS 26.
    /// Same helper Settings → Keybindings uses under the window titleband.
    @ViewBuilder
    func topScrollEdgeBlur() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    /// Soft progressive blur under the Settings titleband (Tahoe+). No-op below macOS 26.
    @ViewBuilder
    func settingsTopScrollEdgeBlur() -> some View {
        topScrollEdgeBlur()
    }

    /// Prevents a nested `List`/`ScrollView` from owning the window titleband scroll-edge
    /// (Tahoe+). Needed when chrome sits above the scroller — otherwise the split view
    /// collapses under the titlebar and the whole Settings window jumps up.
    @ViewBuilder
    func settingsDisableScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectHidden(true, for: .all)
        } else {
            self
        }
    }

    /// Pins a top bar that participates in the system scroll-edge progressive blur
    /// (`safeAreaBar` on macOS 26+). Falls back to `safeAreaInset` below Tahoe.
    @ViewBuilder
    func detailHeaderSafeAreaBar<Bar: View>(@ViewBuilder bar: () -> Bar) -> some View {
        if #available(macOS 26.0, *) {
            self.safeAreaBar(edge: .top, spacing: 0) {
                bar()
            }
        } else {
            self.safeAreaInset(edge: .top, spacing: 0) {
                bar()
            }
        }
    }
}
