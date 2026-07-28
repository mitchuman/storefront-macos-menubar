import SwiftUI
import Combine

enum SyncState: Equatable {
    case idle(Date?)
    case loading
    case failed(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var stores: [Store]
    @Published var selectedStoreID: Store.ID?
    @Published var query: String = ""
    @Published var syncState: [Store.ID: SyncState] = [:]
    @Published var settings: AppSettings
    @Published var caches: [Store.ID: StoreCache]

    private let persistence: PersistenceStore
    private let adminClient = ShopifyAdminClient()
    private static let staleAfter: TimeInterval = 10 * 60

    init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        let loaded = persistence.loadStores()
        self.stores = loaded
        self.selectedStoreID = loaded.first(where: { $0.isVisible })?.id ?? loaded.first?.id
        self.settings = persistence.loadSettings()
        self.caches = persistence.loadCaches()
    }

    /// Favorited stores first (starring moves a store to the top), each group
    /// otherwise in the user's chosen order.
    var visibleStores: [Store] {
        stores.filter(\.isVisible).sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var selectedStore: Store? {
        stores.first { $0.id == selectedStoreID }
    }

    func select(_ store: Store) {
        selectedStoreID = store.id
        refreshIfStale(store)
    }

    func save() {
        persistence.save(stores: stores)
        persistence.save(settings: settings)
    }

    func saveCaches() {
        persistence.save(caches: caches)
    }

    func addStore(domain: String, displayName: String, colorHex: String) {
        let accountID = stores.first?.accountID ?? UUID()
        let nextOrder = (stores.map(\.sortOrder).max() ?? -1) + 1
        let store = Store(accountID: accountID, myshopifyDomain: domain, displayName: displayName, colorHex: colorHex, sortOrder: nextOrder)
        stores.append(store)
        if selectedStoreID == nil { selectedStoreID = store.id }
        save()
    }

    // MARK: - CSV import/export

    /// "Display Name,Domain,Color" — one row per store, in panel order.
    func storesCSV() -> String {
        var lines = ["Display Name,Domain,Color"]
        for store in stores.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            lines.append("\(CSV.escape(store.displayName)),\(CSV.escape(store.myshopifyDomain)),\(store.colorHex)")
        }
        return lines.joined(separator: "\n")
    }

    /// Adds a store per data row (skipping the header row and any duplicate domains).
    /// Returns the number of stores actually added.
    @discardableResult
    func importStoresCSV(_ contents: String) -> Int {
        let palette = ["1f6f4a", "c07a2c", "3a6ea8", "7a4b8c", "4a7a5c", "a8563a", "5c9fd6", "a37bb8"]
        var added = 0
        let rows = CSV.parse(contents)
        for row in rows.dropFirst() where row.count >= 2 {
            let displayName = row[0].trimmingCharacters(in: .whitespaces)
            var domain = row[1].trimmingCharacters(in: .whitespaces)
            guard !displayName.isEmpty, !domain.isEmpty else { continue }
            if !domain.hasSuffix(".myshopify.com") {
                domain = domain.replacingOccurrences(of: ".myshopify.com", with: "") + ".myshopify.com"
            }
            guard !stores.contains(where: { $0.myshopifyDomain == domain }) else { continue }
            let colorHex = row.count >= 3 && !row[2].isEmpty ? row[2] : palette[stores.count % palette.count]
            addStore(domain: domain, displayName: displayName, colorHex: colorHex)
            added += 1
        }
        return added
    }

    func toggleFavorite(_ store: Store) {
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        stores[index].isFavorite.toggle()
        save()
    }

    func removeStore(_ store: Store) {
        stores.removeAll { $0.id == store.id }
        caches.removeValue(forKey: store.id)
        KeychainStore.deleteAdminToken(forStoreDomain: store.myshopifyDomain)
        save()
        saveCaches()
    }

    func moveStore(fromOffsets: IndexSet, toOffset: Int) {
        var ordered = stores.sorted { $0.sortOrder < $1.sortOrder }
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, var store) in ordered.enumerated() {
            store.sortOrder = index
            if let idx = stores.firstIndex(where: { $0.id == store.id }) {
                stores[idx] = store
            }
        }
        save()
    }

    // MARK: - Store connection (manual token)

    enum ConnectError: LocalizedError {
        case invalidToken

        var errorDescription: String? {
            switch self {
            case .invalidToken: return "That token didn't work. Double-check it was copied in full and has the right scopes."
            }
        }
    }

    /// Validates the pasted token against the store before saving anything.
    func connectStore(_ store: Store, token: String) async throws {
        try await adminClient.validateToken(domain: store.myshopifyDomain, token: token)
        KeychainStore.saveAdminToken(token, forStoreDomain: store.myshopifyDomain)
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        stores[index].hasToken = true
        stores[index].connectionStatus = .connected
        save()
        await refresh(stores[index])
    }

    func disconnectStore(_ store: Store) {
        KeychainStore.deleteAdminToken(forStoreDomain: store.myshopifyDomain)
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        stores[index].hasToken = false
        stores[index].connectionStatus = .staticOnly
        caches.removeValue(forKey: store.id)
        syncState.removeValue(forKey: store.id)
        save()
        saveCaches()
    }

    // MARK: - Enrichment refresh

    func refreshIfStale(_ store: Store) {
        guard store.hasToken else { return }
        let cache = caches[store.id]
        let isStale = (cache?.fetchedAt).map { Date().timeIntervalSince($0) > Self.staleAfter } ?? true
        guard isStale else { return }
        Task { await refresh(store) }
    }

    func refreshAllConnectedStores() {
        for store in stores where store.hasToken {
            Task { await refresh(store) }
        }
    }

    /// Called when the panel opens — refreshes every visible connected store whose
    /// cache has gone stale, concurrently, without blocking the panel from painting.
    func refreshVisibleStoresIfStale() {
        for store in visibleStores {
            refreshIfStale(store)
        }
    }

    func refresh(_ store: Store) async {
        guard let token = KeychainStore.adminToken(forStoreDomain: store.myshopifyDomain) else { return }
        syncState[store.id] = .loading

        do {
            async let products = adminClient.fetchRecentlyEditedProducts(domain: store.myshopifyDomain, token: token)
            async let collections = adminClient.fetchTopCollections(domain: store.myshopifyDomain, token: token)
            async let themes = adminClient.fetchThemes(domain: store.myshopifyDomain, token: token)
            async let orders = adminClient.fetchOrderStats(domain: store.myshopifyDomain, token: token)

            let (productsResult, collectionsResult, themesResult, ordersResult) = try await (products, collections, themes, orders)

            var cache = StoreCache()
            cache.recentlyEditedProducts = productsResult
            cache.topCollections = collectionsResult
            cache.liveTheme = themesResult.live
            cache.unpublishedThemes = themesResult.unpublished
            cache.orderStats = ordersResult
            cache.fetchedAt = Date()
            caches[store.id] = cache
            saveCaches()

            if let index = stores.firstIndex(where: { $0.id == store.id }) {
                stores[index].lastRefreshedAt = cache.fetchedAt
                stores[index].connectionStatus = .connected
                save()
            }
            syncState[store.id] = .idle(cache.fetchedAt)
        } catch AdminAPIError.unauthorized {
            if let index = stores.firstIndex(where: { $0.id == store.id }) {
                stores[index].connectionStatus = .tokenInvalid
                save()
            }
            syncState[store.id] = .failed("Token was revoked")
        } catch {
            syncState[store.id] = .failed(error.localizedDescription)
        }
    }
}
