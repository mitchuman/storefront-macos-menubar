import SwiftUI

struct GeneralTabView: View {
    // A compile-time-constant literal — the force unwrap can't practically fail, but
    // hoisting it here keeps it a single obvious spot to double-check if this ever changes.
    private static let nuotsuURL = URL(string: "https://nuotsu.dev")!

    @EnvironmentObject var appState: AppState
    @State private var hotkeyErrorMessage: String?

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { appState.settings.launchAtLogin },
                set: { appState.setLaunchAtLogin($0) }
            ))
            LabeledContent("Global hotkey") {
                VStack(alignment: .trailing, spacing: 4) {
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
                    if let hotkeyErrorMessage {
                        Text(hotkeyErrorMessage)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.errorDot)
                    }
                }
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

            LabeledContent("Version") {
                Text(Self.appVersionString)
                    .foregroundStyle(Theme.textSecondary)
            }

            LabeledContent("Developed by") {
                Link("nuotsu", destination: Self.nuotsuURL)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
