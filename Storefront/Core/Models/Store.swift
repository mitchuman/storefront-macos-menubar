import SwiftUI
import AppKit

enum ConnectionStatus: String, Codable {
    case staticOnly
    case connecting
    case connected
    case tokenInvalid
}

struct Store: Identifiable, Codable, Equatable {
    let id: UUID
    var accountID: UUID
    var myshopifyDomain: String
    var displayName: String
    var colorHex: String
    var isVisible: Bool
    var sortOrder: Int
    var isFavorite: Bool
    var hasToken: Bool
    var connectionStatus: ConnectionStatus
    var lastRefreshedAt: Date?

    init(
        id: UUID = UUID(),
        accountID: UUID,
        myshopifyDomain: String,
        displayName: String,
        colorHex: String,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        isFavorite: Bool = false,
        hasToken: Bool = false,
        connectionStatus: ConnectionStatus = .staticOnly,
        lastRefreshedAt: Date? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.myshopifyDomain = myshopifyDomain
        self.displayName = displayName
        self.colorHex = colorHex
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.isFavorite = isFavorite
        self.hasToken = hasToken
        self.connectionStatus = connectionStatus
        self.lastRefreshedAt = lastRefreshedAt
    }

    var color: Color {
        Color(hex: colorHex)
    }

    /// Automatic a11y text color for content drawn on top of this store's accent color —
    /// black on light accents, white on dark ones, via a standard luma calculation.
    var accentTextColor: Color {
        let (r, g, b) = Store.rgbComponents(fromHex: colorHex)
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        return luma > 150 ? .black : .white
    }

    private static func rgbComponents(fromHex hex: String) -> (Double, Double, Double) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF)
        let g = Double((value >> 8) & 0xFF)
        let b = Double(value & 0xFF)
        return (r, g, b)
    }

    var initials: String {
        let words = displayName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    /// The store "handle" used in admin.shopify.com URLs, i.e. the domain minus ".myshopify.com".
    static func handle(fromDomain domain: String) -> String {
        domain.replacingOccurrences(of: ".myshopify.com", with: "")
    }

    var handle: String { Store.handle(fromDomain: myshopifyDomain) }

    var adminURL: URL? { URL(string: "https://admin.shopify.com/store/\(handle)") }
    var shopURL: URL? { URL(string: "https://\(myshopifyDomain)") }
}

extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Converts this color to a "rrggbb" hex string, for persisting user-picked colors.
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "%02x%02x%02x", r, g, b)
    }
}

enum SampleData {
    static let accountID = UUID()

    static let stores: [Store] = [
        Store(accountID: accountID, myshopifyDomain: "softies-comfort-wear.myshopify.com", displayName: "Softies Comfort Wear", colorHex: "1f6f4a", sortOrder: 0),
        Store(accountID: accountID, myshopifyDomain: "myvibranthealth.myshopify.com", displayName: "My Vibrant Health", colorHex: "c07a2c", sortOrder: 1),
        Store(accountID: accountID, myshopifyDomain: "cnpusa.myshopify.com", displayName: "CNP USA", colorHex: "3a6ea8", sortOrder: 2),
        Store(accountID: accountID, myshopifyDomain: "ringwraps.myshopify.com", displayName: "Ringwraps", colorHex: "7a4b8c", sortOrder: 3),
        Store(accountID: accountID, myshopifyDomain: "kwik-hang-curtains.myshopify.com", displayName: "Kwik Hang Curtains", colorHex: "4a7a5c", sortOrder: 4),
        Store(accountID: accountID, myshopifyDomain: "haute-diggity-dog.myshopify.com", displayName: "Haute Diggity Dog", colorHex: "a8563a", sortOrder: 5),
        Store(accountID: accountID, myshopifyDomain: "fidelis-pet.myshopify.com", displayName: "Fidelis Pet", colorHex: "5c9fd6", sortOrder: 6),
        Store(accountID: accountID, myshopifyDomain: "noodleandboo.myshopify.com", displayName: "Noodle & Boo", colorHex: "a37bb8", sortOrder: 7),
    ]
}
