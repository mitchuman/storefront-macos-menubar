import SwiftUI
import AppKit

struct GeneralTabView: View {
    // A compile-time-constant literal — the force unwrap can't practically fail, but
    // hoisting it here keeps it a single obvious spot to double-check if this ever changes.
    private static let nuotsuURL = URL(string: "https://nuotsu.dev")!

    @EnvironmentObject var appState: AppState
    @State private var hotkeyErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: { appState.setLaunchAtLogin($0) }
                ))
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
                if let hotkeyErrorMessage {
                    // A plain `Form` child (not nested in the `LabeledContent` above) so it
                    // spans and left-aligns like "ABOUT" below, instead of being sized/aligned
                    // relative to the (much narrower) hotkey badge next to its own label.
                    Text(hotkeyErrorMessage)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.errorDot)
                }

                Text("ABOUT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(Theme.textMeta40)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }

            // Kept outside both `Form`s — an unlabeled row inside one throws off the
            // automatic label-column width `Form` computes across all its other rows
            // (that's what previously pushed "Launch at login"/"Global hotkey" out of
            // alignment when this lived at the top of the first `Form`).
            HStack {
                Spacer()
                // Reads the actual configured `AppIcon` asset directly, rather than a
                // duplicated image, so this preview can't drift out of sync with it.
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Spacer()
            }
            .padding(.bottom, 10)

            Form {
                LabeledContent("App name") {
                    Text("Storefront")
                        .foregroundStyle(Theme.textSecondary)
                }
                LabeledContent("Description") {
                    Text("Jump into any Shopify store's admin panel in seconds.")
                        .foregroundStyle(Theme.textSecondary)
                }
                LabeledContent("Version") {
                    Text(Self.appVersionString)
                        .foregroundStyle(Theme.textSecondary)
                }
                LabeledContent("Developed by") {
                    Link("nuotsu", destination: Self.nuotsuURL)
                }
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
