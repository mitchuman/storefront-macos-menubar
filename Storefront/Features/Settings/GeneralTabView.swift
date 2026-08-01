import SwiftUI

struct GeneralTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroupedCard {
                    SettingsGroupedRow("Appearance") {
                        AppearancePillPicker(
                            selection: Binding(
                                get: { appState.settings.appearancePreference },
                                set: { appState.setAppearancePreference($0) }
                            )
                        )
                    }
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

/// Compact three-segment control: Light / Dark / System.
private struct AppearancePillPicker: View {
    @Binding var selection: AppearancePreference

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppearancePreference.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selection == option ? Theme.textPrimary : Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(minWidth: 52)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Theme.settingsCardFill)
                                    .shadow(color: .black.opacity(0.08), radius: 1, y: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.controlFill)
        }
    }
}
