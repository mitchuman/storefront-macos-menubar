import SwiftUI
import AppKit

struct PanelView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var safeTriangle = SafeTriangleController()
    @FocusState private var searchFocused: Bool
    @Environment(\.openSettings) private var openSettings

    /// The right panel's frame is fully determined by fixed layout constants (not
    /// measured dynamically) — a `GeometryReader` here proved unreliable, since its
    /// preference never committed a non-zero value through the conditionally-built
    /// (`if store != nil { … } else { … }`, `.id(store.id)`-churning) content above it.
    private var rightPanelFrame: CGRect {
        let dividerWidth: CGFloat = 1
        let originX = Theme.railWidth + dividerWidth
        return CGRect(x: originX, y: 0, width: Theme.panelSize.width - originX, height: Theme.panelSize.height)
    }

    var body: some View {
        HStack(spacing: 0) {
            StoreRailView(searchFocused: $searchFocused)

            Divider().overlay(Theme.divider)

            if let store = appState.selectedStore {
                StoreDetailView(store: store)
                    .id(store.id)
            } else {
                emptyState
            }
        }
        .coordinateSpace(name: "panel")
        .background(
            MouseTrackingOverlay { point in
                safeTriangle.handleMouseMoved(to: point)
            }
            .allowsHitTesting(false)
        )
        .environmentObject(safeTriangle)
        .onPreferenceChange(RowFramePreferenceKey.self) { frames in
            safeTriangle.updateRowFrames(frames)
        }
        .frame(width: Theme.panelSize.width, height: Theme.panelSize.height)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.borderColor, lineWidth: 1)
        )
        .onAppear {
            searchFocused = true
            appState.exitToRail()
            safeTriangle.updateRightPanelFrame(rightPanelFrame)
            safeTriangle.configure { rowID in
                if let store = appState.stores.first(where: { $0.id == rowID }) {
                    appState.select(store)
                }
            }
            safeTriangle.updateSelectedRowID(appState.selectedStoreID)
        }
        .onChange(of: appState.selectedStoreID) { _, newValue in
            safeTriangle.updateSelectedRowID(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.modifiers.contains(.command) {
            if keyPress.key == "q" {
                NSApp.terminate(nil)
                return .handled
            }
            if let digit = Int(String(keyPress.key.character)), (1...9).contains(digit) {
                appState.selectStore(atShortcutIndex: digit)
                return .handled
            }
            return .ignored
        }

        switch keyPress.key {
        case .upArrow:
            if appState.focusArea == .rail {
                appState.selectAdjacentStore(offset: -1)
            } else {
                appState.moveRowFocus(offset: -1)
            }
            return .handled
        case .downArrow:
            if appState.focusArea == .rail {
                appState.selectAdjacentStore(offset: 1)
            } else {
                appState.moveRowFocus(offset: 1)
            }
            return .handled
        case .leftArrow:
            guard appState.focusArea == .cards else { return .ignored }
            appState.moveCardFocus(offset: -1)
            return .handled
        case .rightArrow:
            if appState.focusArea == .rail {
                appState.enterCards()
            } else {
                appState.moveCardFocus(offset: 1)
            }
            return .handled
        case .return:
            guard appState.focusArea == .cards else { return .ignored }
            appState.openFocusedLink()
            return .handled
        case .escape:
            if appState.focusArea == .cards {
                appState.exitToRail()
                searchFocused = true
            } else {
                AppDelegate.shared?.closePanel()
            }
            return .handled
        default:
            return .ignored
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No stores yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Add a store from Settings to get started.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PanelView()
        .environmentObject(AppState())
}
