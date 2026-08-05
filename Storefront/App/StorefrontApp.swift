import SwiftUI

@main
struct StorefrontApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Plain Window hosting NavigationSplitView — system supplies Liquid Glass
        // sidebar, trailing-edge toggle, and scroll-edge title blur (cmux recipe).
        Window("Settings", id: "settings") {
            SettingsRootView()
                .environment(appDelegate.appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(
            width: SettingsWindowMetrics.idealWidth,
            height: SettingsWindowMetrics.idealHeight
        )
        .commands {
            SettingsCommands()
        }
    }
}

private struct SettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
