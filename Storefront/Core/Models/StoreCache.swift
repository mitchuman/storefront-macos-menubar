import Foundation

extension String {
    /// Extracts the trailing numeric id from a Shopify GraphQL GID, e.g.
    /// "gid://shopify/Product/123456789" -> "123456789".
    var shopifyNumericID: String {
        components(separatedBy: "/").last ?? self
    }
}

struct EnrichedProduct: Codable, Identifiable, Equatable {
    let id: String
    let title: String
}

struct EnrichedCollection: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let productsCount: Int
}

struct EnrichedTheme: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let isLive: Bool
    let updatedAt: Date
}

struct EnrichedOrderStats: Codable, Equatable {
    var unfulfilledCount: Int = 0
    var draftCount: Int = 0
    var abandonedCount: Int = 0
}

/// Enriched (live Admin API) data cached per store, persisted to disk so the panel
/// paints instantly from last-known data before a refresh completes.
struct StoreCache: Codable, Equatable {
    var recentlyEditedProducts: [EnrichedProduct] = []
    var topCollections: [EnrichedCollection] = []
    var liveTheme: EnrichedTheme? = nil
    var unpublishedThemes: [EnrichedTheme] = []
    var orderStats: EnrichedOrderStats = .init()
    var fetchedAt: Date? = nil
}
