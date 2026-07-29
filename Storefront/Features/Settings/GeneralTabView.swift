import SwiftUI

struct GeneralTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var hotkeyErrorMessage: String?

    var body: some View {
            Form {
            Toggle("Launch at login", isOn: Binding(
                get: { appState.settings.launchAtLogin },
                set: { appState.setLaunchAtLogin($0) }
            ))
            .padding(.vertical, 4)

            LabeledContent("Global hotkey") {
                HotKeyRecorderView(combo: Binding(
                    get: { appState.settings.globalHotkey },
                    set: { newCombo in
                        if GlobalHotKeyManager.shared.updateCombo(newCombo) {
                            appState.settings.globalHotkey = newCombo
                            appState.save()
                            hotkeyErrorMessage = nil
                        } else {
                            hotkeyErrorMessage = "Couldn't register that shortcut — try a different combo."
                            // Registering the new combo failed after unregistering the
                            // old one — restore the last-known-good combo so the app
                            // doesn't end up with no working hotkey at all.
                            GlobalHotKeyManager.shared.updateCombo(appState.settings.globalHotkey)
                        }
                    }
                ))
            }
            .padding(.vertical, 4)

            if let hotkeyErrorMessage {
                Text(hotkeyErrorMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.errorDot)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
