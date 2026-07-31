import SwiftUI

struct GeneralTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { appState.settings.launchAtLogin },
                set: { appState.setLaunchAtLogin($0) }
            ))
            .padding(.vertical, 4)

            Toggle("Show in menu bar", isOn: Binding(
                get: { appState.settings.showInMenuBar },
                set: { newValue in
                    AppDelegate.shared?.setShowInMenuBar(newValue)
                }
            ))
            .padding(.vertical, 4)

            Toggle("Show in Dock", isOn: Binding(
                get: { appState.settings.showInDock },
                set: { AppDelegate.shared?.setShowInDock($0) }
            ))
            .padding(.vertical, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
