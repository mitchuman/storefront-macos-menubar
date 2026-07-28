import Foundation

enum SectionKind {
    case enriched
    case links
}

enum SectionID: String, Codable, CaseIterable, Hashable {
    case products
    case collections
    case themes
    case navigationAndRedirects
    case orders
    case discounts
    case settings
    case apps
    case analytics
    case content
    case customers

    var title: String {
        switch self {
        case .products: return "Products"
        case .collections: return "Collections"
        case .themes: return "Themes"
        case .navigationAndRedirects: return "Navigation & redirects"
        case .orders: return "Orders"
        case .discounts: return "Discounts"
        case .settings: return "Store settings"
        case .apps: return "Apps"
        case .analytics: return "Analytics"
        case .content: return "Content"
        case .customers: return "Customers"
        }
    }

    var kind: SectionKind {
        switch self {
        case .products, .collections, .themes, .orders:
            return .enriched
        default:
            return .links
        }
    }

    /// Polaris icon asset name (from `@shopify/polaris-icons`, MIT licensed) shown
    /// alongside the card title in the panel.
    var iconName: String {
        switch self {
        case .products: return "ProductIcon"
        case .collections: return "CollectionIcon"
        case .themes: return "ThemeIcon"
        case .navigationAndRedirects: return "MenuIcon"
        case .orders: return "OrderIcon"
        case .discounts: return "DiscountIcon"
        case .settings: return "SettingsIcon"
        case .apps: return "AppsIcon"
        case .analytics: return "ChartVerticalIcon"
        case .content: return "ContentIcon"
        case .customers: return "PersonIcon"
        }
    }

    /// Default display order, matching the design's default section ordering.
    static var defaultOrder: [SectionID] {
        [.products, .themes, .navigationAndRedirects, .collections, .orders, .discounts, .settings, .apps, .analytics, .content, .customers]
    }
}

struct LinkRow: Identifiable {
    enum Emphasis {
        case normal
        case emphasized
    }

    /// A "New X" action attached to a row and rendered as a trailing "New +" button,
    /// rather than as its own separate row.
    struct CreateAction {
        let path: String
    }

    let id: String
    let title: String
    let path: String
    /// Polaris icon asset name shown leading the row's title.
    let iconName: String
    var emphasis: Emphasis = .normal
    var createAction: CreateAction? = nil
    /// Overrides `path`'s admin.shopify.com templating with a fully-formed external URL
    /// (e.g. the public Shopify App Store, which isn't a per-store admin path).
    var absoluteURL: String? = nil

    func url(for domain: String) -> URL? {
        if let absoluteURL { return URL(string: absoluteURL) }
        return URL(string: "https://admin.shopify.com/store/\(Store.handle(fromDomain: domain))\(path)")
    }

    func createURL(for domain: String) -> URL? {
        guard let createAction else { return nil }
        return URL(string: "https://admin.shopify.com/store/\(Store.handle(fromDomain: domain))\(createAction.path)")
    }
}

/// Static (non-enriched) link catalog per section. Enriched sections still show
/// these base links even without a token; dynamic rows are layered on top when connected.
enum StaticLinkCatalog {
    static func rows(for section: SectionID) -> [LinkRow] {
        switch section {
        case .products:
            return [
                LinkRow(id: "products.all", title: "All products", path: "/products", iconName: "ProductListIcon", createAction: .init(path: "/products/new")),
                LinkRow(id: "products.inventory", title: "Inventory", path: "/products/inventory", iconName: "InventoryIcon"),
            ]
        case .collections:
            return [
                LinkRow(id: "collections.all", title: "All collections", path: "/collections", iconName: "CollectionListIcon", createAction: .init(path: "/collections/new")),
            ]
        case .themes:
            return [
                LinkRow(id: "themes.library", title: "Theme library", path: "/themes", iconName: "ThemeStoreIcon"),
            ]
        case .navigationAndRedirects:
            return [
                LinkRow(id: "navigation.all", title: "Menus", path: "/menus", iconName: "ListBulletedIcon"),
                LinkRow(id: "navigation.main", title: "Main menu", path: "/menus", iconName: "MenuIcon"),
                LinkRow(id: "redirects.all", title: "URL redirects", path: "/content/redirects", iconName: "DomainRedirectIcon", createAction: .init(path: "/content/redirects/new")),
            ]
        case .orders:
            return [
                LinkRow(id: "orders.all", title: "All orders", path: "/orders", iconName: "OrderIcon"),
                LinkRow(id: "orders.unfulfilled", title: "Unfulfilled", path: "/orders?query=fulfillment_status%3Aunfulfilled", iconName: "OrderUnfulfilledIcon"),
                LinkRow(id: "orders.drafts", title: "Drafts", path: "/draft_orders", iconName: "OrderDraftIcon"),
                LinkRow(id: "orders.abandoned", title: "Abandoned checkouts", path: "/checkouts", iconName: "CartAbandonedIcon"),
            ]
        case .discounts:
            return [
                LinkRow(id: "discounts.all", title: "All discounts", path: "/discounts", iconName: "DiscountIcon", createAction: .init(path: "/discounts/new")),
            ]
        case .settings:
            return [
                LinkRow(id: "settings.general", title: "General", path: "/settings/general", iconName: "SettingsIcon"),
                LinkRow(id: "settings.payments", title: "Payments", path: "/settings/payments", iconName: "PaymentIcon"),
                LinkRow(id: "settings.checkout", title: "Checkout", path: "/settings/checkout", iconName: "CreditCardIcon"),
                LinkRow(id: "settings.shipping", title: "Shipping", path: "/settings/shipping", iconName: "DeliveryIcon"),
                LinkRow(id: "settings.domains", title: "Domains", path: "/settings/domains", iconName: "DomainIcon"),
                LinkRow(id: "settings.markets", title: "Markets", path: "/settings/markets", iconName: "MarketsIcon"),
                LinkRow(id: "settings.notifications", title: "Notifications", path: "/settings/notifications", iconName: "NotificationIcon"),
            ]
        case .apps:
            return [
                LinkRow(id: "apps.installed", title: "Installed apps", path: "/settings/apps", iconName: "AppsIcon"),
                LinkRow(id: "apps.store", title: "App store", path: "", iconName: "StoreIcon", absoluteURL: "https://apps.shopify.com/"),
            ]
        case .analytics:
            return [
                LinkRow(id: "analytics.live", title: "Live view", path: "/live_view", iconName: "LiveIcon"),
                LinkRow(id: "analytics.reports", title: "Reports", path: "/reports", iconName: "ChartLineIcon"),
                LinkRow(id: "analytics.dashboard", title: "Dashboard", path: "/analytics", iconName: "ChartVerticalIcon"),
            ]
        case .content:
            return [
                LinkRow(id: "content.files", title: "Files", path: "/content/files", iconName: "FileIcon"),
                LinkRow(id: "content.metafields", title: "Metafield definitions", path: "/settings/custom_data", iconName: "MetaobjectListIcon"),
                LinkRow(id: "content.pages", title: "Pages", path: "/pages", iconName: "PageIcon"),
                LinkRow(id: "content.blogs", title: "Blogs", path: "/content/blogs", iconName: "BlogIcon"),
                LinkRow(id: "content.blog", title: "Blog posts", path: "/content/articles", iconName: "BlogIcon"),
            ]
        case .customers:
            return [
                LinkRow(id: "customers.all", title: "All customers", path: "/customers", iconName: "PersonIcon"),
                LinkRow(id: "customers.segments", title: "Segments", path: "/customers/segments", iconName: "PersonSegmentIcon"),
            ]
        }
    }
}
