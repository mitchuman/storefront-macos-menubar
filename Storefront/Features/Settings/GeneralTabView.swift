import SwiftUI

struct GeneralTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
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

                Divider().overlay(Theme.hairline)

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

                Divider().overlay(Theme.hairline)

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
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .settingsTopScrollEdgeBlur()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
