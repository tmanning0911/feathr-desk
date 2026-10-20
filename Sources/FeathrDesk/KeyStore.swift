import Foundation
import Security

enum KeyStore {
    private static let service = "com.mfccc.feathrdesk"
    private static let account = "feathr-api-key"
    static let controlEnv = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Desktop/Feathr Control/.env")

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return key?.isEmpty == false ? key : nil
    }

    static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("fthr_") else {
            throw KeyStoreError.invalid
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyStoreError.os(status) }
    }

    static func readControlEnv() -> (key: String, base: String)? {
        guard let text = try? String(contentsOf: controlEnv, encoding: .utf8) else { return nil }
        var key = ""
        var base = "https://api.feathr.co"
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let eq = trimmed.firstIndex(of: "=") else { continue }
            let name = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            if name == "FEATHR_API_KEY" { key = value }
            if name == "FEATHR_API_BASE", !value.isEmpty { base = value }
        }
        guard key.hasPrefix("fthr_") else { return nil }
        return (key, base)
    }
}

enum KeyStoreError: LocalizedError {
    case invalid
    case os(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalid: return "A Feathr key starts with fthr_."
        case .os(let status): return "Keychain could not store the key (\(status))."
        }
    }
}
