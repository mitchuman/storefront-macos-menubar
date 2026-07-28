import Foundation
import Security

/// Wraps Keychain access for per-store Shopify Admin API tokens.
/// One generic-password item per store, keyed by a stable service+account pair.
enum KeychainStore {
    private static let adminTokenService = "com.humanmarketing.storefront.admin-token"

    // MARK: - Store Admin API tokens

    static func saveAdminToken(_ token: String, forStoreDomain domain: String) {
        save(token, service: adminTokenService, account: domain)
    }

    static func adminToken(forStoreDomain domain: String) -> String? {
        load(service: adminTokenService, account: domain)
    }

    static func deleteAdminToken(forStoreDomain domain: String) {
        delete(service: adminTokenService, account: domain)
    }

    // MARK: - Generic Keychain helpers

    private static func save(_ value: String, service: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func load(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
