import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        TabView {
            StoresTabView()
                .tabItem { Label("Stores", systemImage: "bag") }
            SectionsTabView()
                .tabItem { Label("Sections", systemImage: "square.grid.2x2") }
            AccountsTabView()
                .tabItem { Label("Accounts", systemImage: "key") }
            GeneralTabView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 660, height: 420)
    }
}
