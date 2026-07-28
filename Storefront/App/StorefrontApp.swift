import SwiftUI

@main
struct StorefrontApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.appState)
        }
    }
}
