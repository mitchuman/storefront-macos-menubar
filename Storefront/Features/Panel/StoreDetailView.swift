import SwiftUI
import AppKit

/// Opens a link. A normal click closes the panel; ⌘-click keeps it open while the
/// browser activates (transient popovers don't always dismiss on URL open alone).
/// Pass `keepOpen` explicitly for keyboard shortcuts that include ⌘ so they don't
/// accidentally inherit the click keep-open path.
@MainActor
func openStoreLink(_ url: URL, keepOpen: Bool? = nil) {
    let shouldKeepOpen = keepOpen ?? NSEvent.modifierFlags.contains(.command)
    if shouldKeepOpen {
        AppDelegate.shared?.keepPopoverOpenTemporarily()
    }
    NSWorkspace.shared.open(url)
    if !shouldKeepOpen {
        AppDelegate.shared?.closePanel()
    }
}

struct StoreDetailView: View {
    @EnvironmentObject var appState: AppState
    let store: Store
    var focusedRowSearchID: FocusState<String?>.Binding
    /// Invoked when ⌃S is pressed while a row search field holds focus (TextField can
    /// swallow the chord before `PanelView.onKeyPress` sees it).
    var onToggleLinkSearchKey: () -> Bool = { false }
    @Environment(\.colorScheme) private var colorScheme

    var enabledSections: [SectionID] { appState.enabledSections }

    /// A section paired with its index in `enabledSections`, so the card grid never has
    /// to scan back for it. `AppState.enabledSections` allocates a fresh filtered array
    /// on every access, so the whole grid is derived from one read per body.
    private struct SectionSlot: Identifiable, Hashable {
        let index: Int
        let section: SectionID
        var id: SectionID { section }
    }

    /// Slots chunked into pairs so each row can be a `GridRow` — `Grid` (unlike
    /// `LazyVGrid`) equalizes height across a row instead of letting each column
    /// stack independently, which is what kept the two columns from lining up.
    private struct SectionGridRow: Identifiable {
        let id: Int
        let slots: [SectionSlot]
    }

    private func sectionRows(for sections: [SectionID]) -> [SectionGridRow] {
        stride(from: 0, to: sections.count, by: 2).enumerated().map { rowIndex, start in
            SectionGridRow(
                id: rowIndex,
                slots: (start..<min(start + 2, sections.count)).map {
                    SectionSlot(index: $0, section: sections[$0])
                }
            )
        }
    }

    var body: some View {
        let sections = enabledSections
        let focusedSectionIndex = appState.focusArea == .cards ? appState.focusedSectionIndex : -1

        // Same recipe as Settings → Keybindings: soft `scrollEdgeEffectStyle` under a
        // top bar. `safeAreaBar` is the popover stand-in for the Settings titleband
        // that the system progressive blur attaches to.
        ScrollViewReader { scrollProxy in
            ScrollView {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(sectionRows(for: sections)) { row in
                        GridRow {
                            ForEach(row.slots) { slot in
                                let isFocused = slot.index == focusedSectionIndex
                                SectionCardView(
                                    section: slot.section,
                                    store: store,
                                    isFocused: isFocused,
                                    // Only the focused card cares about the row index —
                                    // pinning the rest to -1 keeps an arrow-key row move
                                    // from changing a parameter on every other card.
                                    focusedRowIndex: isFocused ? appState.focusedRowIndex : -1,
                                    focusedRowSearchID: focusedRowSearchID,
                                    onToggleLinkSearchKey: onToggleLinkSearchKey
                                )
                                .id(slot.section)
                            }
                            if row.slots.count == 1 {
                                Color.clear
                            }
                        }
                    }
                }
                .padding(12)
            }
            .settingsTopScrollEdgeBlur()
            .detailHeaderSafeAreaBar {
                header
            }
            // Scroll only when keyboard navigation bumps `cardScrollGeneration` — not when
            // hover/click updates `focusedSectionIndex`.
            .onChange(of: appState.cardScrollGeneration) { _, _ in
                scrollToFocusedSection(proxy: scrollProxy, index: appState.focusedSectionIndex)
            }
        }
    }

    /// Keeps the keyboard-focused card on screen while looping Left/Right through the grid.
    private func scrollToFocusedSection(proxy: ScrollViewProxy, index: Int) {
        guard index < enabledSections.count else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(enabledSections[index], anchor: .center)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                StoreFaviconView(store: store, size: 22)
                Text(store.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    // Floating panel: drag from the title like a native titlebar label.
                    .modifier(PanelWindowDragModifier(enabled: !appState.settings.showInMenuBar || appState.settings.openUnderMouse))
            }
            CopyableHandleView(handle: store.handle, domain: store.myshopifyDomain, accentColor: store.color)
                .padding(.top, 3)
            HStack(spacing: 6) {
                if let adminURL = store.adminURL {
                    HeaderActionButton(
                        title: "Admin",
                        iconName: "HomeIcon",
                        background: store.color,
                        foreground: store.accentTextColor,
                        shortcutLetter: appState.settings.openAdminHotkey.mnemonicLetter
                    ) {
                        openStoreLink(adminURL)
                    }
                }
                if let shopURL = store.shopURL {
                    HeaderActionButton(
                        title: "Online Store",
                        iconName: "StoreIcon",
                        background: store.color.pillBackground(colorScheme: colorScheme),
                        foreground: store.color.pillTextColor(colorScheme: colorScheme),
                        shortcutLetter: appState.settings.openOnlineStoreHotkey.mnemonicLetter
                    ) {
                        openStoreLink(shopURL)
                    }
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The store's `myshopify.com` domain, shown next to its display name as two
/// tappable segments. Click the handle to copy just that id; click `.myshopify.com`
/// to copy the full domain. A checkmark fades in beside it to confirm.
private struct CopyableHandleView: View {
    let handle: String
    let domain: String
    let accentColor: Color
    @State private var hoveringHandle = false
    @State private var hoveringSuffix = false
    @State private var didCopy = false
    @State private var hideCheckmarkTask: Task<Void, Never>?

    private static let suffix = ".myshopify.com"

    private var handleColor: Color {
        (hoveringHandle || hoveringSuffix) ? Theme.textBody : Theme.textSecondary
    }

    private var suffixColor: Color {
        hoveringSuffix ? Theme.textBody : Theme.textMeta30
    }

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 0) {
                Text(handle)
                    .font(.mono(10.5))
                    .foregroundStyle(handleColor)
                    .overlay(alignment: .bottom) {
                        TightDashUnderline(color: handleColor)
                            .opacity(hoveringHandle || hoveringSuffix ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onHover { hoveringHandle = $0 }
                    .onTapGesture { copy(handle) }
                    .help("Copy handle")

                Text(Self.suffix)
                    .font(.mono(10.5))
                    .foregroundStyle(suffixColor)
                    .overlay(alignment: .bottom) {
                        TightDashUnderline(color: suffixColor)
                            .opacity(hoveringSuffix ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onHover { hoveringSuffix = $0 }
                    .onTapGesture { copy(domain) }
                    .help("Copy domain")
            }
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accentColor)
                .opacity(didCopy ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.15), value: didCopy)
        .animation(.easeOut(duration: 0.12), value: hoveringHandle)
        .animation(.easeOut(duration: 0.12), value: hoveringSuffix)
        // Detail keeps identity across store switches — clear ephemeral copy UI.
        .onChange(of: domain) { _, _ in
            hideCheckmarkTask?.cancel()
            hideCheckmarkTask = nil
            didCopy = false
            hoveringHandle = false
            hoveringSuffix = false
        }
        .onDisappear {
            hideCheckmarkTask?.cancel()
            hideCheckmarkTask = nil
        }
    }

    private func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        didCopy = true
        // Only the latest click owns the fade-out — older sleeps must not clear a newer copy.
        hideCheckmarkTask?.cancel()
        hideCheckmarkTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            didCopy = false
            hideCheckmarkTask = nil
        }
    }
}

/// Compact dashed underline — tighter than system `.dash` spacing.
private struct TightDashUnderline: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [2.5, 1.5]))
        }
        .frame(height: 1)
        .offset(y: 1)
        .allowsHitTesting(false)
    }
}

/// Compact dotted underline — round dots, not dashes.
private struct TightDotUnderline: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            // Inset so round caps sit inside the letter’s advance, not past its edges.
            let inset: CGFloat = 0.75
            let width = max(0, geo.size.width - inset * 2)
            Path { path in
                path.move(to: CGPoint(x: inset, y: 0.5))
                path.addLine(to: CGPoint(x: inset + width, y: 0.5))
            }
            // Near-zero dash + round caps → true dots rather than short dashes.
            .stroke(color, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, dash: [0.01, 2.25]))
        }
        .frame(height: 1)
        // Sit just under the glyph (overlay `.bottom` already clears the baseline box).
        .offset(y: -1)
        .allowsHitTesting(false)
    }
}

/// A plain, chrome-free tappable pill. Avoids `Button`/`Link`'s system hover/press
/// styling, which on recent macOS versions can subtly resize the control on hover.
private struct HeaderActionButton: View {
    let title: String
    let iconName: String
    let background: Color
    let foreground: Color
    /// When set to a letter that appears in `title`, that first match gets a dotted
    /// underline as a mnemonic for the panel shortcut.
    var shortcutLetter: Character? = nil
    let action: () -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 6) }

    private var fill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.composited(over: background, alpha: 0.12),
                background,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Splits `title` around the first case-insensitive match of `shortcutLetter`.
    private var mnemonicParts: (before: String, letter: String, after: String)? {
        guard let shortcutLetter,
              let index = title.firstIndex(where: { $0.lowercased() == String(shortcutLetter).lowercased() })
        else { return nil }
        return (
            String(title[..<index]),
            String(title[index]),
            String(title[title.index(after: index)...])
        )
    }

    @ViewBuilder
    private var titledText: some View {
        if let parts = mnemonicParts {
            HStack(spacing: 0) {
                Text(parts.before)
                Text(parts.letter)
                    .overlay(alignment: .bottom) {
                        TightDotUnderline(color: foreground)
                    }
                Text(parts.after)
            }
        } else {
            Text(title)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
            titledText
                .font(.system(size: 11, weight: .medium))
        }
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                shape
                    .fill(fill)
                    .shadow(color: .black.opacity(0.14), radius: 1, y: 0.5)
            }
            .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
            .contentShape(shape)
            .onTapGesture(perform: action)
    }
}

/// One section's card in the right-column grid — a title label plus its compact link list.
struct SectionCardView: View {
    let section: SectionID
    let store: Store
    var isFocused: Bool = false
    var focusedRowIndex: Int = 0
    var focusedRowSearchID: FocusState<String?>.Binding
    var onToggleLinkSearchKey: () -> Bool = { false }
    @EnvironmentObject var appState: AppState

    private var rows: [LinkRow] { StaticLinkCatalog.rows(for: section) }
    private var isOpaque: Bool { appState.settings.opaqueMenuBarWidget }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(section.title.uppercased())
                    .font(.mono(9.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMeta40)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isFocused {
                    HStack(spacing: 0) {
                        Image(systemName: "arrow.up")
                        Image(systemName: "arrow.down")
                    }
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Theme.textMeta25)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    CardLinkRow(
                        row: row,
                        store: store,
                        section: section,
                        rowIndex: index,
                        isActive: isFocused && index == focusedRowIndex,
                        focusedRowSearchID: focusedRowSearchID,
                        onToggleLinkSearchKey: onToggleLinkSearchKey
                    )
                }
            }
            // Grid equalizes card height across a GridRow's two columns (see the comment
            // on `sectionRows`) — a short card (e.g. one row) gets offered extra vertical
            // space to match its taller neighbor. Without `fixedSize`, that extra space
            // was stretching the last row itself rather than landing as blank card padding
            // below it (the intended, already-accepted tradeoff of using `Grid` here).
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Clip only the backdrop so row hover shadows aren't cut off.
        .background {
            Group {
                if isOpaque {
                    Theme.panelOpaqueElevatedFill
                } else {
                    SidebarGlassBackground(cornerRadius: 9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .overlay {
            if isOpaque {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            }
        }
        .shadow(color: isOpaque ? Theme.panelElevatedShadow : .clear, radius: 3, y: 1)
    }
}

/// A single static link within a section card. Fixed padding at all times — only the
/// background fill toggles on hover — so hovering never shifts the row's size
/// or its neighbors' positions.
private struct CardLinkRow: View {
    let row: LinkRow
    let store: Store
    let section: SectionID
    let rowIndex: Int
    /// Sole active highlight for this store's card grid — driven by `AppState` so hover,
    /// click, and arrow keys share one selection (hover/click override arrows).
    var isActive: Bool = false
    var focusedRowSearchID: FocusState<String?>.Binding
    var onToggleLinkSearchKey: () -> Bool = { false }
    @EnvironmentObject var appState: AppState
    /// True while the pointer is inside this row — used to activate after hover is
    /// re-armed following a keyboard scroll (`.onHover` does not re-fire for a
    /// stationary cursor).
    @State private var pointerInside = false

    /// Lives in `AppState` (not local `@State`) so the ⌃S keyboard shortcut can toggle a
    /// row's search regardless of which `CardLinkRow` instance it belongs to, and so
    /// switching stores and back doesn't lose it (detail keeps identity across stores).
    private var isSearchExpanded: Bool { appState.expandedSearchRowIDs[store.id]?.contains(row.id) ?? false }

    private var searchQuery: Binding<String> {
        Binding(
            get: { appState.searchQueries[store.id]?[row.id] ?? "" },
            set: { appState.searchQueries[store.id, default: [:]][row.id] = $0 }
        )
    }

    private var hasTrailingActions: Bool { row.createAction != nil || row.supportsSearch }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Image(row.iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(isActive ? Theme.textBody : Theme.textMeta40)
                    Text(row.title)
                        .font(.system(size: 12, weight: row.emphasis == .emphasized ? .medium : .regular))
                        .foregroundStyle(labelColor)
                    Spacer(minLength: 4)
                }
                .padding(.vertical, 3)
                // Scoped to just the link's own zone — the "+"/search buttons sit outside
                // this contentShape entirely (as separate HStack siblings below), so clicking
                // between/around them can never fall through and register as opening the link.
                // Padding lives here (not on the outer HStack) so the buttons' own
                // `maxHeight: .infinity` stretches to match this row's *full* height,
                // including the padding, instead of leaving a dead strip top/bottom.
                .contentShape(Rectangle())
                .onTapGesture {
                    becomeActive()
                    openLink()
                }

                // Its own tight-spacing group — the outer HStack's spacing (6) only applies
                // between the link zone and this whole cluster, not within it.
                HStack(alignment: .center, spacing: 2) {
                    if row.supportsSearch {
                        PillSegment(isActive: isSearchExpanded) {
                            becomeActive()
                            if isSearchExpanded {
                                appState.expandedSearchRowIDs[store.id]?.remove(row.id)
                                if focusedRowSearchID.wrappedValue == row.id {
                                    // Only clear the shared focus if it was actually this row's —
                                    // collapsing a row that's expanded-but-unfocused (another row
                                    // currently has focus) must not steal focus away from it.
                                    focusedRowSearchID.wrappedValue = nil
                                }
                            } else {
                                appState.expandedSearchRowIDs[store.id, default: []].insert(row.id)
                                focusedRowSearchID.wrappedValue = row.id
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    if row.createAction != nil && row.supportsSearch {
                        Rectangle()
                            .fill(Theme.divider)
                            .frame(width: 1, height: 12)
                    }
                    if row.createAction != nil {
                        PillSegment {
                            becomeActive()
                            guard let url = row.createURL(for: store.myshopifyDomain) else { return }
                            openStoreLink(url)
                        } label: {
                            Text("+")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, hasTrailingActions ? 3 : 6)
            .contentShape(Rectangle())
            .onHover { hovering in
                pointerInside = hovering
                if hovering { tryActivateFromHover() }
            }
            .onChange(of: appState.cardLinkHoverArmed) { _, armed in
                if armed && pointerInside { becomeActive() }
            }

            if isSearchExpanded {
                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 1)

                // Custom placeholder: AppKit's cell placeholder jumps when the field
                // editor attaches on focus; a SwiftUI label stays put.
                ZStack(alignment: .leading) {
                    if searchQuery.wrappedValue.isEmpty {
                        Text("Search")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textMeta30)
                            .allowsHitTesting(false)
                    }
                    CaretTintedTextField(
                        text: searchQuery,
                        caretColor: NSColor(hex: store.colorHex),
                        onSubmit: submitSearch
                    )
                        .focused(focusedRowSearchID, equals: row.id)
                        .focusEffectDisabled()
                        .onExitCommand {
                            appState.expandedSearchRowIDs[store.id]?.remove(row.id)
                            if focusedRowSearchID.wrappedValue == row.id {
                                focusedRowSearchID.wrappedValue = nil
                            }
                        }
                        .onKeyPress { keyPress in
                            if appState.settings.toggleLinkSearchHotkey.matches(keyPress) {
                                return onToggleLinkSearchKey() ? .handled : .ignored
                            }
                            return .ignored
                        }
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 26)
            }
        }
        .background {
            // Active highlight is AppState-driven only — never stack hover + arrow
            // highlights. Expanded search without active focus keeps no fill.
            if isActive {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.controlFill)
            }
        }
    }

    private var labelColor: Color {
        switch row.emphasis {
        case .emphasized: return Theme.textPrimary
        case .normal: return isActive ? Theme.textPrimary : Theme.textBody
        }
    }

    private func tryActivateFromHover() {
        appState.focusCardLink(section: section, rowIndex: rowIndex, fromHover: true)
    }

    private func becomeActive() {
        appState.focusCardLink(section: section, rowIndex: rowIndex)
    }

    private func openLink() {
        guard let url = row.url(for: store.myshopifyDomain) else { return }
        openStoreLink(url)
    }

    private func submitSearch() {
        guard let url = row.searchURL(for: store.myshopifyDomain, query: searchQuery.wrappedValue) else { return }
        openStoreLink(url)
        // `openStoreLink` hands focus to the browser, which can leave this row's
        // `@FocusState` binding stuck non-nil (the window resigning key status doesn't
        // reliably clear it) — that would otherwise permanently block the global
        // keyboard-nav guard in `PanelView`. Release it explicitly rather than relying
        // on SwiftUI to notice the field lost real focus.
        if focusedRowSearchID.wrappedValue == row.id {
            focusedRowSearchID.wrappedValue = nil
        }
    }
}

/// One "+" or search tap target — a bare glyph, neutral-colored like the row's own
/// leading icon, with no pill background of its own. Stretches to the row's full height
/// (via `frame` before `contentShape`, so the hit area actually grows with it, not just
/// the glyph) so there's no dead space above/below it that would otherwise fall through
/// to the row's own link tap gesture.
private struct PillSegment<Label: View>: View {
    var isActive: Bool = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var isHovering = false

    var body: some View {
        label()
            .foregroundStyle(isHovering || isActive ? Theme.textBody : Theme.textMeta40)
            .padding(.horizontal, 3)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture(perform: action)
    }
}
