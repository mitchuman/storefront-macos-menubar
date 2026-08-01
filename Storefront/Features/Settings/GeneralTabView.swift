import SwiftUI

struct GeneralTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroupedCard {
                    SettingsGroupedRow("Appearance", alignment: .top) {
                        AppearanceThumbnailPicker(
                            selection: Binding(
                                get: { appState.settings.appearancePreference },
                                set: { appState.setAppearancePreference($0) }
                            )
                        )
                    }
                    .padding(.vertical, 6)

                    SettingsGroupedDivider()

                    SettingsGroupedRow(
                        "Widget background",
                        subtitle: "Choose your preferred look for the menu bar widget.",
                        alignment: .top
                    ) {
                        PanelBackgroundThumbnailPicker(
                            opaque: Binding(
                                get: { appState.settings.opaqueMenuBarWidget },
                                set: { appState.setOpaqueMenuBarWidget($0) }
                            )
                        )
                    }
                    .padding(.vertical, 6)
                }

                SettingsGroupedCard {
                    SettingsGroupedRow("Launch at login") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { appState.settings.launchAtLogin },
                                set: { appState.setLaunchAtLogin($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    SettingsGroupedDivider()

                    SettingsGroupedRow("Show in menu bar") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { appState.settings.showInMenuBar },
                                set: { AppDelegate.shared?.setShowInMenuBar($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    SettingsGroupedDivider()

                    SettingsGroupedRow("Show in Dock") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { appState.settings.showInDock },
                                set: { AppDelegate.shared?.setShowInDock($0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .settingsTopScrollEdgeBlur()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// System Settings–style Auto / Light / Dark thumbnails with a blue selection ring.
private struct AppearanceThumbnailPicker: View {
    @Binding var selection: AppearancePreference

    private let previewSize = CGSize(width: 64, height: 44)
    private let cornerRadius: CGFloat = 7

    var body: some View {
        HStack(spacing: 14) {
            ForEach(AppearancePreference.displayOrder) { option in
                Button {
                    selection = option
                } label: {
                    VStack(spacing: 6) {
                        AppearanceDesktopPreview(style: option)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 1.5, y: 0.5)
                            .padding(2.5)
                            .overlay {
                                if selection == option {
                                    RoundedRectangle(cornerRadius: cornerRadius + 2.5, style: .continuous)
                                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                }
                            }

                        Text(option.title)
                            .font(.system(size: 11, weight: selection == option ? .semibold : .regular))
                            .foregroundStyle(selection == option ? Theme.textPrimary : Theme.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Liquid Glass vs Opaque thumbnails for the menu bar widget chrome.
private struct PanelBackgroundThumbnailPicker: View {
    @Binding var opaque: Bool

    private let previewSize = CGSize(width: 64, height: 44)
    private let cornerRadius: CGFloat = 7

    private var options: [(opaque: Bool, title: String)] {
        [(false, "Liquid Glass"), (true, "Opaque")]
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options, id: \.title) { option in
                Button {
                    opaque = option.opaque
                } label: {
                    VStack(spacing: 6) {
                        PanelBackgroundPreview(opaque: option.opaque)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 1.5, y: 0.5)
                            .padding(2.5)
                            .overlay {
                                if opaque == option.opaque {
                                    RoundedRectangle(cornerRadius: cornerRadius + 2.5, style: .continuous)
                                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                }
                            }

                        Text(option.title)
                            .font(.system(size: 11, weight: opaque == option.opaque ? .semibold : .regular))
                            .foregroundStyle(opaque == option.opaque ? Theme.textPrimary : Theme.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Mini panel mock: wallpaper + floating rail/cards — glass wash vs solid elevated chrome.
private struct PanelBackgroundPreview: View {
    let opaque: Bool

    var body: some View {
        ZStack {
            // Desktop wallpaper hint (matches Appearance previews’ colorful backdrop)
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.68, blue: 0.92),
                    Color(red: 0.82, green: 0.72, blue: 0.55),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Panel body — solid for Opaque, frosted wash for Liquid Glass (popover chrome).
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    opaque
                        ? Color(nsColor: .windowBackgroundColor)
                        : Color.white.opacity(0.55)
                )
                .padding(5)

            HStack(alignment: .top, spacing: 3) {
                // Floating sidebar rail
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(opaque ? Color(nsColor: .controlBackgroundColor) : Color.white.opacity(0.42))
                    .overlay {
                        if opaque {
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
                        }
                    }
                    .shadow(color: opaque ? .black.opacity(0.12) : .clear, radius: 1, y: 0.5)
                    .frame(width: 16)
                    .overlay(alignment: .top) {
                        VStack(spacing: 2) {
                            Capsule()
                                .fill(Color.black.opacity(opaque ? 0.12 : 0.18))
                                .frame(width: 10, height: 2.5)
                            Capsule()
                                .fill(Color.black.opacity(opaque ? 0.08 : 0.12))
                                .frame(width: 10, height: 2.5)
                        }
                        .padding(.top, 4)
                    }

                // Section cards column
                VStack(spacing: 3) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(opaque ? Color(nsColor: .controlBackgroundColor) : Color.white.opacity(0.38))
                            .overlay {
                                if opaque {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
                                }
                            }
                            .shadow(color: opaque ? .black.opacity(0.1) : .clear, radius: 0.8, y: 0.4)
                            .frame(height: 12)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(8)
        }
    }
}

private enum AppearancePreviewStyle {
    case light
    case dark
}

private struct AppearanceDesktopPreview: View {
    let style: AppearancePreference

    var body: some View {
        switch style {
        case .light:
            desktop(style: .light)
        case .dark:
            desktop(style: .dark)
        case .system:
            HStack(spacing: 0) {
                desktop(style: .light)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                desktop(style: .dark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
    }

    private func desktop(style: AppearancePreviewStyle) -> some View {
        let isDark = style == .dark
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: isDark
                    ? [Color(red: 0.12, green: 0.14, blue: 0.32), Color(red: 0.22, green: 0.12, blue: 0.38)]
                    : [Color(red: 0.55, green: 0.72, blue: 0.92), Color(red: 0.78, green: 0.88, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Menu bar strip
            Rectangle()
                .fill(isDark ? Color.black.opacity(0.45) : Color.white.opacity(0.55))
                .frame(height: 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Apple logo mark
            Image(systemName: "apple.logo")
                .font(.system(size: 5, weight: .medium))
                .foregroundStyle(.white.opacity(isDark ? 0.9 : 0.85))
                .padding(.leading, 4)
                .padding(.top, 1)

            // Window chrome (bottom-leading corner)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 2.5) {
                    Circle().fill(Color(red: 1, green: 0.38, blue: 0.35)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color(red: 1, green: 0.76, blue: 0.25)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color(red: 0.35, green: 0.8, blue: 0.4)).frame(width: 3.5, height: 3.5)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 5)
                .padding(.top, 4)
                .padding(.bottom, 10)
                .frame(width: 42, height: 22, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isDark ? Color(white: 0.18) : Color.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                )
                .padding(.leading, 6)
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
