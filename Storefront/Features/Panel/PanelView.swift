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
    /// When true, clearing `focusedRowSearchID` must not bounce focus to the rail search
    /// (⌃S collapse parks on the panel instead).
    @State private var suppressRailSearchRefocus = false
    @Environment(\.openWindow) private var openWindow

    /// Detached floating window (under mouse, or menu bar icon hidden).
    private var isFloatingPanel: Bool {
        !appState.settings.showInMenuBar || appState.settings.openUnderMouse
    }

    private var panelCornerRadius: CGFloat {
        isFloatingPanel ? 14 : 0
    }

    @ViewBuilder
    private var panelChromeBackground: some View {
        if appState.settings.opaqueMenuBarWidget {
            Theme.panelOpaqueFill
        } else if isFloatingPanel {
            // No NSPopover vibrancy behind us — supply glass chrome for the frame.
            // allowsHitTesting(false) is belt-and-suspenders; the NSView also
            // passthrough-hitTests (see SidebarGlassBackground).
            SidebarGlassBackground(
                cornerRadius: panelCornerRadius,
                material: .popover,
                blendingMode: .behindWindow
            )
            .allowsHitTesting(false)
        }
    }

    /// The right panel's frame is fully determined by fixed layout constants (not
    /// measured dynamically) — a `GeometryReader` here proved unreliable, since its
    /// preference never committed a non-zero value through the conditionally-built
    /// (`if store != nil { … } else { … }`) content above it.
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
                // Keep identity across hover-select so the detail column updates in place
                // instead of tearing down cards/favicons on every rail scrub.
                StoreDetailView(
                    store: store,
                    focusedRowSearchID: $focusedRowSearchID,
                    onToggleLinkSearchKey: { performToggleLinkSearch() }
                )
            } else {
                emptyState
            }
        }
        .coordinateSpace(name: "panel")
        .background(
            MouseTrackingOverlay { point in
                safeTriangle.handleMouseMoved(to: point)
                appState.notePanelMouseMoved()
            }
            .allowsHitTesting(false)
        )
        .environmentObject(safeTriangle)
        .onPreferenceChange(RowFramePreferenceKey.self) { frames in
            safeTriangle.updateRowFrames(frames)
        }
        .frame(width: Theme.panelSize.width, height: Theme.panelSize.height)
        // Menu bar popover: root stays clear so NSPopover vibrancy fills body + beak
        // (opaque mode fills the frame). Floating (menu bar off): provide our own
        // rounded chrome since there is no popover arrow / system beak.
        .background { panelChromeBackground }
        .modifier(FloatingPanelChromeModifier(isFloating: isFloatingPanel, cornerRadius: panelCornerRadius))
        .preferredColorScheme(appState.settings.appearancePreference.colorScheme)
        .focusable()
        .focused($panelFocused)
        .focusEffectDisabled()
        .onAppear {
            resetPanelInteractionToRail()
            safeTriangle.updateRightPanelFrame(rightPanelFrame)
            safeTriangle.configure { rowID in
                if let store = appState.stores.first(where: { $0.id == rowID }) {
                    appState.select(store)
                }
            }
            safeTriangle.updateSelectedRowID(appState.selectedStoreID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelWillShow)) { _ in
            // Hosting controller is reused across opens — onAppear won't fire again.
            resetPanelInteractionToRail()
        }
        .onChange(of: appState.selectedStoreID) { _, newValue in
            safeTriangle.updateSelectedRowID(newValue)
            // Only steal focus when a TextField would swallow panel shortcuts —
            // skip the churn on every hover-select while the panel is already focused.
            if searchFocused || focusedRowSearchID != nil {
                moveKeyboardFocusToPanel()
            }
        }
        .onChange(of: focusedRowSearchID) { oldValue, newValue in
            // A row's search field just lost real keyboard focus (Escape, submit, or
            // collapsing via the magnifying-glass control) — restore focus to the rail's
            // search field so *something* always holds it. Without this, `.onKeyPress`
            // below has no focused responder to fire from at all, silently breaking every
            // keyboard shortcut (arrows included) until the panel is closed and reopened.
            // ⌃S collapse sets `suppressRailSearchRefocus` and parks on the panel instead.
            if oldValue != nil && newValue == nil, !suppressRailSearchRefocus {
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

    /// Store list active, cards inactive — ready for ↑↓ store navigation.
    private func resetPanelInteractionToRail() {
        appState.exitToRail()
        moveKeyboardFocusToPanel()
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

    /// Shared by panel `onKeyPress` and the row-search `TextField` (which can swallow ⌃S
    /// before it bubbles). Returns whether the shortcut was applicable.
    @discardableResult
    private func performToggleLinkSearch() -> Bool {
        // Block only while typing in the rail store search with no active card link.
        // Hover/click puts `focusArea` into `.cards`, so ⌃S still works for mouse users
        // even if the rail search still holds text focus.
        if searchFocused && focusedRowSearchID == nil && appState.focusArea != .cards {
            return false
        }
        guard let result = appState.toggleSearchForFocusedLink() else { return false }
        if result.isNowExpanded {
            suppressRailSearchRefocus = false
            focusLinkSearchField(result.rowID)
        } else {
            suppressRailSearchRefocus = true
            moveKeyboardFocusToPanel()
            DispatchQueue.main.async {
                suppressRailSearchRefocus = false
            }
        }
        return true
    }

    /// Puts the caret in the expanded row search — sync + next-turn so the field exists
    /// in the hierarchy after expand before `@FocusState` commits.
    private func focusLinkSearchField(_ rowID: String) {
        panelFocused = false
        searchFocused = false
        focusedRowSearchID = rowID
        DispatchQueue.main.async {
            self.panelFocused = false
            self.searchFocused = false
            self.focusedRowSearchID = rowID
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
        // can collapse/re-expand continuously), but not while the rail store search
        // is focused.
        if appState.settings.toggleLinkSearchHotkey.matches(keyPress) {
            return performToggleLinkSearch() ? .handled : .ignored
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

        // Escape from the rail search returns to the store list (not close / stay in field).
        if keyPress.key == .escape, searchFocused {
            appState.exitToRail()
            moveKeyboardFocusToPanel()
            return .handled
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
            if appState.focusArea == .rail {
                appState.enterCards()
            } else {
                appState.moveCardFocus(offset: -1)
            }
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
                moveKeyboardFocusToPanel()
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

/// Rounded clip for the detached (menu bar off) panel only —
/// leave the menu-bar NSPopover path untouched so the system beak still composites.
private struct FloatingPanelChromeModifier: ViewModifier {
    let isFloating: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if isFloating {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
        }
    }
}

#Preview {
    PanelView()
        .environmentObject(AppState())
}
