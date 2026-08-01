import SwiftUI
import AppKit

struct PanelView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var safeTriangle = SafeTriangleController()
    @FocusState private var searchFocused: Bool
    @FocusState private var focusedRowSearchID: String?
    /// Non-text focus target so shortcuts keep working after the search field is blurred
    /// (e.g. after ⌘1–9), without the text field swallowing ⌘A / ⌘O.
    @FocusState private var panelFocused: Bool
    @Environment(\.openWindow) private var openWindow

    /// The right panel's frame is fully determined by fixed layout constants (not
    /// measured dynamically) — a `GeometryReader` here proved unreliable, since its
    /// preference never committed a non-zero value through the conditionally-built
    /// (`if store != nil { … } else { … }`, `.id(store.id)`-churning) content above it.
    private var rightPanelFrame: CGRect {
        let originX = Theme.railInset + Theme.railWidth + Theme.railGap
        return CGRect(x: originX, y: 0, width: Theme.panelSize.width - originX, height: Theme.panelSize.height)
    }

    var body: some View {
        HStack(spacing: Theme.railGap) {
            StoreRailView(searchFocused: $searchFocused)
                .padding(.leading, Theme.railInset)
                .padding(.vertical, Theme.railInset)

            if let store = appState.selectedStore {
                StoreDetailView(store: store, focusedRowSearchID: $focusedRowSearchID)
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
        // Root stays clear so NSPopover chrome fills body and beak with one material.
        .preferredColorScheme(appState.settings.appearancePreference.colorScheme)
        .focusable()
        .focused($panelFocused)
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
        .onChange(of: focusedRowSearchID) { oldValue, newValue in
            // A row's search field just lost real keyboard focus (Escape, toggle-off,
            // submit, or ⌃S collapsing it) — restore focus to the rail's search field so
            // *something* always holds it. Without this, `.onKeyPress` below has no
            // focused responder to fire from at all, silently breaking every keyboard
            // shortcut (arrows included) until the panel is closed and reopened.
            if oldValue != nil && newValue == nil {
                searchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    /// Blur text fields and park focus on the panel so shortcut chords aren't eaten by
    /// `TextField` (⌘A select-all, typing, etc.).
    private func moveKeyboardFocusToPanel() {
        focusedRowSearchID = nil
        searchFocused = false
        panelFocused = true
        // If clearing a row-search focus synchronously re-focuses the rail search via
        // `onChange`, win on the next turn.
        DispatchQueue.main.async {
            searchFocused = false
            panelFocused = true
        }
    }

    private func focusStoreSearch() {
        appState.exitToRail()
        focusedRowSearchID = nil
        panelFocused = false
        searchFocused = true
        DispatchQueue.main.async {
            searchFocused = true
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let typingInSearch = searchFocused || focusedRowSearchID != nil

        // Store-search focus only when not already typing in a field.
        if !typingInSearch, appState.settings.focusSearchHotkey.matches(keyPress) {
            focusStoreSearch()
            return .handled
        }
        // Link-search toggle stays available while a row search is focused (so ⌃S
        // can collapse it), but not while the rail store search is focused.
        if !searchFocused, appState.settings.toggleLinkSearchHotkey.matches(keyPress) {
            if let result = appState.toggleSearchForFocusedLink() {
                if result.isNowExpanded {
                    focusedRowSearchID = result.rowID
                } else if focusedRowSearchID == result.rowID {
                    focusedRowSearchID = nil
                }
            }
            return .handled
        }

        if keyPress.modifiers.contains(.command) {
            if keyPress.key == "q" {
                NSApp.terminate(nil)
                return .handled
            }
            if let digit = Int(String(keyPress.key.character)), (1...9).contains(digit) {
                appState.selectStore(atShortcutIndex: digit)
                moveKeyboardFocusToPanel()
                return .handled
            }
            return .ignored
        }

        // While typing in the rail or row search field, let the TextField handle
        // keys (including A/O/arrows) instead of panel shortcuts / grid nav.
        guard !typingInSearch else { return .ignored }

        if appState.settings.openAdminHotkey.matches(keyPress) {
            appState.openSelectedAdmin()
            return .handled
        }
        if appState.settings.openOnlineStoreHotkey.matches(keyPress) {
            appState.openSelectedOnlineStore()
            return .handled
        }
        if appState.settings.openCreateLinkHotkey.matches(keyPress) {
            appState.openFocusedCreateLink()
            return .handled
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
