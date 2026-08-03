import AppKit
import Foundation
import OSLog

/// Resolves, downloads, and caches store favicons under Application Support.
/// Binary data stays on disk — never in `stores.json`.
@MainActor
final class FaviconStore: ObservableObject {
    static let shared = FaviconStore()

    /// Bumped whenever a favicon is written or removed so SwiftUI views refresh.
    @Published private(set) var revision: UInt = 0

    private let logger = Logger(subsystem: "com.humanmarketing.storefront", category: "favicon")
    private let directoryURL: URL
    private var memory: [UUID: NSImage] = [:]
    private var inFlight: Set<UUID> = []

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directoryURL = appSupport
            .appendingPathComponent("Storefront", isDirectory: true)
            .appendingPathComponent("Favicons", isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    func image(for storeID: UUID) -> NSImage? {
        if let cached = memory[storeID] { return cached }
        guard let data = try? Data(contentsOf: fileURL(for: storeID)),
              let image = NSImage(data: data) else { return nil }
        memory[storeID] = image
        return image
    }

    func hasCachedImage(for storeID: UUID) -> Bool {
        if memory[storeID] != nil { return true }
        return FileManager.default.fileExists(atPath: fileURL(for: storeID).path)
    }

    /// Fetches favicons for the given stores. Skips stores that already have a
    /// cached file unless `force` is true. Returns how many icons were newly saved.
    @discardableResult
    func fetch(stores: [Store], force: Bool = false) async -> Int {
        let targets = stores.filter { force || !hasCachedImage(for: $0.id) }
        guard !targets.isEmpty else { return 0 }

        var updated = 0
        // Process in chunks so we don't open dozens of connections at once.
        for chunk in stride(from: 0, to: targets.count, by: 4).map({ Array(targets[$0..<min($0 + 4, targets.count)]) }) {
            let runnable = chunk.filter { !inFlight.contains($0.id) }
            guard !runnable.isEmpty else { continue }
            for store in runnable { inFlight.insert(store.id) }

            await withTaskGroup(of: (UUID, NSImage)?.self) { group in
                for store in runnable {
                    let storeID = store.id
                    let domain = store.myshopifyDomain
                    let shopURL = store.shopURL
                    group.addTask {
                        guard let shopURL else { return nil }
                        guard let image = await Self.downloadFavicon(shopURL: shopURL, domain: domain) else {
                            return nil
                        }
                        return (storeID, image)
                    }
                }
                for await result in group {
                    guard let (storeID, image) = result else { continue }
                    save(image, for: storeID)
                    updated += 1
                    logger.info("Favicon saved for store \(storeID.uuidString, privacy: .public)")
                }
            }

            for store in runnable { inFlight.remove(store.id) }
        }
        return updated
    }

    func remove(storeID: UUID) {
        memory.removeValue(forKey: storeID)
        try? FileManager.default.removeItem(at: fileURL(for: storeID))
        revision &+= 1
    }

    func removeAll() {
        memory.removeAll()
        if let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }
        revision &+= 1
    }

    // MARK: - Persistence

    private func save(_ image: NSImage, for storeID: UUID) {
        memory[storeID] = image
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: fileURL(for: storeID), options: .atomic)
        }
        revision &+= 1
    }

    private func fileURL(for storeID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(storeID.uuidString).png")
    }

    // MARK: - Network (nonisolated)

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "StorefrontMac (Macintosh; macOS)"
        ]
        return URLSession(configuration: config)
    }()

    nonisolated private static func downloadFavicon(shopURL: URL, domain: String) async -> NSImage? {
        let candidates = await resolveCandidateURLs(shopURL: shopURL, domain: domain)
        for url in candidates {
            if let image = await downloadImage(from: url) {
                return image
            }
        }
        return nil
    }

    nonisolated private static func resolveCandidateURLs(shopURL: URL, domain: String) async -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL?) {
            guard let url else { return }
            let key = url.absoluteString
            guard !seen.contains(key) else { return }
            seen.insert(key)
            urls.append(url)
        }

        if let html = try? await fetchHTML(from: shopURL) {
            for href in iconHrefs(in: html) {
                append(URL(string: href, relativeTo: shopURL)?.absoluteURL)
            }
        }

        append(URL(string: "/favicon.ico", relativeTo: shopURL)?.absoluteURL)
        append(URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128"))
        append(URL(string: "https://icons.duckduckgo.com/ip3/\(domain).ico"))

        return urls
    }

    nonisolated private static func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let limited = data.prefix(256 * 1024)
        return String(decoding: limited, as: UTF8.self)
    }

    nonisolated private static func downloadImage(from url: URL) async -> NSImage? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard data.count > 32, data.count < 2 * 1024 * 1024 else { return nil }
            guard let image = NSImage(data: data), image.size.width >= 8, image.size.height >= 8 else {
                return nil
            }
            return image
        } catch {
            return nil
        }
    }

    /// Pulls href values from `<link rel="…icon…">` tags, preferring apple-touch / larger icons.
    nonisolated static func iconHrefs(in html: String) -> [String] {
        let pattern = #"<link\b[^>]*\brel\s*=\s*["']([^"']*icon[^"']*)["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        struct Candidate {
            let href: String
            let score: Int
        }
        var candidates: [Candidate] = []

        for match in matches {
            let tag = ns.substring(with: match.range)
            guard let href = attribute("href", in: tag) else { continue }
            let rel = attribute("rel", in: tag)?.lowercased() ?? ""
            let sizes = attribute("sizes", in: tag) ?? ""
            var score = 0
            if rel.contains("apple-touch-icon") { score += 100 }
            else if rel.contains("icon") { score += 50 }
            if let dim = sizes.split(separator: "x").compactMap({ Int($0) }).max() {
                score += min(dim, 256)
            }
            if href.lowercased().hasSuffix(".svg") { score -= 20 }
            candidates.append(Candidate(href: href, score: score))
        }

        return candidates.sorted { $0.score > $1.score }.map(\.href)
    }

    nonisolated private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = #"\#(name)\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
              match.numberOfRanges >= 2
        else { return nil }
        return (tag as NSString).substring(with: match.range(at: 1))
    }
}
