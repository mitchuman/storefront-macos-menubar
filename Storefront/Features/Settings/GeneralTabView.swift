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
