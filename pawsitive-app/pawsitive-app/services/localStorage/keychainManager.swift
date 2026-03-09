//
//  keychainManager.swift
//  recap
//
//  Created by Diptayan Jash on 09/03/26.
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case noToken
    case unexpectedTokenData
}

class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private let service = "com.pawsitive.app"

    enum Key: String {
        case userID = "userID"
        case userRole
        case accessToken = "accessToken"
    }

    // MARK: - Generic Methods

    private func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(data, account: account)
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }

    private func get(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.noToken
            }
            throw KeychainError.unknown(status)
        }

        return data
    }

    private func update(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unknown(status)
        }
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - String Helpers

    func save(key: Key, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try save(data, account: key.rawValue)
    }

    func getString(key: Key) -> String? {
        do {
            let data = try get(account: key.rawValue)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func delete(key: Key) throws {
        try delete(account: key.rawValue)
    }
}
