// YoLingo/Services/Settings/KeychainHelper.swift
import Foundation
import Security

// MARK: - KeychainHelper

/// Security framework 的薄封装，提供 Keychain CRUD 操作
struct KeychainHelper {

    /// Save data to Keychain. If item already exists, updates it instead.
    static func save(service: String, account: String, data: Data) throws {
        if read(service: service, account: account) != nil {
            try update(service: service, account: account, data: data)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Read data from Keychain. Returns nil if not found.
    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Update existing Keychain item.
    static func update(service: String, account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.updateFailed(status)
        }
    }

    /// Delete Keychain item. No-op if not found.
    static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - KeychainError

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case updateFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed (OSStatus: \(status))"
        case .updateFailed(let status):
            return "Keychain update failed (OSStatus: \(status))"
        case .deleteFailed(let status):
            return "Keychain delete failed (OSStatus: \(status))"
        case .unexpectedData:
            return "Keychain returned unexpected data format"
        }
    }
}
