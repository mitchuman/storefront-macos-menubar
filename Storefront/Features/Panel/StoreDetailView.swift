import SwiftUI
import AppKit

/// Opens a link and, if ⌥ is held at the moment of the click, keeps the panel open
/// instead of letting it auto-dismiss when the browser steals focus.
@MainActor
func openStoreLink(_ url: URL) {
    if NSEvent.modifierFlags.contains(.option) {
        AppDelegate.shared?.keepPopoverOpenTemporarily()
    }
    NSWorkspace.shared.open(url)
}

struct StoreDetailView: View {
    @EnvironmentObject var appState: AppState
    let store: Store
    @Environment(\.colorScheme) private var colorScheme

    var enabledSections: [SectionID] { appState.enabledSections }

    /// Sections chunked into pairs so each row can be a `GridRow` — `Grid` (unlike
    /// `LazyVGrid`) equalizes height across a row instead of letting each column
    /// stack independently, which is what kept the two columns from lining up.
    private var sectionRows: [[SectionID]] {
        stride(from: 0, to: enabledSections.count, by: 2).map {
            Array(enabledSections[$0..<min($0 + 2, enabledSections.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.hairline)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        ForEach(sectionRows, id: \.self) { row in
                            GridRow {
                                ForEach(row, id: \.self) { section in
                                    SectionCardView(
                                        section: section,
                                        store: store,
                                        isFocused: appState.focusArea == .cards && appState.focusedSectionIndex == (enabledSections.firstIndex(of: section) ?? -1),
                                        focusedRowIndex: appState.focusedRowIndex
                                    )
                                    .id(section)
                                }
                                if row.count == 1 {
                                    Color.clear
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .onChange(of: appState.focusedSectionIndex) { _, newIndex in
                    scrollToFocusedSection(proxy: scrollProxy, index: newIndex)
                }
                .onChange(of: appState.focusArea) { _, newArea in
                    if newArea == .cards {
                        scrollToFocusedSection(proxy: scrollProxy, index: appState.focusedSectionIndex)
                    }
                }
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                CopyableHandleView(handle: store.handle, accentColor: store.color)
                Spacer()
            }
            HStack(spacing: 6) {
                if let adminURL = store.adminURL {
                    HeaderActionButton(title: "Admin", iconName: "HomeIcon", background: store.color, foreground: store.accentTextColor) {
                        openStoreLink(adminURL)
                    }
                }
                if let shopURL = store.shopURL {
                    HeaderActionButton(
                        title: "Online Store",
                        iconName: "GlobeIcon",
                        background: store.color.pillBackground(colorScheme: colorScheme),
                        foreground: store.color.pillTextColor(colorScheme: colorScheme)
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
    }
}

/// The store's `myshopify.com` handle, shown next to its display name. Click to copy
/// it to the clipboard; a checkmark fades in beside it to confirm, then fades back out.
private struct CopyableHandleView: View {
    let handle: String
    let accentColor: Color
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 4) {
            Text(handle)
                .font(.mono(10.5))
                .foregroundStyle(isHovering ? Theme.textBody : Theme.textMeta40)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accentColor)
                .opacity(didCopy ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { copy() }
        .help("Click to copy")
        .animation(.easeOut(duration: 0.15), value: didCopy)
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(handle, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopy = false
        }
    }
}

/// A plain, chrome-free tappable pill. Avoids `Button`/`Link`'s system hover/press
/// styling, which on recent macOS versions can subtly resize the control on hover.
private struct HeaderActionButton: View {
    let title: String
    let iconName: String
    let background: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

/// One section's card in the right-column grid — a title label plus its compact link list.
struct SectionCardView: View {
    let section: SectionID
    let store: Store
    var isFocused: Bool = false
    var focusedRowIndex: Int = 0

    private var rows: [LinkRow] { StaticLinkCatalog.rows(for: section) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title.uppercased())
                .font(.mono(9.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textMeta40)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    CardLinkRow(row: row, store: store, isKeyboardFocused: isFocused && index == focusedRowIndex)
                }
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }
}

/// A single static link within a section card. Fixed padding at all times — only the
/// background fill toggles on hover — so hovering never shifts the row's size
/// or its neighbors' positions.
private struct CardLinkRow: View {
    let row: LinkRow
    let store: Store
    var isKeyboardFocused: Bool = false
    @State private var isHovering = false

    private var isHighlighted: Bool { isHovering || isKeyboardFocused }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(row.iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(isHighlighted ? Theme.textBody : Theme.textMeta40)
            Text(row.title)
                .font(.system(size: 12, weight: row.emphasis == .emphasized ? .medium : .regular))
                .foregroundStyle(labelColor)
            Spacer(minLength: 4)
            if row.createAction != nil {
                CreateActionButton(accentColor: store.color) {
                    guard let url = row.createURL(for: store.myshopifyDomain) else { return }
                    openStoreLink(url)
                }
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, row.createAction != nil ? 3 : 6)
        .padding(.vertical, 3)
        .background(isHighlighted ? Theme.hoverFill : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { openLink() }
    }

    private var labelColor: Color {
        switch row.emphasis {
        case .emphasized: return Theme.textPrimary
        case .normal: return isHighlighted ? Theme.textPrimary : Theme.textBody
        }
    }

    private func openLink() {
        guard let url = row.url(for: store.myshopifyDomain) else { return }
        openStoreLink(url)
    }
}

/// The trailing "New +" action on a row. A separate tap target from the row itself —
/// SwiftUI resolves the tap to whichever view's `contentShape` is directly hit, so
/// tapping this pill opens the create URL instead of the row's own link.
private struct CreateActionButton: View {
    let accentColor: Color
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("+")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(accentColor.pillTextColor(colorScheme: colorScheme))
            .opacity(isHovering ? 0.75 : 1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(accentColor.pillBackground(colorScheme: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture(perform: action)
    }
}
