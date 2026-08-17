import Foundation
import Security

/// Speichert die Withings OAuth-Tokens sicher im iOS Keychain.
final class TokenStore {
    static let shared = TokenStore()
    private let service = "com.zkardes.PulseTrack.withings"

    private(set) var accessToken: String? { didSet { save(key: "access", value: accessToken) } }
    private(set) var refreshToken: String? { didSet { save(key: "refresh", value: refreshToken) } }
    private(set) var expiry: Date? {
        didSet { save(key: "expiry", value: expiry.map { String($0.timeIntervalSince1970) }) }
    }

    private init() {
        accessToken  = read(key: "access")
        refreshToken = read(key: "refresh")
        if let e = read(key: "expiry"), let t = Double(e) {
            expiry = Date(timeIntervalSince1970: t)
        }
    }

    func save(access: String, refresh: String, expiry: Date) {
        self.accessToken = access
        self.refreshToken = refresh
        self.expiry = expiry
    }

    func clear() {
        accessToken = nil; refreshToken = nil; expiry = nil
    }

    // MARK: - Keychain primitives

    private func save(key: String, value: String?) {
        let account = "\(service).\(key)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let account = "\(service).\(key)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
