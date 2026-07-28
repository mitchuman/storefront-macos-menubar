import SwiftUI
import AppKit

/// Opens a link and, if ⌥ is held at the moment of the click, keeps the panel open
/// instead of letting it auto-dismiss when the browser steals focus (⌥-click /
/// ⌥⏎ "keep open" per the footer hint).
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

    var enabledSections: [SectionID] {
        appState.settings.sectionOrder.filter { appState.settings.enabledSections.contains($0) }
    }

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

            ScrollView {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(sectionRows, id: \.self) { row in
                        GridRow {
                            ForEach(row, id: \.self) { section in
                                SectionCardView(section: section, store: store)
                            }
                            if row.count == 1 {
                                Color.clear
                            }
                        }
                    }
                }
                .padding(12)
            }

            Divider().overlay(Theme.hairline)
            footer
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
                    HeaderActionButton(title: "Online Store", iconName: "GlobeIcon", background: Theme.controlFill, foreground: Theme.textBody) {
                        openStoreLink(shopURL)
                    }
                }
            }
            .padding(.top, 10)

            if !store.hasToken {
                ConnectBanner(store: store)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack {
            Text(syncedLabel)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textMeta40.opacity(0.9))
            Spacer()
            Text("⏎ open · ⌥⏎ keep open")
                .font(.mono(10.5))
                .foregroundStyle(Theme.textMeta30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.footerBackground)
    }

    private var syncedLabel: String {
        guard let date = store.lastRefreshedAt else {
            return store.hasToken ? "Not yet synced" : "Links only"
        }
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        return "Synced \(minutes) min ago"
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
                .frame(width: 11, height: 11)
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
/// Enriched sections layer live data (or a loading/connect/reconnect state) below the
/// static links once a store is connected.
struct SectionCardView: View {
    @EnvironmentObject var appState: AppState
    let section: SectionID
    let store: Store

    private var rows: [LinkRow] { StaticLinkCatalog.rows(for: section) }
    private var cache: StoreCache? { appState.caches[store.id] }
    private var isLoading: Bool { appState.syncState[store.id] == .loading }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 5) {
                Image(section.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
                    .foregroundStyle(Theme.textMeta40)
                Text(section.title.uppercased())
                    .font(.mono(9.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textMeta40)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    CardLinkRow(row: row, store: store, trailingCount: orderCount(for: row))
                }
                if section.kind == .enriched && store.hasToken {
                    enrichedContent
                }
            }

            if store.connectionStatus == .tokenInvalid {
                AuthExpiredNotice(store: store)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    /// Orders rows show a live count once enrichment data lands, keyed to the specific row.
    private func orderCount(for row: LinkRow) -> Int? {
        guard section == .orders, let stats = cache?.orderStats else { return nil }
        switch row.id {
        case "orders.unfulfilled": return stats.unfulfilledCount
        case "orders.drafts": return stats.draftCount
        case "orders.abandoned": return stats.abandonedCount
        default: return nil
        }
    }

    @ViewBuilder
    private var enrichedContent: some View {
        switch section {
        case .products:
            if let cache, !cache.recentlyEditedProducts.isEmpty {
                ForEach(cache.recentlyEditedProducts) { product in
                    DynamicRow(title: product.title, iconName: "ProductIcon", path: "/products/\(product.id.shopifyNumericID)", store: store)
                }
            } else if isLoading {
                SkeletonRows(count: 3)
            }
        case .collections:
            if let cache, !cache.topCollections.isEmpty {
                ForEach(cache.topCollections) { collection in
                    DynamicRow(title: collection.title, iconName: "CollectionIcon", path: "/collections/\(collection.id.shopifyNumericID)", store: store, meta: "\(collection.productsCount)")
                }
            } else if isLoading {
                SkeletonRows(count: 2)
            }
        case .themes:
            if let cache, cache.liveTheme != nil || !cache.unpublishedThemes.isEmpty {
                if let live = cache.liveTheme {
                    ThemeRow(theme: live, store: store)
                }
                ForEach(cache.unpublishedThemes) { theme in
                    ThemeRow(theme: theme, store: store)
                }
            } else if isLoading {
                SkeletonRows(count: 2)
            }
        default:
            EmptyView()
        }
    }
}

/// A single static link within a section card. Fixed padding at all times — only the
/// background fill toggles on hover — so hovering never shifts the row's size
/// or its neighbors' positions.
private struct CardLinkRow: View {
    let row: LinkRow
    let store: Store
    var trailingCount: Int?
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(row.iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .foregroundStyle(isHovering ? Theme.textBody : Theme.textMeta40)
            Text(row.title)
                .font(.system(size: 12, weight: row.emphasis == .emphasized ? .medium : .regular))
                .foregroundStyle(labelColor)
            Spacer(minLength: 4)
            if let trailingCount {
                Text("\(trailingCount)")
                    .font(.mono(10.5))
                    .foregroundStyle(Theme.textMeta30)
            }
            if row.createAction != nil {
                CreateActionButton(accentColor: store.color) {
                    guard let url = row.createURL(for: store.myshopifyDomain) else { return }
                    openStoreLink(url)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isHovering ? Theme.hoverFill : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { openLink() }
    }

    private var labelColor: Color {
        switch row.emphasis {
        case .emphasized: return Theme.textPrimary
        case .normal: return isHovering ? Theme.textPrimary : Theme.textBody
        }
    }

    private func openLink() {
        guard let url = row.url(for: store.myshopifyDomain) else { return }
        openStoreLink(url)
    }
}

/// A single link within a card driven by live enrichment data (recent products,
/// top collections) rather than the static catalog — same visual language as
/// `CardLinkRow`, just backed by a computed URL instead of a fixed path.
private struct DynamicRow: View {
    let title: String
    let iconName: String
    let path: String
    let store: Store
    var meta: String?
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .foregroundStyle(isHovering ? Theme.textBody : Theme.textMeta40)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(isHovering ? Theme.textPrimary : Theme.textBody)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if let meta {
                Text(meta)
                    .font(.mono(10.5))
                    .foregroundStyle(Theme.textMeta30)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isHovering ? Theme.hoverFill : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            guard let url = URL(string: "https://admin.shopify.com/store/\(store.handle)\(path)") else { return }
            openStoreLink(url)
        }
    }
}

/// A theme row (live or unpublished) with its inline Editor/Preview action buttons.
private struct ThemeRow: View {
    let theme: EnrichedTheme
    let store: Store
    @State private var isHovering = false

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: theme.updatedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image("ThemeIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .foregroundStyle(isHovering ? Theme.textBody : Theme.textMeta40)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(theme.name)
                        .font(.system(size: 12))
                        .foregroundStyle(isHovering ? Theme.textPrimary : Theme.textBody)
                        .lineLimit(1)
                    if theme.isLive {
                        Text("LIVE")
                            .font(.mono(8.5, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(store.accentTextColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(store.color)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(relativeTime)
                    .font(.mono(9.5))
                    .foregroundStyle(Theme.textMeta36)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                themeButton("Editor") {
                    openAdminPath("/themes/\(theme.id.shopifyNumericID)/editor")
                }
                if theme.isLive {
                    themeButton("Code") {
                        openAdminPath("/themes/\(theme.id.shopifyNumericID)/edit")
                    }
                } else {
                    themeButton("Preview") {
                        guard let url = URL(string: "https://\(store.myshopifyDomain)?preview_theme_id=\(theme.id.shopifyNumericID)") else { return }
                        openStoreLink(url)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isHovering ? Theme.hoverFill : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private func themeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.textBody)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Theme.controlFill)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private func openAdminPath(_ path: String) {
        guard let url = URL(string: "https://admin.shopify.com/store/\(store.handle)\(path)") else { return }
        openStoreLink(url)
    }
}

/// Placeholder bars shown while enriched data is loading and no cached data exists yet.
private struct SkeletonRows: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.controlFill)
                    .frame(width: index.isMultiple(of: 2) ? 110 : 76, height: 8)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

/// Shown once at the top of the panel (not per-card) when the store has no token yet —
/// a single prompt to connect, rather than repeating the same notice on every enriched card.
private struct ConnectBanner: View {
    let store: Store
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 8) {
            Text("Connect a token to see live data across every card.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("Connect")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(store.accentTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(store.color)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
                .onTapGesture { openSettingsAccounts() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    private func openSettingsAccounts() {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Shown when a previously-connected store's token was revoked. Store-scoped only —
/// other stores and this store's static links keep working.
private struct AuthExpiredNotice: View {
    let store: Store
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(Theme.errorDot)
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            Text("\(store.displayName) token was revoked. Links still work.")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text("Reconnect")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(store.color)
                .contentShape(Rectangle())
                .onTapGesture {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }
}

/// The trailing "New +" action on a row. A separate tap target from the row itself —
/// SwiftUI resolves the tap to whichever view's `contentShape` is directly hit, so
/// tapping this pill opens the create URL instead of the row's own link.
private struct CreateActionButton: View {
    let accentColor: Color
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Text("New +")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(accentColor)
            .opacity(isHovering ? 0.75 : 1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture(perform: action)
    }
}
