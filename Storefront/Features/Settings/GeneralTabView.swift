import SwiftUI

struct GeneralTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { appState.settings.launchAtLogin },
                set: { appState.settings.launchAtLogin = $0; appState.save() }
            ))
            Toggle("Compact mode", isOn: Binding(
                get: { appState.settings.compactMode },
                set: { appState.settings.compactMode = $0; appState.save() }
            ))
            LabeledContent("Global hotkey") {
                HotKeyRecorderView(combo: Binding(
                    get: { appState.settings.globalHotkey },
                    set: { newCombo in
                        appState.settings.globalHotkey = newCombo
                        appState.save()
                        GlobalHotKeyManager.shared.updateCombo(newCombo)
                    }
                ))
            }
            Picker("Menubar icon", selection: Binding(
                get: { appState.settings.menubarIconStyle },
                set: { appState.settings.menubarIconStyle = $0; appState.save() }
            )) {
                Text("Monochrome").tag(MenubarIconStyle.monochrome)
                Text("Store color").tag(MenubarIconStyle.colorTag)
            }

            Text("ABOUT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.textMeta40)
                .padding(.top, 14)

            LabeledContent("Developed by") {
                Link("nuotsu", destination: URL(string: "https://nuotsu.dev")!)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
