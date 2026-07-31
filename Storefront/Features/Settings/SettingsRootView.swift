import AppKit
import SwiftUI

enum SettingsWindowMetrics {
    static let width: CGFloat = 520
    static let minHeight: CGFloat = 480
    static let idealHeight: CGFloat = 620
}

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
        // Fixed width; height flexible so the window can grow/shrink vertically.
        .frame(width: SettingsWindowMetrics.width)
        .frame(
            minHeight: SettingsWindowMetrics.minHeight,
            idealHeight: SettingsWindowMetrics.idealHeight,
            maxHeight: .infinity
        )
        .background(SettingsWindowConfigurator())
    }
}

/// SwiftUI `Settings` scenes often ignore vertical resize; pin AppKit min/max size
/// so width stays locked and height is user-resizable.
private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            Self.apply(to: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.apply(to: nsView.window, coordinator: context.coordinator)
        }
    }

    final class Coordinator {
        var didApplyDefaultHeight = false
    }

    private static func apply(to window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: SettingsWindowMetrics.width, height: SettingsWindowMetrics.minHeight)
        // Lock horizontal growth; allow tall vertical growth.
        window.maxSize = NSSize(width: SettingsWindowMetrics.width, height: 10_000)

        var frame = window.frame
        var changed = false

        if abs(frame.size.width - SettingsWindowMetrics.width) > 0.5 {
            let deltaW = SettingsWindowMetrics.width - frame.size.width
            frame.size.width = SettingsWindowMetrics.width
            frame.origin.x += deltaW / 2
            changed = true
        }

        // Raise the first open to the taller default without fighting later user shrinks.
        if !coordinator.didApplyDefaultHeight {
            coordinator.didApplyDefaultHeight = true
            if frame.size.height < SettingsWindowMetrics.idealHeight {
                let deltaH = SettingsWindowMetrics.idealHeight - frame.size.height
                frame.size.height = SettingsWindowMetrics.idealHeight
                frame.origin.y -= deltaH
                changed = true
            }
        }

        if changed {
            window.setFrame(frame, display: true)
        }
    }
}
