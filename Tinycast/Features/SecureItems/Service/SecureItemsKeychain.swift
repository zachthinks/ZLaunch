import Foundation
import LocalAuthentication
import Security

// LAContext supports concurrent invalidation; no mutable configuration crosses the worker boundary.
final class SecureItemsAuthentication: @unchecked Sendable {
    let context = LAContext()
    func invalidate() { context.invalidate() }
}

protocol SecureItemsRepository: Sendable {
    func read(context: SecureItemsAuthentication) async throws -> [SecureItem]
    func write(_ items: [SecureItem], context: SecureItemsAuthentication) async throws
}

struct SecureItemsKeychain: SecureItemsRepository {
    enum Failure: Error { case keychain(OSStatus), invalidData }
    let service: String

    init(bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.zachthinks.zlaunch") {
        service = bundleIdentifier + ".secure-items"
    }

    @concurrent
    func read(context: SecureItemsAuthentication) async throws -> [SecureItem] {
        try Task.checkCancellation()
        var query = query(context: context)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw Failure.keychain(status) }
        guard let data = result as? Data else { throw Failure.invalidData }
        let items = try JSONDecoder().decode([SecureItem].self, from: data)
        guard items.allSatisfy(\.isValid), Set(items.map(\.id)).count == items.count else {
            throw Failure.invalidData
        }
        try Task.checkCancellation()
        return items
    }

    @concurrent
    func write(_ items: [SecureItem], context: SecureItemsAuthentication) async throws {
        guard items.allSatisfy(\.isValid) else { throw Failure.invalidData }
        let data = try JSONEncoder().encode(items)
        let query = query(context: context)
        try Task.checkCancellation()
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            guard let access = SecAccessControlCreateWithFlags(
                nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, nil)
            else { throw Failure.invalidData }
            var addition = query
            addition[kSecAttrAccessControl as String] = access
            addition[kSecValueData as String] = data
            try Task.checkCancellation()
            let added = SecItemAdd(addition as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure.keychain(added) }
        } else if status != errSecSuccess {
            throw Failure.keychain(status)
        }
    }

    private func query(context: SecureItemsAuthentication) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "vault-v1",
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationContext as String: context.context
        ]
    }
}
