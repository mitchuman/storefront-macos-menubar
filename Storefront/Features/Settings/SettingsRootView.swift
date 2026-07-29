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
            GeneralTabView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
        }
        .frame(width: 660, height: 420)
    }
}
