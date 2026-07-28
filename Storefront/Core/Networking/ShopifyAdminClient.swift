import Foundation

enum AdminAPIError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case http(Int)
    case graphQL([String])
}

/// Thin wrapper around the Shopify Admin GraphQL API, authenticated with a
/// per-store Custom App access token (no OAuth — see Core/Keychain/KeychainStore).
///
/// Field names below are current as of Admin API 2024-10 to the best of available
/// knowledge; if a query starts failing against a real store, check the exact schema
/// (`productsCount`/theme `role` values are the most likely to drift across API versions).
struct ShopifyAdminClient {
    private static let apiVersion = "2024-10"

    private static func endpoint(domain: String) -> URL? {
        URL(string: "https://\(domain)/admin/api/\(apiVersion)/graphql.json")
    }

    private func request(domain: String, token: String, query: String, variables: [String: Any] = [:]) async throws -> [String: Any] {
        guard let url = Self.endpoint(domain: domain) else { throw AdminAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Shopify-Access-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AdminAPIError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw AdminAPIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw AdminAPIError.http(http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AdminAPIError.invalidResponse
        }
        if let errors = json["errors"] as? [[String: Any]] {
            let messages = errors.compactMap { $0["message"] as? String }
            throw AdminAPIError.graphQL(messages)
        }
        guard let dataObj = json["data"] as? [String: Any] else { throw AdminAPIError.invalidResponse }
        return dataObj
    }

    /// A cheap query used purely to confirm a pasted token is valid before saving it.
    func validateToken(domain: String, token: String) async throws {
        _ = try await request(domain: domain, token: token, query: "{ shop { name } }")
    }

    func fetchRecentlyEditedProducts(domain: String, token: String, limit: Int = 5) async throws -> [EnrichedProduct] {
        let query = """
        query RecentProducts($first: Int!) {
          products(first: $first, sortKey: UPDATED_AT, reverse: true) {
            edges { node { id title } }
          }
        }
        """
        let data = try await request(domain: domain, token: token, query: query, variables: ["first": limit])
        let edges = ((data["products"] as? [String: Any])?["edges"] as? [[String: Any]]) ?? []
        return edges.compactMap { edge in
            guard let node = edge["node"] as? [String: Any],
                  let id = node["id"] as? String,
                  let title = node["title"] as? String else { return nil }
            return EnrichedProduct(id: id, title: title)
        }
    }

    func fetchTopCollections(domain: String, token: String, limit: Int = 5) async throws -> [EnrichedCollection] {
        let query = """
        query TopCollections($first: Int!) {
          collections(first: $first, sortKey: UPDATED_AT, reverse: true) {
            edges { node { id title productsCount { count } } }
          }
        }
        """
        let data = try await request(domain: domain, token: token, query: query, variables: ["first": 25])
        let edges = ((data["collections"] as? [String: Any])?["edges"] as? [[String: Any]]) ?? []
        let collections: [EnrichedCollection] = edges.compactMap { edge in
            guard let node = edge["node"] as? [String: Any],
                  let id = node["id"] as? String,
                  let title = node["title"] as? String else { return nil }
            let count = (node["productsCount"] as? [String: Any])?["count"] as? Int ?? 0
            return EnrichedCollection(id: id, title: title, productsCount: count)
        }
        return Array(collections.sorted { $0.productsCount > $1.productsCount }.prefix(limit))
    }

    func fetchThemes(domain: String, token: String, unpublishedLimit: Int = 3) async throws -> (live: EnrichedTheme?, unpublished: [EnrichedTheme]) {
        let query = """
        query Themes {
          themes(first: 20) {
            edges { node { id name role updatedAt } }
          }
        }
        """
        let data = try await request(domain: domain, token: token, query: query)
        let edges = (data["themes"] as? [String: Any])?["edges"] as? [[String: Any]] ?? []
        let formatter = ISO8601DateFormatter()

        let themes: [(role: String, theme: EnrichedTheme)] = edges.compactMap { edge in
            guard let node = edge["node"] as? [String: Any],
                  let id = node["id"] as? String,
                  let name = node["name"] as? String,
                  let role = node["role"] as? String,
                  let updatedAtString = node["updatedAt"] as? String,
                  let updatedAt = formatter.date(from: updatedAtString) else { return nil }
            return (role, EnrichedTheme(id: id, name: name, isLive: role == "MAIN", updatedAt: updatedAt))
        }

        let live = themes.first { $0.role == "MAIN" }?.theme
        let unpublished = themes
            .filter { $0.role == "UNPUBLISHED" }
            .sorted { $0.theme.updatedAt > $1.theme.updatedAt }
            .prefix(unpublishedLimit)
            .map(\.theme)
        return (live, Array(unpublished))
    }

    func fetchOrderStats(domain: String, token: String) async throws -> EnrichedOrderStats {
        let query = """
        query OrderStats {
          unfulfilled: orders(first: 50, query: "fulfillment_status:unfulfilled") { edges { node { id } } }
          drafts: draftOrders(first: 50) { edges { node { id } } }
          abandoned: abandonedCheckouts(first: 50) { edges { node { id } } }
        }
        """
        let data = try await request(domain: domain, token: token, query: query)
        func count(_ key: String) -> Int {
            ((data[key] as? [String: Any])?["edges"] as? [[String: Any]])?.count ?? 0
        }
        return EnrichedOrderStats(
            unfulfilledCount: count("unfulfilled"),
            draftCount: count("drafts"),
            abandonedCount: count("abandoned")
        )
    }
}
