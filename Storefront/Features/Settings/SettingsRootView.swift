import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedSettingsTab) {
            StoresTabView()
                .tabItem { Label("Stores", systemImage: "bag") }
                .tag(SettingsTab.stores)
            SectionsTabView()
                .tabItem { Label("Sections", systemImage: "square.grid.2x2") }
                .tag(SettingsTab.sections)
            ShortcutsTabView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag(SettingsTab.shortcuts)
            GeneralTabView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            AboutTabView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 660, height: 420)
    }
}
