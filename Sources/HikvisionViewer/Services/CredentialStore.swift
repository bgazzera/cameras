import Foundation
import Security

enum CredentialStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain access failed with status \(status)."
        case .invalidEncoding:
            return "The saved password could not be decoded from Keychain."
        }
    }
}

struct CredentialStore {
    private let service = "com.bgazzera.HikvisionViewer"

    func loadPassword(host: String, username: String) throws -> String? {
        let account = accountName(host: host, username: username)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }

        guard let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.invalidEncoding
        }

        return password
    }

    func savePassword(_ password: String, host: String, username: String) throws {
        let account = accountName(host: host, username: username)
        let encoded = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw CredentialStoreError.unexpectedStatus(updateStatus)
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = encoded
        let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(insertStatus)
        }
    }

    private func accountName(host: String, username: String) -> String {
        "\(host.lowercased())::\(username)"
    }
}
